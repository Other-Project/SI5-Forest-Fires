/// Metadata common to all messages
pub struct RawMetadata {
    /// Unique identifier for the device
    pub device_id: u16,

    /// Timestamp of the message
    pub timestamp: u32,

    /// Battery voltage (by steps of 10mV)
    pub battery_voltage: u16,

    /// Status bits
    pub status_bits: u8,
}

/// Weather data message
pub struct RawWeatherData {
    /// Metadata common to all messages
    pub metadata: RawMetadata,

    /// Temperature (by steps of 0.25°C)
    pub temperature: i16,
    /// Air humidity (by steps of 1%)
    pub air_humidity: u8,
    /// Soil humidity (by steps of 1%)
    pub soil_humidity: u8,
    /// Air pressure (by steps of 0.1 hPa)
    pub air_pressure: u16,
    /// Rainfall (by steps of 0.2 mm)
    pub rain: u16,
    /// Wind speed (by steps of 0.2 m/s)
    pub wind_speed: u8,
    /// Wind direction (by steps of 0.5°)
    pub wind_direction: u16,
}
