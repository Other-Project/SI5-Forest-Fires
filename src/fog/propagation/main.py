import base64
import numpy as np
import matplotlib.pyplot as plt
from dataclasses import dataclass
from scipy.interpolate import griddata
from matplotlib.colors import ListedColormap, BoundaryNorm
import matplotlib.animation as animation
import json
from kafka import KafkaConsumer, KafkaProducer
from kafka.errors import KafkaError
import random
import threading
import time
import re
import os
import datetime
from PIL import Image
import io

REDPANDA_BROKER = os.getenv("REDPANDA_BROKER", "localhost:19092")
PLOT = os.getenv("PLOT", "True").lower() == "true"

GRID_SIZE = 64
PREDICTION_STEPS = 10
FIRE_THRESHOLD = 60.0

# Satellite readjustment configuration
SATELLITE_WEIGHT = 0.7  # Weight for satellite data in readjustment
METEO_WEIGHT = 0.3      # Weight for meteo station data
SATELLITE_UPDATE_THRESHOLD = 5.0  # seconds between satellite updates

def json_serializer(data):
    return json.dumps(data).encode("utf-8")

producer = KafkaProducer(
    bootstrap_servers=[REDPANDA_BROKER],
    value_serializer=json_serializer
)

@dataclass
class LocationData:
    latitude: float
    longitude: float
    altitude: float

@dataclass
class SensorData:
    id: str
    location: LocationData
    forest_area: str = "unknown"
    temperature: float = 0.0
    air_humidity: float = 50.0
    soil_humidity: float = 50.0
    wind_speed: float = 0.0
    wind_direction: int = 0
    timestamp: float = 0.0

known_sensors = {}
satellite_grid = None
satellite_lock = threading.Lock()
last_satellite_update = 0.0
satellite_bbox = None  # (min_lon, min_lat, max_lon, max_lat)

def consume_redpanda():
    """
    Consume meteo station data for high-frequency precision updates.
    Meteo stations provide fast, localized data for propagation refinement.
    """
    max_retries = 5
    retry_count = 0

    while retry_count < max_retries:
        try:
            print(f"Tentative de connexion à Redpanda (meteo) ({retry_count + 1}/{max_retries})...")
            consumer = KafkaConsumer(
                bootstrap_servers=[REDPANDA_BROKER],
                value_deserializer=lambda m: json.loads(m.decode('utf-8')),
                auto_offset_reset='latest',
                group_id='propagation-group'
            )
            pattern = re.compile(r'sensors\.meteo\..*\.data')
            consumer.subscribe(pattern=pattern)
            print("✓ Connecté à Redpanda (meteo)")
            retry_count = 0

            for message in consumer:
                try:
                    p = message.value
                    meta = p['metadata']
                    area = meta.get('forest_area', 'default_zone')

                    s = SensorData(
                        id=meta['device_id'],
                        location=LocationData(**meta['location']),
                        forest_area=area,
                        temperature=p['temperature'],
                        air_humidity=p['air_humidity'],
                        soil_humidity=p['soil_humidity'],
                        wind_speed=p['wind_speed'],
                        wind_direction=p['wind_direction'],
                        timestamp=time.time()
                    )
                    known_sensors[s.id] = s
                except Exception as e:
                    print(f"Erreur parsing meteo: {e}")
        except KafkaError as e:
            retry_count += 1
            print(f"✗ Erreur Kafka (meteo): {e}")
            if retry_count < max_retries:
                time.sleep(2 ** retry_count)
            else:
                break

consumer_thread = threading.Thread(target=consume_redpanda, daemon=True)
consumer_thread.start()

# Cell state constants
STATE_VEGETATION = 0
STATE_AT_RISK = 1
STATE_BURNING = 2
STATE_BURNT = 3

class FirePredictor:
    def __init__(self, size=50):
        self.size = size
        self.min_lat, self.max_lat = 0, 0
        self.min_lon, self.max_lon = 0, 0
        self.weather_data = {}
        self.initialized = False
        
        # Satellite-based fire position (ground truth)
        self.satellite_fire_grid = np.zeros((size, size))
        # Meteo-based prediction (high frequency)
        self.meteo_prediction_grid = np.zeros((size, size))
        # Combined display grid
        self.display_grid = np.zeros((size, size))

        self.last_publish_time = 0
        self.publish_interval = 2.0
        
        # Track when we last readjusted from satellite
        self.last_satellite_readjustment = 0.0

        self.satellite_bbox = None  # (min_lon, min_lat, max_lon, max_lat)

    def _get_biggest_bbox(self, station_bbox, satellite_bbox):
        """
        Return the biggest bbox covering both station and satellite bboxes.
        Each bbox is (min_lon, min_lat, max_lon, max_lat)
        """
        if station_bbox is None and satellite_bbox is None:
            return (0, 1, 0, 1)
        if station_bbox is None:
            return satellite_bbox
        if satellite_bbox is None:
            return station_bbox
        min_lon = min(station_bbox[0], satellite_bbox[0])
        min_lat = min(station_bbox[1], satellite_bbox[1])
        max_lon = max(station_bbox[2], satellite_bbox[2])
        max_lat = max(station_bbox[3], satellite_bbox[3])
        return (min_lon, min_lat, max_lon, max_lat)

    def update_weather_from_sensors(self, sensors_dict):
        global satellite_bbox
        if len(sensors_dict) < 3:
            # If not enough sensors, fill weather_data with default values
            self.min_lat, self.max_lat = 0, 1
            self.min_lon, self.max_lon = 0, 1
            grid_x, grid_y = np.meshgrid(
                np.linspace(self.min_lon, self.max_lon, self.size),
                np.linspace(self.min_lat, self.max_lat, self.size)
            )
            self.weather_data = {
                'temperature': np.full((self.size, self.size), 20.0),
                'air_humidity': np.full((self.size, self.size), 50.0),
                'wind_speed': np.full((self.size, self.size), 0.0),
                'wind_direction': np.full((self.size, self.size), 0.0)
            }
            self.initialized = True
            return

        sensors = list(sensors_dict.values())

        lats = [s.location.latitude for s in sensors]
        lons = [s.location.longitude for s in sensors]

        # Compute station bbox
        station_min_lat, station_max_lat = min(lats), max(lats)
        station_min_lon, station_max_lon = min(lons), max(lons)
        lat_margin = (station_max_lat - station_min_lat) * 0.1 if station_max_lat != station_min_lat else 0.01
        lon_margin = (station_max_lon - station_min_lon) * 0.1 if station_max_lon != station_min_lon else 0.01
        station_bbox = (
            station_min_lon - lon_margin,
            station_min_lat - lat_margin,
            station_max_lon + lon_margin,
            station_max_lat + lat_margin,
        )

        # Use the biggest bbox between satellite and stations
        biggest_bbox = self._get_biggest_bbox(station_bbox, satellite_bbox)
        self.min_lon, self.min_lat, self.max_lon, self.max_lat = biggest_bbox

        points = np.array([[s.location.longitude, s.location.latitude] for s in sensors])

        grid_x, grid_y = np.meshgrid(
            np.linspace(self.min_lon, self.max_lon, self.size),
            np.linspace(self.min_lat, self.max_lat, self.size)
        )
        keys = ['temperature', 'air_humidity', 'wind_speed', 'wind_direction']
        for k in keys:
            vals = np.array([getattr(s, k) for s in sensors])
            self.weather_data[k] = griddata(points, vals, (grid_x, grid_y), method='nearest')

        self.initialized = True

    def readjust_from_satellite(self):
        """
        Readjust fire position based on satellite imagery.
        Satellite data is the ground truth but updates less frequently.
        """
        global satellite_grid, last_satellite_update
        
        with satellite_lock:
            if satellite_grid is None:
                return False
            
            # Update fire position from satellite
            # mask: 0=vegetation, 1=fire, 2=burnt
            self.satellite_fire_grid = np.zeros_like(satellite_grid, dtype=int)
            self.satellite_fire_grid[satellite_grid == 1] = STATE_BURNING  # Burning
            self.satellite_fire_grid[satellite_grid == 2] = STATE_BURNT   # Burnt
            
            last_satellite_update = time.time()
            self.last_satellite_readjustment = time.time()
            
            fire_count = np.sum(satellite_grid == 1)
            burnt_count = np.sum(satellite_grid == 2)
            print(f"🛰️  Satellite readjustment: {fire_count} fire cells, {burnt_count} burnt cells")
            
            return True

    def predict_from_meteo(self, steps=3):
        """
        Fast prediction based on meteo station data.
        Uses temperature thresholds and weather conditions for propagation.
        """
        if not self.initialized:
            return
        
        # Initialize from meteo station hot spots
        seed_grid = np.zeros((self.size, self.size))
        
        for s in known_sensors.values():
            if s.temperature > FIRE_THRESHOLD:
                px = int((s.location.longitude - self.min_lon) / (self.max_lon - self.min_lon) * (self.size - 1))
                py = int((s.location.latitude - self.min_lat) / (self.max_lat - self.min_lat) * (self.size - 1))

                for dy in range(-2, 3):
                    for dx in range(-2, 3):
                        ny, nx = py+dy, px+dx
                        if 0 <= ny < self.size and 0 <= nx < self.size:
                            seed_grid[ny, nx] = 1

        # If we have satellite data, use it as additional seed
        if self.last_satellite_readjustment > 0:
            seed_grid = np.maximum(seed_grid, self.satellite_fire_grid)

        sim_grid = seed_grid.copy()

        # Propagation simulation
        for step in range(steps):
            new_spread = np.zeros_like(sim_grid)
            rows, cols = np.where(sim_grid >= 0.5)

            for r, c in zip(rows, cols):
                for dr in [-1, 0, 1]:
                    for dc in [-1, 0, 1]:
                        if dr==0 and dc==0:
                            continue
                        nr, nc = r+dr, c+dc

                        if 0 <= nr < self.size and 0 <= nc < self.size:
                            if sim_grid[nr, nc] < 0.5:
                                prob = self._calculate_propagation_probability(r, c, nr, nc)
                                if random.random() < prob:
                                    new_spread[nr, nc] = 1
            sim_grid = np.maximum(sim_grid, new_spread)

        self.meteo_prediction_grid = sim_grid

    def calculate_prediction(self, steps=3):
        """
        Main prediction method combining satellite and meteo data.
        Satellite provides position readjustment, meteo provides high-frequency updates.
        """
        if not self.initialized:
            return
        
        # Try to readjust from satellite if available
        global last_satellite_update
        current_time = time.time()
        
        # Check if we have recent satellite data
        time_since_sat_update = current_time - last_satellite_update
        if time_since_sat_update < SATELLITE_UPDATE_THRESHOLD:
            self.readjust_from_satellite()
        
        # Always run meteo prediction for high-frequency updates
        self.predict_from_meteo(steps)
        
        # Combine satellite position with meteo prediction
        if self.last_satellite_readjustment > 0:
            # 4-state grid: 3=burnt, 2=burning, 1=at risk, 0=vegetation/none
            combined = np.full_like(self.satellite_fire_grid, STATE_VEGETATION, dtype=int)
            # Burnt: satellite says burnt (STATE_BURNT)
            combined[self.satellite_fire_grid == STATE_BURNT] = STATE_BURNT
            # Burning: satellite says burning (STATE_BURNING)
            combined[self.satellite_fire_grid == STATE_BURNING] = STATE_BURNING
            # At risk: not burnt/burning but meteo predicts fire
            at_risk = (self.satellite_fire_grid == STATE_VEGETATION) & (self.meteo_prediction_grid >= 0.5)
            combined[at_risk] = STATE_AT_RISK
            self.display_grid = combined
        else:
            # No satellite data yet, use only meteo: at risk (STATE_AT_RISK)
            self.display_grid = np.full_like(self.meteo_prediction_grid, STATE_VEGETATION, dtype=int)
            self.display_grid[self.meteo_prediction_grid >= 0.5] = STATE_AT_RISK

    def _calculate_propagation_probability(self, r1, c1, r2, c2):
        """
        Calculate fire propagation probability based on weather conditions.
        """
        wd = self.weather_data
        T = wd['temperature'][r2, c2]
        H = wd['air_humidity'][r2, c2]
        Ws = wd['wind_speed'][r2, c2]
        Wd = wd['wind_direction'][r2, c2]

        dryness = (T / 40.0) + (1.0 - (H / 100.0))
        dy, dx = r2 - r1, c2 - c1
        angle = np.degrees(np.arctan2(dy, dx))
        wind_factor = (Ws / 30.0) * np.cos(np.radians(Wd - angle)) if Ws > 0 else 0

        return max(0.0, min(1.0, (0.1 * dryness) + wind_factor))

    # compute global mean wind speed and circular mean wind direction
    def get_global_wind(self):
        if not self.initialized:
            return None, None
        wd = self.weather_data
        if 'wind_speed' not in wd or 'wind_direction' not in wd:
            return None, None
        try:
            ws_grid = wd['wind_speed']
            wd_grid = wd['wind_direction']
            mean_ws = float(np.nanmean(ws_grid))
            angs = np.deg2rad(wd_grid.astype(float))
            sin_sum = np.nansum(np.sin(angs))
            cos_sum = np.nansum(np.cos(angs))
            if sin_sum == 0 and cos_sum == 0:
                mean_dir = 0.0
            else:
                mean_dir = (np.degrees(np.arctan2(sin_sum, cos_sum)) + 360.0) % 360.0
            return round(mean_ws, 1), int(round(mean_dir))
        except Exception:
            return None, None

    def publish_risk_map(self):
        """
        Publish risk map to Kafka.
        Includes metadata about data sources (satellite vs meteo).
        """
        current_time = time.time()
        if current_time - self.last_publish_time < self.publish_interval:
            return

        if not self.initialized:
            return

        lat_step = (self.max_lat - self.min_lat) / self.size
        lon_step = (self.max_lon - self.min_lon) / self.size

        # Only output cells with value > 0 (at risk, burning, burnt)
        rows, cols = np.where(self.display_grid > STATE_VEGETATION)

        cells_data = []
        for r, c in zip(rows, cols):
            cell_lat = self.min_lat + (r * lat_step)
            cell_lon = self.min_lon + (c * lon_step)
            value = int(self.display_grid[r, c])  # 3=burnt, 2=burning, 1=at risk

            cells_data.append({
                "latitude": round(cell_lat, 6),
                "longitude": round(cell_lon, 6),
                "value": value
            })

        if not cells_data:
            return

        payload = {
            "timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat(),
            "cell_size_lat": round(lat_step, 6),
            "cell_size_lon": round(lon_step, 6),
            "cells": cells_data,
            "data_sources": {
                "meteo_stations": len(known_sensors),
                "satellite_age_seconds": round(current_time - last_satellite_update, 1) if last_satellite_update > 0 else None,
                "has_satellite": self.last_satellite_readjustment > 0
            }
        }

        # include global wind info if available
        mean_ws, mean_dir = self.get_global_wind()
        if mean_ws is not None and mean_dir is not None:
            payload["wind_speed"] = mean_ws
            payload["wind_direction"] = mean_dir

        topic = "maps.watch"

        try:
            producer.send(topic, value=payload)
            sat_info = f", sat:{round(current_time - last_satellite_update, 1)}s" if last_satellite_update > 0 else ""
            wind_info = f", wind={mean_ws}m/s @{mean_dir}°" if mean_ws is not None else ""
            print(f"→ Risk map: {len(cells_data)} cells, {len(known_sensors)} meteo{sat_info}{wind_info}")
            self.last_publish_time = current_time
        except Exception as e:
            print(f"Erreur envoi Kafka: {e}")

    def get_sensor_coords(self):
        coords = []
        for s in known_sensors.values():
            px = (s.location.longitude - self.min_lon) / (self.max_lon - self.min_lon) * (self.size - 1) if (self.max_lon - self.min_lon) != 0 else 0
            py = (s.location.latitude - self.min_lat) / (self.max_lat - self.min_lat) * (self.size - 1) if (self.max_lat - self.min_lat) != 0 else 0
            coords.append((px, py))
        return coords

predictor = FirePredictor(size=GRID_SIZE)

def classify_satellite_pixels(arr):
    """
    Classify satellite image pixels into vegetation, fire, and burnt areas.
    """
    # arr: (H, W, 3) RGB
    r = arr[..., 0].astype(np.float32)
    g = arr[..., 1].astype(np.float32)
    b = arr[..., 2].astype(np.float32)

    mask = np.zeros(arr.shape[:2], dtype=np.uint8)  # default: vegetation

    # Burnt: all channels low and similar (dark/gray/black)
    burnt = (r < 80) & (g < 80) & (b < 80) & (np.abs(r-g) < 30) & (np.abs(r-b) < 30) & (np.abs(g-b) < 30)
    # Fire: red is dominant and at least 40 higher than both green and blue
    fire = (r > g + 40) & (r > b + 40)
    # Vegetation: green is dominant and at least 30 higher than both red and blue
    vegetation = (g > r + 30) & (g > b + 30)

    mask[burnt] = 2
    mask[fire] = 1
    mask[vegetation] = 0  # already default

    return mask

def consume_satellite_view():
    """
    Consume satellite imagery for ground truth fire position.
    Satellite updates are less frequent but more accurate for position readjustment.
    """
    global satellite_grid, last_satellite_update, satellite_bbox
    try:
        consumer = KafkaConsumer(
            'sensors.satellite.view',
            bootstrap_servers=[REDPANDA_BROKER],
            value_deserializer=lambda m: m,
            auto_offset_reset='latest',
            group_id='satellite-group'
        )
        print("✓ Satellite consumer connected")
        for message in consumer:
            try:
                msg = json.loads(message.value.decode('utf-8'))
                img_b64 = msg.get("image", "")
                img_bytes = base64.b64decode(img_b64)
                img = Image.open(io.BytesIO(img_bytes)).convert('RGB')
                img = img.resize((GRID_SIZE, GRID_SIZE), Image.BILINEAR)
                arr = np.array(img)
                arr =np.flipud(arr)
                
                mask = classify_satellite_pixels(arr)
                with satellite_lock:
                    satellite_grid = mask
                    last_satellite_update = time.time()
                    bbox = msg.get("bbox", None)
                    if bbox and isinstance(bbox, list) and len(bbox) == 4:
                        # bbox: [min_lon, min_lat, max_lon, max_lat]
                        satellite_bbox = tuple(bbox)
                fire_px = np.sum(mask==1)
                burnt_px = np.sum(mask==2)
                print(f"🛰️  Satellite update: {fire_px} fire pixels, {burnt_px} burnt pixels")
            except Exception as e:
                print(f"Erreur lecture satellite: {e}")
    except KafkaError as e:
        print(f"Erreur Kafka satellite: {e}")

sat_thread = threading.Thread(target=consume_satellite_view, daemon=True)
sat_thread.start()

def process_simulation_step():
    """
    Process one simulation step.
    - Update weather from meteo stations (fast)
    - Run prediction combining satellite position + meteo propagation
    - Publish risk map
    """
    predictor.update_weather_from_sensors(known_sensors)

    predictor.calculate_prediction(steps=PREDICTION_STEPS)
    predictor.publish_risk_map()

    # Status reporting
    ws, wd_dir = predictor.get_global_wind()
    wind_text = f" | vent {ws}m/s @{wd_dir}°" if ws is not None and wd_dir is not None else ""
    
    sat_status = ""
    if predictor.last_satellite_readjustment > 0:
        sat_age = time.time() - predictor.last_satellite_readjustment
        sat_status = f" | sat:{sat_age:.1f}s ago"
    
    return True, f"Feu prédis | {len(known_sensors)} meteo{wind_text}{sat_status}"

if PLOT:
    print("Démarrage en mode GUI (PLOT=True)")

    fig, ax = plt.subplots(figsize=(8, 8))
    # Update colormap for 4 states: vegetation, at risk, burning, burnt
    colors = ['forestgreen', 'gold', 'red', 'black']  # 0, 1, 2, 3
    cmap = ListedColormap(colors)
    bounds = [-0.5, 0.5, 1.5, 2.5, 3.5]  # 0, 1, 2, 3
    norm = BoundaryNorm(bounds, cmap.N)

    matrice = ax.imshow(np.zeros((GRID_SIZE, GRID_SIZE)), cmap=cmap, norm=norm, origin='lower')
    points = ax.scatter([], [], c='cyan', edgecolors='white', s=60, zorder=5)
    titre = ax.set_title("Initialisation...")

    def update(frame):
        success, status_text = process_simulation_step()
        titre.set_text(status_text)

        if not success:
            return [matrice]

        matrice.set_data(predictor.display_grid)

        coords = predictor.get_sensor_coords()
        if coords:
            sx, sy = zip(*coords)
            points.set_offsets(list(zip(sx, sy)))

        return [matrice, points, titre]

    ani = animation.FuncAnimation(fig, update, frames=100, interval=500, blit=False)
    plt.show()

else:
    print("Démarrage en mode HEADLESS (PLOT=False)")
    try:
        while True:
            success, status = process_simulation_step()
            if success:
                pass
            else:
                print(f"[Wait] {status}")
            time.sleep(1.0)

    except KeyboardInterrupt:
        print("Arrêt du script.")