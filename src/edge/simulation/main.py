import json
import os
import asyncio
from threading import Thread, Event, Lock
import paho.mqtt.client as mqtt
from engine import SimulationEngine

MQTT_BROKER = os.getenv("MQTT_BROKER", "localhost")
MQTT_PORT = int(os.getenv("MQTT_PORT", "1883"))
KEEP_ALIVE = int(os.getenv("KEEP_ALIVE", "60"))

SIZE = int(os.getenv("SIZE", "50"))
PLOT = os.getenv("PLOT", "True").lower() == "true"


client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)

try:
    print(f"Connexion au broker MQTT {MQTT_BROKER}...")
    client.connect(MQTT_BROKER, MQTT_PORT, KEEP_ALIVE)
    client.loop_start()
    print("Connecté avec succès !")
except Exception as e:
    print(f"ERREUR: Impossible de se connecter au broker MQTT. {e}")
    exit()

sim = SimulationEngine(size=SIZE, n_sensors=10)
sim.start_fire(25, 25)

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

        print(f"\n--- STEP {step_count} ---")
        for p in payloads:
            device_id = p['metadata']['device_id']
            payload_str = json.dumps(p)
            topic = f"sensors/meteo/{device_id}/raw"
            client.publish(topic, payload_str)
            print(f"-> {device_id} | T:{p['temperature']}°C | Vent:{p['wind_direction']}°")

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
    cmap = ListedColormap(['black', 'forestgreen', 'red'])
    im_fire = ax.imshow(sim.env.fire_grid, cmap=cmap, vmin=-1, vmax=1, origin='lower')
    sx = [s.x for s in sim.sensors]
    sy = [s.y for s in sim.sensors]
    ax.scatter(sx, sy, c='cyan', edgecolors='white', s=80)
    titre = ax.set_title("Vent 135°")

    ani = animation.FuncAnimation(fig, update_gui, frames=200, interval=1000, blit=False)
    plt.show()
else:
    try:
        sim_thread.join()
    except KeyboardInterrupt:
        pass

# Clean exit
print("Arrêt de la simulation...")
stop_event.set()
sim_thread.join(timeout=5)
client.loop_stop()
client.disconnect()
