import json
import logging
from paho.mqtt.client import Client, MQTTMessage

from filter import mean_payload
from discrete import payload_to_discrete
from compress import payload_to_bytes

def on_message(client: Client, _: any, msg: MQTTMessage):
    logging.info(f"Received message on topic: {msg.topic}")
    try:
        device_id = msg.topic.split("/")[2]
        payload = json.loads(msg.payload.decode())
        logging.debug(f"Original payload: {payload}")

        # Apply preprocessing steps
        payload = mean_payload(device_id, payload)
        payload = payload_to_discrete(payload)
        payload = payload_to_bytes(payload)

        logging.debug(f"Pretreated payload: {payload}")
        client.publish(f"sensors/meteo/{device_id}/raw", payload)
        logging.info(f"Published pretreated data for device {device_id}")
    except Exception as e:
        logging.error(f"Error processing message: {e}")
