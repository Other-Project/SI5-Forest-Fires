import numpy as np
import scipy.ndimage

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
