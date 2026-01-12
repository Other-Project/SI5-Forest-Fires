import paho.mqtt.client as mqtt
import os
import threading
import logging

from process import on_message

# Configure logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s"
)

MQTT_BROKER = os.getenv("MQTT_BROKER", "localhost")
MQTT_PORT = int(os.getenv("MQTT_PORT", "1883"))
KEEP_ALIVE = int(os.getenv("KEEP_ALIVE", "60"))

client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
try:
    logging.info(f"Connecting to MQTT broker at '{MQTT_BROKER}'...")
    client.connect(MQTT_BROKER, MQTT_PORT, KEEP_ALIVE)
    client.loop_start()
    logging.info("Connected successfully!")
except Exception as e:
    logging.error(f"Failed to connect to MQTT broker: {e}")
    exit()


client.subscribe("sensors/meteo/+/lora")
client.message_callback_add("sensors/meteo/+/lora", on_message)

logging.info("Subscribed to topic 'sensors/meteo/+/lora'. Waiting for messages...")

stop_event = threading.Event()
try:
    stop_event.wait()
except KeyboardInterrupt:
    logging.info("Disconnecting from MQTT broker...")
    client.loop_stop()
    client.disconnect()
    logging.info("Disconnected successfully!")
