import os
import asyncio
from threading import Thread, Event, Lock
import numpy as np
import paho.mqtt.client as mqtt
from engine import SimulationEngine
import geojson
import random
import json
from io import BytesIO
from minio import Minio
from minio.error import S3Error
import base64

MQTT_BROKER = os.getenv("MQTT_BROKER", "localhost")
MQTT_PORT = int(os.getenv("MQTT_PORT", "1883"))
KEEP_ALIVE = int(os.getenv("KEEP_ALIVE", "60"))

PLOT = os.getenv("PLOT", "True").lower() == "true"

MINIO = os.getenv("MINIO", "True").lower() == "true"
MINIO_ENDPOINT = os.getenv("MINIO_ENDPOINT", "localhost:9000")
MINIO_ACCESS_KEY = os.getenv("MINIO_ACCESS_KEY", "minioadmin")
MINIO_SECRET_KEY = os.getenv("MINIO_SECRET_KEY", "minioadmin123")
MINIO_BUCKET = os.getenv("MINIO_BUCKET", "stations")

START_MARGIN = 15

def parse_geojson(file_path):
    try:
        with open(file_path, "r") as f:
            geojson_data = geojson.load(f)
        data = {
            "bbox": geojson_data.bbox,
            "width": 64,
            "height": 64,
            "sensors": [],
        }

        for i, feature in enumerate(geojson_data.features):
            if feature.geometry.type == "Point":
                coords = feature.geometry.coordinates
                data["sensors"].append(
                    {
                        "device_id": i,
                        "location": {
                            "latitude": coords[1],
                            "longitude": coords[0],
                            "altitude": 0,
                        },
                        "forest_area": feature.properties.get("forest_area", "unknown"),
                    }
                )
        return data
    except Exception as e:
        print(f"Can't parse GeoJSON file: {e}")
        return None


def upload_station_to_minio(minio_client, station):
    try:
        object_name = f"{station['device_id']}.json"
        data_bytes = json.dumps(station).encode("utf-8")
        minio_client.put_object(
            bucket_name=MINIO_BUCKET,
            object_name=object_name,
            data=BytesIO(data_bytes),
            length=len(data_bytes),
            content_type="application/octet-stream",
        )
        print(f"Uploaded {MINIO_BUCKET}/{object_name} to MinIO")
    except Exception as e:
        print(f"Failed to upload to MinIO: {e}")


client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)

try:
    print(f"Connecting to MQTT broker at '{MQTT_BROKER}'...")
    client.connect(MQTT_BROKER, MQTT_PORT, KEEP_ALIVE)
    client.loop_start()
    print("Connected successfully!")
except Exception as e:
    print(f"Failed to connect to MQTT broker: {e}")
    exit()

GEOJSON_FILE = os.getenv("GEOJSON_FILE", "map.geojson")
map = parse_geojson(GEOJSON_FILE)
if map is None:
    exit(1)

if MINIO:
    try:
        minio_client = Minio(
            MINIO_ENDPOINT,
            access_key=MINIO_ACCESS_KEY,
            secret_key=MINIO_SECRET_KEY,
            secure=False,
        )
        print(f"Connected to MinIO at '{MINIO_ENDPOINT}'")

        found = minio_client.bucket_exists(MINIO_BUCKET)
        if not found:
            minio_client.make_bucket(MINIO_BUCKET)
            print(f"Created bucket '{MINIO_BUCKET}'")

        for station in map["sensors"]:
            upload_station_to_minio(minio_client, station)
    except S3Error as e:
        print(f"Failed to connect to MinIO: {e}")
        exit(1)

sim = SimulationEngine(map)
sim.start_fire(
    x=random.randint(START_MARGIN, map["width"] - 1 - START_MARGIN),
    y=random.randint(START_MARGIN, map["height"] - 1 - START_MARGIN),
)

# New: shared-state lock and stop event
env_lock = Lock()
stop_event = Event()

# --- Satellite sending thread ---
def satellite_sender_thread(delay=5):
    step_count = 0
    while not stop_event.is_set():
        with env_lock:
            sat_payload = sim.generate_satellite_payload()
        sat_topic = "sensors/satellite/view"

        img_b64 = base64.b64encode(sat_payload).decode("ascii")
        wrapper = {"bbox": map.get("bbox"), "image": img_b64}
        client.publish(sat_topic, json.dumps(wrapper))

        print("-> Satellite | Fire grid data sent (threaded)")
        step_count += 1
        stop_event.wait(delay)

def start_satellite_thread(delay=5):
    t = Thread(target=lambda: satellite_sender_thread(delay), daemon=True)
    t.start()
    return t

# --- Simulation loop ---
async def sim_loop(max_steps=None):
    step_count = 0
    while not stop_event.is_set():
        with env_lock:
            sim.step()
            payloads = sim.generate_sensor_payloads()
        print(f"Step {step_count}")
        for p in payloads:
            device_id = p["metadata"]["device_id"]
            payload = sim.payload_to_bytes(p)
            topic = f"sensors/meteo/{device_id}/raw"
            client.publish(topic, payload)
            print(
                f"-> {device_id} | T:{float(p['temperature']):.2f}°C | Vent:{int(p['wind_direction'])}°"
            )
        step_count += 1
        if max_steps is not None and step_count >= max_steps:
            break
        await asyncio.sleep(1)

def start_sim_thread():
    t = Thread(target=lambda: asyncio.run(sim_loop()), daemon=True)
    t.start()
    return t

# Start SIM and satellite sender in background threads
sim_thread = start_sim_thread()
sat_thread = start_satellite_thread(delay=5)

if PLOT:
    import matplotlib.pyplot as plt
    from matplotlib.colors import ListedColormap
    import matplotlib.animation as animation
    from PIL import Image

    def decode_sat_image(payload_bytes):
        try:
            img = Image.open(BytesIO(payload_bytes))
            arr = np.array(img)
            return arr
        except Exception:
            # fallback: blank image
            return np.zeros((map["height"] // 4, map["width"] // 4, 3), dtype=np.uint8)

    def update_gui(frame):
        # Safely read fire grid snapshot for display
        with env_lock:
            grid = sim.env.fire_grid.copy()
            sat_payload_bytes = sim.generate_satellite_payload()
        im_fire.set_data(grid)
        titre.set_text(
            f"Vent {sim.env.wind_speed_map.mean():.1f} km/h à {sim.env.wind_dir_map.mean():.1f}°"
        )
        # Update satellite view
        sat_img = decode_sat_image(sat_payload_bytes)
        im_sat.set_data(sat_img)
        return [im_fire, im_sat, titre]

    fig, axs = plt.subplots(1, 2, figsize=(12, 6))
    cmap = ListedColormap(["black", "forestgreen", "red"])
    # Fire grid
    im_fire = axs[0].imshow(sim.env.fire_grid, cmap=cmap, vmin=-1, vmax=1, origin="lower")
    sx = [s.x for s in sim.sensors]
    sy = [s.y for s in sim.sensors]
    axs[0].scatter(sx, sy, c="cyan", edgecolors="white", s=80)
    titre = axs[0].set_title("")

    # Satellite view preview
    sat_payload_bytes = sim.generate_satellite_payload()
    sat_img = decode_sat_image(sat_payload_bytes)
    im_sat = axs[1].imshow(sat_img)
    axs[1].set_title("Satellite View")

    ani = animation.FuncAnimation(
        fig, update_gui, frames=200, interval=1000, blit=False
    )
    plt.show()
else:
    try:
        sim_thread.join()
        sat_thread.join()
    except KeyboardInterrupt:
        pass

# Clean exit
print("Stopping simulation...")
stop_event.set()
sim_thread.join(timeout=5)
sat_thread.join(timeout=5)
client.loop_stop()
client.disconnect()
