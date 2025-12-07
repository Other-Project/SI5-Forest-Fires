mod raw_messages {
    /// Metadata common to all messages
    pub struct RawMetadata {
        /// Unique identifier for the device
        device_id: u16,

        /// Timestamp of the message
        timestamp: u32,

        /// Battery voltage (by steps of 10mV)
        battery_voltage: u8,

        /// Status bits
        status_bits: u8,
    }

    /// Weather data message
    pub struct RawWeatherData {
        /// Metadata common to all messages
        metadata: RawMetadata,

        /// Temperature (by steps of 0.25°C)
        temperature: i16,
        /// Air humidity (by steps of 1%)
        air_humidity: u8,
        /// Soil humidity (by steps of 1%)
        soil_humidity: u8,
        /// Air pressure (by steps of 0.1 hPa)
        air_pressure: u16,
        /// Rainfall (by steps of 0.2 mm)
        rain: u16,
        /// Wind speed (by steps of 0.2 m/s)
        wind_speed: u8,
        /// Wind direction (by steps of 0.5°)
        wind_direction: u16,
    }
}
