import os
import asyncio
from threading import Thread, Event, Lock
import paho.mqtt.client as mqtt
from engine import SimulationEngine
import geojson
import random
import json
from io import BytesIO
from minio import Minio
from minio.error import S3Error

MQTT_BROKER = os.getenv("MQTT_BROKER", "localhost")
MQTT_PORT = int(os.getenv("MQTT_PORT", "1883"))
KEEP_ALIVE = int(os.getenv("KEEP_ALIVE", "60"))

PLOT = os.getenv("PLOT", "True").lower() == "true"

MINIO = os.getenv("MINIO", "True").lower() == "true"
MINIO_ENDPOINT = os.getenv("MINIO_ENDPOINT", "localhost:9000")
MINIO_ACCESS_KEY = os.getenv("MINIO_ACCESS_KEY", "minioadmin")
MINIO_SECRET_KEY = os.getenv("MINIO_SECRET_KEY", "minioadmin123")
MINIO_BUCKET = os.getenv("MINIO_BUCKET", "stations")


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
        object_name=f"{station['device_id']}.json"
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
    x=random.randint(0, map["width"] - 1), y=random.randint(0, map["height"] - 1)
)

# New: shared-state lock and stop event
env_lock = Lock()
stop_event = Event()


async def sim_loop(max_steps=None):
    step_count = 0
    while not stop_event.is_set():
        # Step + read payloads atomically
        with env_lock:
            sim.step()
            payloads = sim.generate_sensor_payloads()

        print(f"Step {step_count}")
        for p in payloads:
            device_id = p["metadata"]["device_id"]
            payload = sim.payload_to_bytes(p)
            topic = f"sensors/meteo/{device_id}/raw"
            client.publish(topic, payload)

        step_count += 1
        if max_steps is not None and step_count >= max_steps:
            break

        await asyncio.sleep(1)


def start_sim_thread():
    t = Thread(target=lambda: asyncio.run(sim_loop()), daemon=True)
    t.start()
    return t


# Start SIM in background thread
sim_thread = start_sim_thread()

if PLOT:
    import matplotlib.pyplot as plt
    from matplotlib.colors import ListedColormap
    import matplotlib.animation as animation

    def update_gui(frame):
        if frame == 40:
            titre.set_text("Vent 315°")

        # Safely read fire grid snapshot for display
        with env_lock:
            grid = sim.env.fire_grid.copy()
        im_fire.set_data(grid)
        return [im_fire, titre]

    fig, ax = plt.subplots(figsize=(6, 6))
    cmap = ListedColormap(["black", "forestgreen", "red"])
    im_fire = ax.imshow(sim.env.fire_grid, cmap=cmap, vmin=-1, vmax=1, origin="lower")
    sx = [s.x for s in sim.sensors]
    sy = [s.y for s in sim.sensors]
    ax.scatter(sx, sy, c="cyan", edgecolors="white", s=80)
    titre = ax.set_title("Vent 135°")

    ani = animation.FuncAnimation(
        fig, update_gui, frames=200, interval=1000, blit=False
    )
    plt.show()
else:
    try:
        sim_thread.join()
    except KeyboardInterrupt:
        pass

# Clean exit
print("Stopping simulation...")
stop_event.set()
sim_thread.join(timeout=5)
client.loop_stop()
client.disconnect()
