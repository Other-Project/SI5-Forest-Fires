import numpy as np
from dataclasses import dataclass
import random
import scipy.ndimage
import json
import datetime
import os
import paho.mqtt.client as mqtt
import asyncio
from threading import Thread, Event, Lock

MQTT_BROKER = os.getenv("MQTT_BROKER", "localhost")
MQTT_PORT = int(os.getenv("MQTT_PORT", "1883"))
KEEP_ALIVE = int(os.getenv("KEEP_ALIVE", "60"))

SIZE = int(os.getenv("SIZE", "50"))
PLOT = os.getenv("PLOT", "True").lower() == "true"

@dataclass
class Sensor:
    id: str
    x: int
    y: int

    # Données lues
    read_temp: float = 0.0
    read_air_hum: float = 0.0
    read_soil_hum: float = 0.0
    read_pressure: float = 1013.0
    read_rain: float = 0.0
    read_wind_s: float = 0.0
    read_wind_d: int = 0

class Environment:
    def __init__(self, size=50):
        self.size = size

        self.min_lat, self.max_lat = 43.5, 43.6
        self.min_lon, self.max_lon = 7.0, 7.1

        self.altitude_map = self._generate_smooth_map(100, 500, sigma=3)
        self.temp_map = self._generate_smooth_map(20, 30, sigma=5)
        self.air_hum_map = self._generate_smooth_map(20, 60, sigma=4)
        self.soil_hum_map = self._generate_smooth_map(15, 50, sigma=4)
        self.pressure_map = 1013.0 - (self.altitude_map / 8.3)
        self.rain_map = np.zeros((size, size))

        self.wind_speed_map = np.full((size, size), 30.0)
        self.wind_dir_map = np.full((size, size), 135.0) #nord-est

        self.fire_grid = np.zeros((size, size))

    def _generate_smooth_map(self, low, high, sigma):
        raw = np.random.uniform(low, high, (self.size, self.size))
        return scipy.ndimage.gaussian_filter(raw, sigma=sigma)

    def grid_to_gps(self, x, y):
        lat = self.min_lat + (y / self.size) * (self.max_lat - self.min_lat)
        lon = self.min_lon + (x / self.size) * (self.max_lon - self.min_lon)
        return lat, lon

    def evolve_wind(self):
        delta_dir = np.random.uniform(-2, 2, (self.size, self.size))
        self.wind_dir_map = (self.wind_dir_map + delta_dir) % 360

        delta_speed = np.random.uniform(-1, 1, (self.size, self.size))
        self.wind_speed_map = np.clip(self.wind_speed_map + delta_speed, 0, 100)

    def apply_heat_from_fire(self):
        fire_mask = (self.fire_grid == 1)
        self.temp_map[fire_mask] += 40
        self.temp_map = np.clip(self.temp_map, -20, 800)
        self.air_hum_map[fire_mask] -= 15
        self.air_hum_map = np.clip(self.air_hum_map, 0, 100)
        self.soil_hum_map[fire_mask] -= 10
        self.soil_hum_map = np.clip(self.soil_hum_map, 0, 100)

    def get_probability(self, r1, c1, r2, c2):
        T = self.temp_map[r2, c2]
        H = self.air_hum_map[r2, c2]
        Alt1 = self.altitude_map[r1, c1]
        Alt2 = self.altitude_map[r2, c2]
        W_s = self.wind_speed_map[r2, c2]
        W_d = self.wind_dir_map[r2, c2]

        dryness = (T / 40.0) + (1.0 - (H / 100.0))
        base_prob = 0.10 * dryness
        slope = (Alt2 - Alt1) * 0.2 if (Alt2 > Alt1) else -0.05

        dy, dx = r2 - r1, c2 - c1
        angle_target = np.degrees(np.arctan2(dy, dx))
        wind_alignment = np.cos(np.radians(W_d - angle_target))
        wind_factor = (W_s / 50.0) * wind_alignment if W_s > 0 else 0

        return max(0.0, min(1.0, base_prob + slope + wind_factor))

class SimulationEngine:
    def __init__(self, size=50, n_sensors=10):
        self.env = Environment(size)
        self.sensors = []

        for i in range(n_sensors):
            sx = random.randint(0, size-1)
            sy = random.randint(0, size-1)
            s_id = f"{i:03d}"
            self.sensors.append(Sensor(id=s_id, x=sx, y=sy))

        self.update_sensors()

    def start_fire(self, x, y):
        self.env.fire_grid[y, x] = 1

    def update_sensors(self):
        r = 2
        limit = self.env.size

        for s in self.sensors:
            y_min = max(0, s.y - r)
            y_max = min(limit, s.y + r + 1)
            x_min = max(0, s.x - r)
            x_max = min(limit, s.x + r + 1)

            local_temps = self.env.temp_map[y_min:y_max, x_min:x_max]
            s.read_temp = np.max(local_temps)

            s.read_air_hum = np.mean(self.env.air_hum_map[y_min:y_max, x_min:x_max])
            s.read_soil_hum = np.mean(self.env.soil_hum_map[y_min:y_max, x_min:x_max])
            s.read_pressure = np.mean(self.env.pressure_map[y_min:y_max, x_min:x_max])
            s.read_rain = np.mean(self.env.rain_map[y_min:y_max, x_min:x_max])
            s.read_wind_s = np.mean(self.env.wind_speed_map[y_min:y_max, x_min:x_max])

            s.read_wind_d = self.env.wind_dir_map[s.y, s.x]

    def generate_sensor_payloads(self):
        payloads = []
        now = datetime.datetime.now().isoformat()

        for s in self.sensors:
            lat, lon = self.env.grid_to_gps(s.x, s.y)
            alt = self.env.altitude_map[s.y, s.x]

            payload = {
                "metadata": {
                    "device_id": s.id,
                    "location": {
                        "latitude": round(lat, 6),
                        "longitude": round(lon, 6),
                        "altitude": round(float(alt), 2)
                    },
                    "forest_area": "grand_sambuc",
                    "timestamp": now,
                    "processed_timestamp": now,
                    "battery_voltage": 3.6,
                    "is_charging": False,
                    "data_quality_flag": "OK"
                },
                "temperature": round(float(s.read_temp), 2),
                "air_humidity": round(float(s.read_air_hum), 2),
                "soil_humidity": round(float(s.read_soil_hum), 2),
                "air_pressure": round(float(s.read_pressure), 2),
                "rain": round(float(s.read_rain), 2),
                "wind_speed": round(float(s.read_wind_s), 2),
                "wind_direction": int(s.read_wind_d)
            }
            payloads.append(payload)
        return payloads

    def step(self):
        self.env.evolve_wind()

        new_fire = self.env.fire_grid.copy()
        rows, cols = np.where(self.env.fire_grid == 1)
        for r, c in zip(rows, cols):
            new_fire[r, c] = -1
            for dr in [-1, 0, 1]:
                for dc in [-1, 0, 1]:
                    if dr==0 and dc==0: continue
                    nr, nc = r+dr, c+dc
                    if 0 <= nr < self.env.size and 0 <= nc < self.env.size:
                        if self.env.fire_grid[nr, nc] == 0:
                            prob = self.env.get_probability(r, c, nr, nc)
                            if random.random() < prob:
                                new_fire[nr, nc] = 1
        self.env.fire_grid = new_fire

        self.env.apply_heat_from_fire()
        self.update_sensors()


client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)

try:
    print(f"Connexion au broker MQTT {MQTT_BROKER}...")
    client.connect(MQTT_BROKER, MQTT_PORT, KEEP_ALIVE)
    client.loop_start()
    print("Connecté avec succès !")
except Exception as e:
    print(f"ERREUR: Impossible de se connecter au broker MQTT. {e}")
    exit()

sim = SimulationEngine(size=SIZE, n_sensors=10)
sim.start_fire(25, 25)

# New: shared-state lock and stop event
env_lock = Lock()
stop_event = Event()

async def sim_loop(max_steps=None):
    step_count = 0
    while not stop_event.is_set():

        # Step + read payloads atomically
        with env_lock:
            sim.step()
            payloads = sim.generate_sensor_payloads()

        print(f"\n--- STEP {step_count} ---")
        for p in payloads:
            device_id = p['metadata']['device_id']
            payload_str = json.dumps(p)
            topic = f"/sensors/meteo/{device_id}/raw"
            client.publish(topic, payload_str)
            print(f"-> {device_id} | T:{p['temperature']}°C | Vent:{p['wind_direction']}°")

        step_count += 1
        if max_steps is not None and step_count >= max_steps:
            break

        await asyncio.sleep(1)

def start_sim_thread():
    t = Thread(target=lambda: asyncio.run(sim_loop()), daemon=True)
    t.start()
    return t


# Start SIM in background thread
sim_thread = start_sim_thread()

if PLOT:
    import matplotlib.pyplot as plt
    from matplotlib.colors import ListedColormap
    import matplotlib.animation as animation

    def update_gui(frame):
        if frame == 40:
            titre.set_text("Vent 315°")

        # Safely read fire grid snapshot for display
        with env_lock:
            grid = sim.env.fire_grid.copy()
        im_fire.set_data(grid)
        return [im_fire, titre]

    fig, ax = plt.subplots(figsize=(6, 6))
    cmap = ListedColormap(['black', 'forestgreen', 'red'])
    im_fire = ax.imshow(sim.env.fire_grid, cmap=cmap, vmin=-1, vmax=1, origin='lower')
    sx = [s.x for s in sim.sensors]
    sy = [s.y for s in sim.sensors]
    ax.scatter(sx, sy, c='cyan', edgecolors='white', s=80)
    titre = ax.set_title("Vent 135°")

    ani = animation.FuncAnimation(fig, update_gui, frames=200, interval=1000, blit=False)
    plt.show()
else:
    try:
        sim_thread.join()
    except KeyboardInterrupt:
        pass

# Clean exit
print("Arrêt de la simulation...")
stop_event.set()
sim_thread.join(timeout=5)
client.loop_stop()
client.disconnect()