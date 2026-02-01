# Forest fire prevention and detection

<p align=center>
    <img alt="icon" src="src/cloud/webui/public/icon.svg" width="20%" /><br/>
    <span>Project realized by <a href="https://github.com/06Games">Evan Galli</a>, <a href="https://github.com/JokerOnWeed">Anthony Vasta</a> and <a href="https://github.com/sachaCast">Sacha Castillejos</a>
    <br/>as part of the <b>Fundamentals and challenges of cyber-physical systems</b>, <b>From IoT to cyber-physical systems</b> and <b>Development of cyber-physical systems</b> courses.</span>
</p>

## Overview

This project simulates and monitors forest fires using a distributed cyber-physical system architecture. It collects sensor data from an edge environment, processes it in a fog layer, and visualizes it in the cloud.

> [!NOTE]  
> Some AI tools, including GitHub Copilot and Google Gemini, were used to help write parts of the code and documentation.

## Getting Started

### Prerequisites

[Docker](https://docs.docker.com/engine/install/) and [Docker Compose](https://docs.docker.com/compose/install/linux/) must be installed on your machine to run the project.

[UV](https://docs.astral.sh/uv/) is required to run the simulation outside of Docker.

### Running the Project

The entire stack can be launched using the main compose file:

```bash
docker compose up -d --build
```

You might want to start the simulation manually to see the GUI updating in real-time:

```bash
docker compose stop simulation && uv --directory src/edge/simulation run main.py
```

You can do the same for the propagation service:

```bashbash
docker compose stop propagation && uv --directory src/fog/propagation run main.py
```

### Accessing Services

| Service              | URL                                            | Description               | Credentials                                   |
| -------------------- | ---------------------------------------------- | ------------------------- | --------------------------------------------- |
| **Web Application**  | [http://localhost](http://localhost)           | Main Dashboard            |                                               |
| **Redpanda Console** | [http://localhost:8080](http://localhost:8080) | Kafka/Redpanda Management |                                               |
| **MinIO Console**    | [http://localhost:9090](http://localhost:9090) | Storage Management        | User: `minioadmin`, Password: `minioadmin123` |
| **InfluxDB**         | [http://localhost:8086](http://localhost:8086) | Time Series Database      | User: `admin`, Password: `adminpass123`       |

## Architecture

The system is divided into three layers:

*   **Edge**: 
    * **Simulation**: Simulates environmental sensors (Temperature, Humidity, etc.) and sends data via MQTT.
    * **Treatment**: Receives raw sensor data, applies initial filtering, and forwards it to the fog layer via MQTT.
*   **Fog**:
    *   **Pre-treatment**: Rust service to clean and format raw sensor data.
    *   **Propagation**: Python service to calculate fire spread risks.
*   **Cloud**:
    *   **GeoJSON Producer**: Generates map data for the frontend.
    *   **API**: Rust backend serving data.
    *   **Web UI**: React application for visualization.

## Technologies

*   **Languages**: Rust, Python (with uv), TypeScript (SolidJS/Bun/Vite)
*   **Messaging**: MQTT (Mosquitto), Kafka (Redpanda)
*   **Storage**: MinIO, InfluxDB
*   **Infrastructure**: Docker

## Demo

https://github.com/user-attachments/assets/3e4292e0-58c5-4bed-bbf1-a76257120b20

<table>
    <tr>
        <td><img alt="webui1" src="https://github.com/user-attachments/assets/9fdacbd1-388d-44d3-b872-13c685e2dad5" /></td>
        <td><img alt="webui2" src="https://github.com/user-attachments/assets/c51f4f37-f6bb-4a3e-97f0-7f8aa9aa24a1" /></td>
    <tr>
    </tr>
        <td><img alt="simu1" src="https://github.com/user-attachments/assets/8318bbf3-ce41-49c9-9009-2beba167885c" /></td>
        <td><img alt="simu2" src="https://github.com/user-attachments/assets/2c9308ab-774c-47c6-a866-e1d2ebaded48" /></td>
    <tr>
    </tr>
        <td><img alt="redpanda" src="https://github.com/user-attachments/assets/e5fb2425-70cf-4586-905c-c76e7af60f13" /></td>
        <td><img alt="redpanda_JSONdata" src="https://github.com/user-attachments/assets/e8b7df12-5c27-4bed-8259-ed7cf78622dc" /></td>
    <tr>
    </tr>
        <td><img alt="minIO" src="https://github.com/user-attachments/assets/b6427cf7-4260-4403-9195-b45ccee8d934" /></td>
        <td><img alt="influxDBstats" src="https://github.com/user-attachments/assets/eafc5217-0bd0-4ad7-b489-1d8d143ad271" /></td>
    </tr>
</table>


