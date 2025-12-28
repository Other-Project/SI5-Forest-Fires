from environment import Environment
from sensor import Sensor
import datetime
import numpy as np
import random

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
