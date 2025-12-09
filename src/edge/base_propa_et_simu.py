import numpy as np
import matplotlib.pyplot as plt
from dataclasses import dataclass
from scipy.interpolate import griddata
from matplotlib.colors import ListedColormap
import matplotlib.animation as animation
import random

# --- 1. STRUCTURES DE DONNÉES ---
@dataclass
class LocationData:
    latitude: float
    longitude: float
    altitude: float

@dataclass
class DataSensors:
    location: LocationData
    temperature: float
    air_humidity: float
    soil_humidity: float
    wind_speed: float
    wind_direction: int

# --- 2. GÉNÉRATEUR ---
def generate_fake_sensors(n=10):
    sensors = []
    for _ in range(n):
        lat = random.uniform(43.5, 43.6)
        lon = random.uniform(7.0, 7.1)
        alt = random.uniform(100, 500)
        s = DataSensors(
            location=LocationData(lat, lon, alt),
            temperature=random.uniform(20, 35),
            air_humidity=random.uniform(20, 50),
            soil_humidity=random.uniform(10, 40),
            wind_speed=random.uniform(0, 50),
            wind_direction=random.randint(0, 360)
        )
        sensors.append(s)
    return sensors

# --- 3. SIMULATION ---
class FireSimulation:
    def __init__(self, sensors: list[DataSensors], grid_resolution=50):
        self.sensors = sensors
        self.grid_res = grid_resolution
        self.data_grid = {}
        self.fire_grid = None

        # On garde les bornes pour pouvoir dessiner les capteurs plus tard
        lats = [s.location.latitude for s in sensors]
        lons = [s.location.longitude for s in sensors]
        self.min_lat, self.max_lat = min(lats), max(lats)
        self.min_lon, self.max_lon = min(lons), max(lons)

        self._interpolate_data()

    def _interpolate_data(self):
        points = np.array([[s.location.longitude, s.location.latitude] for s in self.sensors])

        # Récupération des valeurs
        temps = np.array([s.temperature for s in self.sensors])
        hums = np.array([s.air_humidity for s in self.sensors])
        soil_hums = np.array([s.soil_humidity for s in self.sensors])
        winds_s = np.array([s.wind_speed for s in self.sensors])
        winds_d = np.array([s.wind_direction for s in self.sensors])
        alts = np.array([s.location.altitude for s in self.sensors])

        # Création de la grille
        grid_x = np.linspace(self.min_lon, self.max_lon, self.grid_res)
        grid_y = np.linspace(self.min_lat, self.max_lat, self.grid_res)
        self.X, self.Y = np.meshgrid(grid_x, grid_y)

        method = 'linear'
        self.data_grid['temp'] = griddata(points, temps, (self.X, self.Y), method=method, fill_value=np.mean(temps))
        self.data_grid['hum'] = griddata(points, hums, (self.X, self.Y), method=method, fill_value=np.mean(hums))
        self.data_grid['soil'] = griddata(points, soil_hums, (self.X, self.Y), method=method, fill_value=np.mean(soil_hums))
        self.data_grid['wind_s'] = griddata(points, winds_s, (self.X, self.Y), method=method, fill_value=np.mean(winds_s))
        self.data_grid['wind_d'] = griddata(points, winds_d, (self.X, self.Y), method=method, fill_value=np.mean(winds_d))
        self.data_grid['alt'] = griddata(points, alts, (self.X, self.Y), method=method, fill_value=np.mean(alts))

        # Nettoyage NaN
        for key in self.data_grid:
            mask = np.isnan(self.data_grid[key])
            self.data_grid[key][mask] = np.nanmean(self.data_grid[key])

        self.fire_grid = np.zeros((self.grid_res, self.grid_res))

    def get_sensor_pixel_coords(self):
        """Convertit Lat/Lon des capteurs en coordonnées Pixels (x, y)"""
        coords = []
        for s in self.sensors:
            # Normalisation entre 0 et 1, puis multiplication par la taille de la grille
            px = (s.location.longitude - self.min_lon) / (self.max_lon - self.min_lon) * (self.grid_res - 1)
            py = (s.location.latitude - self.min_lat) / (self.max_lat - self.min_lat) * (self.grid_res - 1)
            coords.append((px, py))
        return coords

    def start_fire(self, x_idx, y_idx):
        if 0 <= x_idx < self.grid_res and 0 <= y_idx < self.grid_res:
            self.fire_grid[y_idx, x_idx] = 1

    def step(self):
        new_grid = self.fire_grid.copy()
        rows, cols = np.where(self.fire_grid == 1)
        for r, c in zip(rows, cols):
            new_grid[r, c] = -1
            for dr in [-1, 0, 1]:
                for dc in [-1, 0, 1]:
                    if dr == 0 and dc == 0: continue
                    nr, nc = r + dr, c + dc
                    if 0 <= nr < self.grid_res and 0 <= nc < self.grid_res and self.fire_grid[nr, nc] == 0:
                        prob = self._calculate_probability(r, c, nr, nc)
                        if random.random() < prob:
                            new_grid[nr, nc] = 1
        self.fire_grid = new_grid

    def _calculate_probability(self, r1, c1, r2, c2):
        # (Logique identique à ton code précédent)
        T = self.data_grid['temp'][r2, c2]
        H_air = self.data_grid['hum'][r2, c2]
        H_soil = self.data_grid['soil'][r2, c2]
        W_speed = self.data_grid['wind_s'][r2, c2]
        W_dir = self.data_grid['wind_d'][r2, c2]
        Alt1 = self.data_grid['alt'][r1, c1]
        Alt2 = self.data_grid['alt'][r2, c2]

        dryness = (T / 40.0) + (1.0 - (H_air / 100.0)) + (1.0 - (H_soil / 100.0))
        base_prob = 0.15 * dryness

        diff_alt = Alt2 - Alt1
        slope_factor = 0.2 * diff_alt if diff_alt > 0 else -0.1

        dy = r2 - r1
        dx = c2 - c1
        angle_spread = np.degrees(np.arctan2(dy, dx))
        wind_alignment = np.cos(np.radians(W_dir - angle_spread))

        wind_factor = 0
        if W_speed > 0:
            wind_factor = (W_speed / 20.0) * wind_alignment

        prob = base_prob + wind_factor + slope_factor
        return max(0.0, min(1.0, prob))

# --- EXÉCUTION & VISUALISATION ---

# 1. Config
sensors = generate_fake_sensors(15)
sim = FireSimulation(sensors, grid_resolution=50)
sim.start_fire(25, 25)

# Calcul des coordonnées des capteurs en pixels pour l'affichage
sensor_coords = sim.get_sensor_pixel_coords()
sx, sy = zip(*sensor_coords) # Sépare les X et les Y

# Palette personnalisée
# -1 = Gris (Cendres), 0 = Vert (Forêt), 1 = Rouge (Feu)
cmap_perso = ListedColormap(['darkgray', 'forestgreen', 'red'])

# 2. Affichage Statique (4 étapes)
plt.figure(figsize=(14, 4))
for i in range(4):
    plt.subplot(1, 4, i+1)
    plt.title(f"Temps t={i}")

    plt.imshow(sim.fire_grid, cmap=cmap_perso, vmin=-1, vmax=1, origin='lower')

    # Ajout des capteurs (Points Cyan avec bord noir)
    plt.scatter(sx, sy, c='cyan', edgecolors='black', s=50, label='Capteurs')

    if i == 0: plt.legend(loc='upper right', fontsize='small') # Légende juste sur la 1ere

    sim.step()

plt.tight_layout()
plt.show()

# 3. Animation
print("Fermez la fenêtre statique pour lancer l'animation...")
fig, ax = plt.subplots()
ax.set_title("Simulation Live avec Capteurs")

# Fond de carte
matrice = ax.imshow(sim.fire_grid, cmap=cmap_perso, vmin=-1, vmax=1, origin='lower', zorder=1)

points_capteurs = ax.scatter(sx, sy, c='cyan', edgecolors='black', s=60, marker='X', label='Capteurs', zorder=5)
# Capteurs (statiques, on les dessine une fois)
ax.scatter(sx, sy, c='cyan', edgecolors='black', s=60, marker='X', label='Capteurs')
ax.legend()

def update(frame):
    sim.step()
    matrice.set_data(sim.fire_grid)
    return [matrice]

ani = animation.FuncAnimation(fig, update, frames=60, interval=100, blit=True)
plt.show()
