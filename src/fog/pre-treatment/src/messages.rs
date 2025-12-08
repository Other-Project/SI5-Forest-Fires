use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

/// Location information
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Location {
    /// Geographic latitude
    pub latitude: f64,
    /// Geographic longitude
    pub longitude: f64,
    /// Altitude in meters
    pub altitude: f32,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub enum Quality {
    Good,
    Moderate,
    Poor,
}

/// Metadata common to all messages
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Metadata {
    /// Unique identifier for the device
    pub device_id: u16,

    /// Device location
    pub location: Location,

    /// Forest area identifier
    pub forest_area: String,

    /// Timestamp of the message
    pub timestamp: DateTime<Utc>,

    /// Timestamp when the message was processed
    pub processed_timestamp: DateTime<Utc>,

    /// Battery voltage in volts
    pub battery_voltage: f32,

    /// Charging status
    pub is_charging: bool,

    /// Data quality flag
    pub data_quality_flag: Quality,
}

/// Weather data message
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct WeatherData {
    /// Metadata common to all messages
    pub metadata: Metadata,

    /// Temperature in Celsius
    pub temperature: f32,
    /// Air humidity (0.0 to 1.0)
    pub air_humidity: f32,
    /// Soil humidity (0.0 to 1.0)
    pub soil_humidity: f32,
    /// Air pressure in hPa
    pub air_pressure: f32,
    /// Rainfall in mm
    pub rain: f32,
    /// Wind speed in m/s
    pub wind_speed: f32,
    /// Wind direction in degrees
    pub wind_direction: f32,
}
