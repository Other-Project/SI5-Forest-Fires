import struct

ranges = {
    "H": (0, 65535),      # u16
    "I": (0, 4294967295), # u32
    "h": (-32768, 32767), # i16
    "B": (0, 255),        # u8
}


def payload_to_bytes(payload):
    # Define the mapping of fields to struct format specifiers
    field_mapping = [
        ("metadata.device_id", "H"),  # u16
        ("metadata.timestamp", "I"),  # u32
        ("metadata.battery_voltage", "H"),  # u16
        ("metadata.statut_bits", "B"),  # u8
        ("temperature", "h"),  # i16
        ("air_humidity", "B"),  # u8
        ("soil_humidity", "B"),  # u8
        ("air_pressure", "H"),  # u16
        ("rain", "H"),  # u16
        ("wind_speed", "B"),  # u8
        ("wind_direction", "H"),  # u16
    ]

    # Build the format string dynamically
    fmt = ">" + "".join(f[1] for f in field_mapping)

    # Extract values from the payload based on the mapping
    values = []
    for field, fmt_char in field_mapping:
        keys = field.split(".")
        value = payload
        (range_min, range_max) = ranges[fmt_char]
        for key in keys:
            value = value[key]
        values.append(max(range_min, min(range_max, int(value))))

    # Pack the data into bytes
    return struct.pack(fmt, *values)
