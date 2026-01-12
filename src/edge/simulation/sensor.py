from dataclasses import dataclass,field

@dataclass
class Sensor:
    id: str
    x: int
    y: int

    # Données lues
    read_temp: float = 0.0
    read_air_hum: float = 0.0
    read_soil_hum: float = 0.0
    read_pressure: float = 1013.0
    read_rain: float = 0.0
    read_wind_s: float = 0.0
    read_wind_d: int = 0
    temp_history: list = field(default_factory=list)
    