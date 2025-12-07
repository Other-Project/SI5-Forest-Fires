mod messages {
    /// Location information
    pub struct Location {
        /// Geographic latitude
        latitude: f64,
        /// Geographic longitude
        longitude: f64,
        /// Altitude in meters
        altitude: f32,
    }

    pub enum Quality {
        Good,
        Moderate,
        Poor,
    }

    /// Metadata common to all messages
    pub struct Metadata {
        /// Unique identifier for the device
        device_id: u16,

        /// Device location
        location: Location,

        /// Forest area identifier
        forest_area: String,

        /// Timestamp of the message
        timestamp: datetime::DateTime<datetime::Utc>,

        /// Timestamp when the message was processed
        processed_timestamp: datetime::DateTime<datetime::Utc>,

        /// Battery voltage in volts
        battery_voltage: f32,

        /// Charging status
        is_charging: bool,

        /// Data quality flag
        data_quality_flag: Quality,
    }

    /// Weather data message
    pub struct WeatherData {
        /// Metadata common to all messages
        metadata: Metadata,

        /// Temperature in Celsius
        temperature: f32,
        /// Air humidity (0.0 to 1.0)
        air_humidity: f32,
        /// Soil humidity (0.0 to 1.0)
        soil_humidity: f32,
        /// Air pressure in hPa
        air_pressure: f32,
        /// Rainfall in mm
        rain: f32,
        /// Wind speed in m/s
        wind_speed: f32,
        /// Wind direction in degrees
        wind_direction: f32,
    }
}
