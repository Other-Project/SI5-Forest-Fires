from sensor import Sensor
from environment import Environment
import datetime
import numpy as np
import random
import struct
import scipy.ndimage
from PIL import Image
import io

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
        payload = self.payload_to_discrete(payload)

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
                    "battery_voltage": battery,
                    "statut_bits": 0,
                },
                "temperature": s.read_temp,
                "air_humidity": s.read_air_hum,
                "soil_humidity": s.read_soil_hum,
                "air_pressure": s.read_pressure,
                "rain": s.read_rain,
                "wind_speed": s.read_wind_s,
                "wind_direction": s.read_wind_d,
            }
            payloads.append(payload)
        return payloads
    
    def payload_to_discrete(self, payload):
        payload = payload.copy()
        payload["metadata"]["battery_voltage"] = int(payload["metadata"]["battery_voltage"] * 100)
        payload["temperature"] = int((payload["temperature"] + 20.0) / 0.25)
        payload["air_humidity"] = int(payload["air_humidity"])
        payload["soil_humidity"] = int(payload["soil_humidity"])
        payload["air_pressure"] = int(payload["air_pressure"] / 0.1)
        payload["rain"] = int(payload["rain"] / 0.2)
        payload["wind_speed"] = int(payload["wind_speed"] / 0.2)
        payload["wind_direction"] = int(payload["wind_direction"] / 0.5)
        return payload
    
    def generate_satellite_payload(self, downscale_factor=1):
        # Map values to colors: -1=black, 0=green, 1=red
        color_map = {
            -1: [0, 0, 0],       # black
             0: [34, 139, 34],   # forest green
             1: [255, 0, 0],     # red
        }
        grid = self.env.fire_grid
        rgb_array = np.zeros((*grid.shape, 3), dtype=np.uint8)
        for val, color in color_map.items():
            rgb_array[grid == val] = color

        # Apply Gaussian blur to each channel
        blurred = np.zeros_like(rgb_array)
        for i in range(3):
            blurred[..., i] = scipy.ndimage.gaussian_filter(rgb_array[..., i], sigma=1)

        # Downsample the blurred image
        small_rgb = blurred[::downscale_factor, ::downscale_factor, :]

        # Flip vertically to correct y-axis inversion
        small_rgb = np.flipud(small_rgb)

        # Convert to PIL Image
        img = Image.fromarray(small_rgb, mode='RGB')

        # Encode as JPEG bytes
        buf = io.BytesIO()
        img.save(buf, format='JPEG')
        return buf.getvalue()

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
