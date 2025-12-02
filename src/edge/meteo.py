import json
import random
import time
from datetime import datetime
from tkinter.constants import TRUE


class ForestSensorSimulator:
    def __init__(self, sensor_id, lat, lon):
        self.sensor_id = sensor_id
        self.location = {"lat": lat, "lon": lon}

        # Valeurs initiales (Conditions d'été standard)
        self.temp = 25.0  # °C
        self.humidity = 55.0  # %
        self.co2 = 410.0  # ppm
        self.wind_speed = 10.0  # km/h
        self.wind_dir = 180  # Degrés

        # État du feu
        self.is_fire_active = False

    def _update_normal_weather(self):
        """Simule des variations naturelles douces"""
        self.temp += random.uniform(-0.5, 0.5)
        self.humidity += random.uniform(-1.0, 1.0)
        # Corrélation : Si temp monte, humidité baisse souvent
        if self.temp > 28:
            self.humidity -= 0.5

        self.co2 += random.uniform(-2, 2)
        self.wind_speed += random.uniform(-2, 2)
        self.wind_dir = (self.wind_dir + random.randint(-10, 10)) % 360

        # Garde-fous (clamping)
        self.humidity = max(10, min(100, self.humidity))
        self.wind_speed = max(0, self.wind_speed)
        self.co2 = max(400, self.co2)

    def _update_fire_conditions(self):
        """Simule un départ de feu (changements drastiques)"""
        # La température grimpe vite
        self.temp += random.uniform(2.0, 5.0)
        # L'humidité chute
        self.humidity -= random.uniform(2.0, 4.0)
        # Le CO2 explose (fumée)
        self.co2 += random.uniform(50, 150)
        # Le vent devient turbulent
        self.wind_speed += random.uniform(0, 5.0)

        # Limites physiques
        self.humidity = max(0, self.humidity)

    def generate_reading(self):
        """Génère un point de donnée complet"""
        if self.is_fire_active:
            self._update_fire_conditions()
        else:
            self._update_normal_weather()

        return {
            "sensor_id": self.sensor_id,
            "timestamp": datetime.now().isoformat(),
            "location": self.location,
            "status": "FIRE" if self.is_fire_active else "OK",
            "measurements": {
                "temperature": round(self.temp, 2),
                "humidity": round(self.humidity, 2),
                "co2": round(self.co2, 2),
                "wind_speed": round(self.wind_speed, 2),
                "wind_direction": self.wind_dir,
            },
        }

    def trigger_fire(self):
        print(f"\n[ALERTE] DÉPART DE FEU SUR LE CAPTEUR {self.sensor_id} !\n")
        self.is_fire_active = True


# --- EXÉCUTION ---

# Création du capteur
sim = ForestSensorSimulator(sensor_id="FOREST_01", lat=43.604, lon=1.444)

i = 0
y = int(random.uniform(15, 50))
try:
    while True:  # Simule les lectures
        data = sim.generate_reading()

        # C'est ici que vous enverriez les données (ex: producer.send(data))
        print(json.dumps(data))

        # Au bout de x itérations, on simule le feu
        if y == i:
            sim.trigger_fire()
            i = 0
            y = int(random.uniform(15, 50))

        time.sleep(1)  # Pause d'une seconde entre les envois
        i += 1

except KeyboardInterrupt:
    print("Simulation arrêtée.")
