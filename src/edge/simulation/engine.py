from sensor import Sensor
from environment import Environment
import datetime
import numpy as np
import random
import struct

class SimulationEngine:
    def __init__(self, map):
        self.env = Environment(map["width"], map["height"])

        self.x_unit = (map["bbox"][2] - map["bbox"][0]) / map["width"]
        self.y_unit = (map["bbox"][3] - map["bbox"][1]) / map["height"]

        self.sensors = [
            Sensor(
                id=s["device_id"],
                x=int((s["location"]["longitude"] - map["bbox"][0]) / self.x_unit),
                y=int((s["location"]["latitude"] - map["bbox"][1]) / self.y_unit),
            )
            for s in map["sensors"]
        ]

        print(f"Initialized simulation of size {self.env.x_size}x{self.env.y_size} with {len(self.sensors)} sensors.")

        self.update_sensors()

    def start_fire(self, x, y):
        print(f"Starting fire at ({x}, {y})")
        self.env.fire_grid[y, x] = 1

    def update_sensors(self):
        r = 2

        for s in self.sensors:
            y_min = max(0, s.y - r)
            y_max = min(self.env.y_size, s.y + r + 1)
            x_min = max(0, s.x - r)
            x_max = min(self.env.x_size, s.x + r + 1)

            local_temps = self.env.temp_map[y_min:y_max, x_min:x_max]
            s.read_temp = np.max(local_temps)

            s.read_air_hum = np.mean(self.env.air_hum_map[y_min:y_max, x_min:x_max])
            s.read_soil_hum = np.mean(self.env.soil_hum_map[y_min:y_max, x_min:x_max])
            s.read_pressure = np.mean(self.env.pressure_map[y_min:y_max, x_min:x_max])
            s.read_rain = np.mean(self.env.rain_map[y_min:y_max, x_min:x_max])
            s.read_wind_s = np.mean(self.env.wind_speed_map[y_min:y_max, x_min:x_max])

            s.read_wind_d = self.env.wind_dir_map[s.y, s.x]

    def payload_to_bytes(self, payload):
        # Define the mapping of fields to struct format specifiers
        field_mapping = [
            ("metadata.device_id", "H"),  # u16
            ("metadata.timestamp", "I"),  # u32
            ("metadata.battery_voltage", "H"),  # u16
            ("metadata.statut_bits", "B"),  # u8
            ("temperature", "h"),  # i16
            ("air_humidity", "B"),  # u8
            ("soil_humidity", "B"),  # u8
            ("air_pressure", "H"),  # u16
            ("rain", "H"),  # u16
            ("wind_speed", "B"),  # u8
            ("wind_direction", "H"),  # u16
        ]

        # Build the format string dynamically
        fmt = ">" + "".join(f[1] for f in field_mapping)

        # Extract values from the payload based on the mapping
        values = []
        for field, _ in field_mapping:
            keys = field.split(".")
            value = payload
            for key in keys:
                value = value[key]
            values.append(int(value))

        # Pack the data into bytes
        return struct.pack(fmt, *values)

    def generate_sensor_payloads(self):
        payloads = []
        now = datetime.datetime.now()
        battery = 3.6

        for s in self.sensors:
            payload = {
                "metadata": {
                    "device_id": s.id,
                    "timestamp": now.timestamp(),
                    "battery_voltage": int(battery * 100),
                    "statut_bits": 0,
                },
                "temperature": int((s.read_temp + 20.0) / 0.25),
                "air_humidity": int(s.read_air_hum),
                "soil_humidity": int(s.read_soil_hum),
                "air_pressure": int(s.read_pressure / 0.1),
                "rain": int(s.read_rain / 0.2),
                "wind_speed": int(s.read_wind_s / 0.2),
                "wind_direction": int(s.read_wind_d / 0.5),
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
                    if dr == 0 and dc == 0:
                        continue
                    nr, nc = r + dr, c + dc
                    if 0 <= nr < self.env.y_size and 0 <= nc < self.env.x_size:
                        if self.env.fire_grid[nr, nc] == 0:
                            prob = self.env.get_probability(r, c, nr, nc)
                            if random.random() < prob:
                                new_fire[nr, nc] = 1
        self.env.fire_grid = new_fire

        self.env.apply_heat_from_fire()
        self.update_sensors()
