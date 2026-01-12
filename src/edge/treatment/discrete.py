def payload_to_discrete(payload):
    payload = payload.copy()
    payload["metadata"]["battery_voltage"] = int(
        payload["metadata"]["battery_voltage"] * 100
    )
    payload["temperature"] = int((payload["temperature"] + 20.0) / 0.25)
    payload["air_humidity"] = int(payload["air_humidity"])
    payload["soil_humidity"] = int(payload["soil_humidity"])
    payload["air_pressure"] = int(payload["air_pressure"] / 0.1)
    payload["rain"] = int(payload["rain"] / 0.2)
    payload["wind_speed"] = int(payload["wind_speed"] / 0.2)
    payload["wind_direction"] = int(payload["wind_direction"] / 0.5)
    return payload
