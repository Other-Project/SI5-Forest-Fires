from filters import apply_median_filter
import paho.mqtt.client as mqtt
import os
from dataclasses import dataclass,field


MQTT_BROKER = os.getenv("MQTT_BROKER", "localhost")
MQTT_PORT = int(os.getenv("MQTT_PORT", "1883"))
KEEP_ALIVE = int(os.getenv("KEEP_ALIVE", "60"))

client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
try:
    print(f"Connecting to MQTT broker at '{MQTT_BROKER}'...")
    client.connect(MQTT_BROKER, MQTT_PORT, KEEP_ALIVE)
    client.loop_start()
    print("Connected successfully!")
except Exception as e:
    print(f"Failed to connect to MQTT broker: {e}")
    exit()


k = 2  # Paramètre du filtre (voisinage de 2k + 1 = 5 échantillons)


temp_history: list = field(default_factory=list)

# Initialisation de l'historique pour chaque capteur
for s in self.sensors:
    s.temp_history = []


# mise à jour de l'historique
s.temp_history.append(s.read_temp)

# On limite l'historique à 20 mesures pour ne pas saturer la mémoire
if len(s.temp_history) > 20:
    s.temp_history.pop(0)




# Application du filtre médian sur l'historique
filtered_temps = apply_median_filter(s.temp_history, k)

# On récupère la dernière valeur filtrée (y[n])
temp_value = filtered_temps[-1] if len(filtered_temps) > 0 else s.read_temp


client.loop_stop()
client.disconnect()
