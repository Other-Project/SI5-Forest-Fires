use crate::messages::{Location, Metadata, Quality, WeatherData};
use crate::raw_messages::RawWeatherData;
use anyhow::{anyhow, Result};
use log::info;

/// Process raw weather data and fetch station info from MinIO
pub fn process_weather_data(
    raw_data: RawWeatherData,
    minio_endpoint: String,
) -> Result<WeatherData> {
    // Process metadata (fetch station info from MinIO)
    let metadata = process_metadata(&raw_data.metadata, &minio_endpoint)?;

    // Convert raw values to processed values
    // Temperature: steps of 0.25°C
    let temperature = (raw_data.temperature as f32) * 0.25;

    // Air humidity: steps of 1%, convert to 0.0-1.0
    let air_humidity = (raw_data.air_humidity as f32) / 100.0;

    // Soil humidity: steps of 1%, convert to 0.0-1.0
    let soil_humidity = (raw_data.soil_humidity as f32) / 100.0;

    // Air pressure: steps of 0.1 hPa
    let air_pressure = (raw_data.air_pressure as f32) * 0.1;

    // Rainfall: steps of 0.2 mm
    let rain = (raw_data.rain as f32) * 0.2;

    // Wind speed: steps of 0.2 m/s
    let wind_speed = (raw_data.wind_speed as f32) * 0.2;

    // Wind direction: steps of 0.5°
    let wind_direction = (raw_data.wind_direction as f32) * 0.5;

    Ok(WeatherData {
        metadata,
        temperature,
        air_humidity,
        soil_humidity,
        air_pressure,
        rain,
        wind_speed,
        wind_direction,
    })
}

fn process_metadata(
    raw_metadata: &crate::raw_messages::RawMetadata,
    _minio_endpoint: &str,
) -> Result<Metadata> {
    // TODO: Fetch station data from MinIO using device_id

    info!("Processing metadata for device {}", raw_metadata.device_id);

    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map_err(|e| anyhow!("Failed to get current time: {}", e))?
        .as_secs() as i64;

    Ok(Metadata {
        device_id: raw_metadata.device_id,
        location: Location {
            latitude: 0.0,  // TODO: Fetch from MinIO
            longitude: 0.0, // TODO: Fetch from MinIO
            altitude: 0.0,  // TODO: Fetch from MinIO
        },
        forest_area: "Unknown".to_string(), // TODO: Fetch from MinIO
        timestamp: raw_metadata.timestamp as i64,
        processed_timestamp: now,
        battery_voltage: (raw_metadata.battery_voltage as f32) * 0.01, // Convert 10mV steps to volts
        is_charging: (raw_metadata.status_bits & 0x01) != 0,
        data_quality_flag: Quality::Good, // TODO: TBD
    })
}
