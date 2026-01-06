import numpy as np
import matplotlib.pyplot as plt
from dataclasses import dataclass
from scipy.interpolate import griddata
from matplotlib.colors import ListedColormap, BoundaryNorm
import matplotlib.animation as animation
import json
from kafka import KafkaConsumer
from kafka.errors import KafkaError
import random
import threading
import time
import re
import os
import datetime

REDPANDA_BROKER = os.getenv("REDPANDA_BROKER", "localhost:19092")

GRID_SIZE = 50
PREDICTION_STEPS = 10
FIRE_THRESHOLD = 60.0

@dataclass
class LocationData:
    latitude: float
    longitude: float
    altitude: float

@dataclass
class SensorData:
    id: str
    location: LocationData
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
            print("Écoute des topics: sensors.meteo.*.data")
            retry_count = 0

            for message in consumer:
                try:
                    p = message.value
                    meta = p['metadata']
                    timestamp = message.timestamp
                    dt = datetime.datetime.fromtimestamp(timestamp / 1000)
                    s = SensorData(
                        id=meta['device_id'],
                        location=LocationData(**meta['location']),
                        temperature=p['temperature'],
                        air_humidity=p['air_humidity'],
                        soil_humidity=p['soil_humidity'],
                        wind_speed=p['wind_speed'],
                        wind_direction=p['wind_direction']
                    )
                    known_sensors[s.id] = s
                    print(f"[{dt.strftime('%Y-%m-%d %H:%M:%S.%f')[:-3]}] {s}")
                    print("")
                except Exception as e:
                    print(f"Erreur parsing: {e}")
        except KafkaError as e:
            retry_count += 1
            print(f"✗ Erreur Kafka: {e}")
            if retry_count < max_retries:
                wait_time = 2 ** retry_count
                print(f"Reconnexion dans {wait_time}s...")
                time.sleep(wait_time)
            else:
                print("Max retries atteint. Arrêt de la consommation.")
                break

# Démarrer la consommation Redpanda dans un thread
consumer_thread = threading.Thread(target=consume_redpanda, daemon=True)
consumer_thread.start()

class FirePredictor:
    def __init__(self, size=50):
        self.size = size
        self.min_lat, self.max_lat = None, None
        self.min_lon, self.max_lon = None, None

        self.weather_data = {}
        self.initialized = False

        self.seed_grid = np.zeros((size, size))
        self.display_grid = np.zeros((size, size))

    def update_weather_from_sensors(self, sensors_dict):
        if len(sensors_dict) < 3: return
        sensors = list(sensors_dict.values())

        # Calculer dynamiquement les limites
        lats = [s.location.latitude for s in sensors]
        lons = [s.location.longitude for s in sensors]

        self.min_lat, self.max_lat = min(lats), max(lats)
        self.min_lon, self.max_lon = min(lons), max(lons)

        # Ajouter une marge de 10%
        lat_margin = (self.max_lat - self.min_lat) * 0.1
        lon_margin = (self.max_lon - self.min_lon) * 0.1
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

        alts = np.array([s.location.altitude for s in sensors])
        self.weather_data['altitude'] = griddata(points, alts, (grid_x, grid_y), method='nearest')
        self.initialized = True

    def calculate_prediction(self, steps=3):
        self.seed_grid = np.zeros((self.size, self.size))

        if not self.initialized: return

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

    def get_sensor_coords(self):
        coords = []
        for s in known_sensors.values():
            px = (s.location.longitude - self.min_lon) / (self.max_lon - self.min_lon) * (self.size - 1)
            py = (s.location.latitude - self.min_lat) / (self.max_lat - self.min_lat) * (self.size - 1)
            coords.append((px, py))
        return coords

predictor = FirePredictor(size=GRID_SIZE)
fig, ax = plt.subplots(figsize=(8, 8))
colors = ['forestgreen', 'orange']
cmap = ListedColormap(colors)
bounds = [-0.5, 0.5, 1.5]
norm = BoundaryNorm(bounds, cmap.N)

matrice = ax.imshow(np.zeros((GRID_SIZE, GRID_SIZE)), cmap=cmap, norm=norm, origin='lower')
points = ax.scatter([], [], c='cyan', edgecolors='white', s=60, zorder=5)
titre = ax.set_title("Initialisation...")

def update(frame):
    predictor.update_weather_from_sensors(known_sensors)

    if not predictor.initialized:
        titre.set_text(f"Attente données Redpanda... ({len(known_sensors)} capteurs)")
        return [matrice]

    predictor.calculate_prediction(steps=PREDICTION_STEPS)
    matrice.set_data(predictor.display_grid)

    coords = predictor.get_sensor_coords()
    if coords:
        sx, sy = zip(*coords)
        points.set_offsets(list(zip(sx, sy)))
        titre.set_text(f"Feu prédis | {len(known_sensors)} capteurs | (+{PREDICTION_STEPS} steps)")
    else:
        titre.set_text("Pas de capteurs valides")

    return [matrice, points, titre]

ani = animation.FuncAnimation(fig, update, frames=100, interval=500, blit=False)
plt.show()