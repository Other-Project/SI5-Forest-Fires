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

REDPANDA_BROKER = os.getenv("REDPANDA_BROKER", "localhost:19092")
PLOT = os.getenv("PLOT", "True").lower() == "true"

GRID_SIZE = 50
PREDICTION_STEPS = 10
FIRE_THRESHOLD = 60.0

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

known_sensors = {}

def consume_redpanda():
    max_retries = 5
    retry_count = 0

    while retry_count < max_retries:
        try:
            print(f"Tentative de connexion à Redpanda ({retry_count + 1}/{max_retries})...")
            consumer = KafkaConsumer(
                bootstrap_servers=[REDPANDA_BROKER],
                value_deserializer=lambda m: json.loads(m.decode('utf-8')),
                auto_offset_reset='latest',
                group_id='propagation-group'
            )
            pattern = re.compile(r'sensors\.meteo\..*\.data')
            consumer.subscribe(pattern=pattern)
            print("✓ Connecté à Redpanda")
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
                        wind_direction=p['wind_direction']
                    )
                    known_sensors[s.id] = s
                except Exception as e:
                    print(f"Erreur parsing: {e}")
        except KafkaError as e:
            retry_count += 1
            print(f"✗ Erreur Kafka: {e}")
            if retry_count < max_retries:
                time.sleep(2 ** retry_count)
            else:
                break

consumer_thread = threading.Thread(target=consume_redpanda, daemon=True)
consumer_thread.start()

class FirePredictor:
    def __init__(self, size=50):
        self.size = size
        self.min_lat, self.max_lat = 0, 0
        self.min_lon, self.max_lon = 0, 0
        self.weather_data = {}
        self.initialized = False
        self.seed_grid = np.zeros((size, size))
        self.display_grid = np.zeros((size, size))

        self.last_publish_time = 0
        self.publish_interval = 2.0

    def update_weather_from_sensors(self, sensors_dict):
        if len(sensors_dict) < 3: return
        sensors = list(sensors_dict.values())

        lats = [s.location.latitude for s in sensors]
        lons = [s.location.longitude for s in sensors]

        self.min_lat, self.max_lat = min(lats), max(lats)
        self.min_lon, self.max_lon = min(lons), max(lons)

        lat_margin = (self.max_lat - self.min_lat) * 0.1 if self.max_lat != self.min_lat else 0.01
        lon_margin = (self.max_lon - self.min_lon) * 0.1 if self.max_lon != self.min_lon else 0.01

        self.min_lat -= lat_margin
        self.max_lat += lat_margin
        self.min_lon -= lon_margin
        self.max_lon += lon_margin

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

    def calculate_prediction(self, steps=3):
        if not self.initialized: return
        self.seed_grid = np.zeros((self.size, self.size))

        for s in known_sensors.values():
            if s.temperature > FIRE_THRESHOLD:
                px = int((s.location.longitude - self.min_lon) / (self.max_lon - self.min_lon) * (self.size - 1))
                py = int((s.location.latitude - self.min_lat) / (self.max_lat - self.min_lat) * (self.size - 1))

                for dy in range(-2, 3):
                    for dx in range(-2, 3):
                        ny, nx = py+dy, px+dx
                        if 0 <= ny < self.size and 0 <= nx < self.size:
                            self.seed_grid[ny, nx] = 1

        sim_grid = self.seed_grid.copy()

        for _ in range(steps):
            new_spread = np.zeros_like(sim_grid)
            rows, cols = np.where(sim_grid == 1)

            for r, c in zip(rows, cols):
                for dr in [-1, 0, 1]:
                    for dc in [-1, 0, 1]:
                        if dr==0 and dc==0: continue
                        nr, nc = r+dr, c+dc

                        if 0 <= nr < self.size and 0 <= nc < self.size:
                            if sim_grid[nr, nc] == 0:
                                prob = self._calculate_proba(r, c, nr, nc)
                                if random.random() < prob:
                                    new_spread[nr, nc] = 1
            sim_grid = np.maximum(sim_grid, new_spread)

        self.display_grid = sim_grid

    def _calculate_proba(self, r1, c1, r2, c2):
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

    def publish_risk_map(self):
        current_time = time.time()
        if current_time - self.last_publish_time < self.publish_interval:
            return

        if not self.initialized or not known_sensors:
            return

        primary_area = next(iter(known_sensors.values())).forest_area
        lat_step = (self.max_lat - self.min_lat) / self.size
        lon_step = (self.max_lon - self.min_lon) / self.size

        rows, cols = np.where(self.display_grid == 1)

        cells_data = []
        for r, c in zip(rows, cols):
            cell_lat = self.min_lat + (r * lat_step)
            cell_lon = self.min_lon + (c * lon_step)

            cells_data.append({
                "latitude": round(cell_lat, 6),
                "longitude": round(cell_lon, 6),
                "value": 1.0
            })

        if not cells_data: return

        payload = {
            "timestamp": datetime.datetime.utcnow().replace(microsecond=0).isoformat() + "Z",
            "cell_size_lat": round(lat_step, 6),
            "cell_size_lon": round(lon_step, 6),
            "cells": cells_data
        }

        topic = f"alerts.risk.maps.risk.{primary_area}"

        try:
            producer.send(topic, value=payload)
            print(f"-> Sent risk map to {topic} ({len(cells_data)} cells)")
            self.last_publish_time = current_time
        except Exception as e:
            print(f"Erreur envoi Kafka: {e}")

    def get_sensor_coords(self):
        coords = []
        for s in known_sensors.values():
            px = (s.location.longitude - self.min_lon) / (self.max_lon - self.min_lon) * (self.size - 1)
            py = (s.location.latitude - self.min_lat) / (self.max_lat - self.min_lat) * (self.size - 1)
            coords.append((px, py))
        return coords

predictor = FirePredictor(size=GRID_SIZE)

def process_simulation_step():
    predictor.update_weather_from_sensors(known_sensors)

    if not predictor.initialized:
        return False, f"Attente données Redpanda... ({len(known_sensors)} capteurs)"

    predictor.calculate_prediction(steps=PREDICTION_STEPS)
    predictor.publish_risk_map()

    return True, f"Feu prédis | {len(known_sensors)} capteurs"

if PLOT:
    print("Démarrage en mode GUI (PLOT=True)")

    fig, ax = plt.subplots(figsize=(8, 8))
    colors = ['forestgreen', 'orange']
    cmap = ListedColormap(colors)
    bounds = [-0.5, 0.5, 1.5]
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