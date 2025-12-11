use crate::messages::{Metadata, Quality, WeatherData};
use crate::raw_messages::RawWeatherData;
use crate::station_config::StationConfig;
use anyhow::Result;
use chrono::{TimeZone, Utc};
use log::info;

/// Process raw weather data and fetch station info from MinIO
pub fn process_weather_data(
    raw_data: RawWeatherData,
    station_metadata: &StationConfig,
) -> Result<WeatherData> {
    // Process metadata (fetch station info from MinIO)
    let metadata = process_metadata(&raw_data.metadata, &station_metadata)?;

    // Convert raw values to processed values
    // Temperature: steps of 0.25°C
    let temperature = (raw_data.temperature as f32) * 0.25 - 20.0;

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
    station_metadata: &StationConfig,
) -> Result<Metadata> {
    // TODO: Fetch station data from MinIO using device_id

    info!("Processing metadata for device {}", raw_metadata.device_id);

    let now = Utc::now();

    Ok(Metadata {
        device_id: station_metadata.device_id.clone(),
        location: station_metadata.location.clone(),
        forest_area: station_metadata.forest_area.clone(),
        timestamp: Utc.timestamp_opt(raw_metadata.timestamp as i64, 0).unwrap(),
        processed_timestamp: now,
        battery_voltage: (raw_metadata.battery_voltage as f32) * 0.01, // Convert 10mV steps to volts
        is_charging: (raw_metadata.status_bits & 0x01) != 0,
        data_quality_flag: Quality::Good, // TODO: TBD
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::messages::Location;
    use crate::parser::parse_weather_data;
    use crate::station_config::StationConfig;
    use chrono::Utc;

    #[test]
    fn test_parse_and_process_from_bytes() {
        let bytes: [u8; 20] = [
            0x00, 0x32, // device_id
            0x69, 0x05, 0x4d, 0x80, // timestamp
            0x01, 0x68, // battery_voltage
            0x00, // status_bits
            0x00, 0xa2, // temperature
            0x3c, // air_humidity
            0x1e, // soil_humidity
            0x27, 0x94, // air_pressure
            0x00, 0x0a, // rain
            0x10, // wind_speed
            0x01, 0x68, // wind_direction
        ];

        // Parse
        let raw = parse_weather_data(&bytes).expect("Parsing should succeed");

        // Create a minimal station config matching the device id
        let station_cfg = StationConfig {
            device_id: raw.metadata.device_id,
            location: Location {
                latitude: 43.700123,
                longitude: 7.266012,
                altitude: 305.5,
            },
            forest_area: "grand_sambuc".to_string(),
        };

        // Process
        let weather = process_weather_data(raw, &station_cfg).expect("Processing should succeed");

        // Assertions (use small epsilon for float comparisons)
        let eps: f32 = 1e-6;

        assert_eq!(weather.metadata.device_id, 50, "Device ID should match");
        assert!((weather.metadata.location.latitude - 43.700123).abs() < eps as f64, "Latitude should match");
        assert!((weather.metadata.location.longitude - 7.266012).abs() < eps as f64, "Longitude should match");
        assert!((weather.metadata.location.altitude - 305.5).abs() < eps, "Altitude should match");
        assert_eq!(weather.metadata.forest_area, "grand_sambuc", "Forest area should match");
        assert_eq!(
            weather.metadata.timestamp, Utc.timestamp_opt(1761955200, 0).unwrap(), // 2025-11-01T00:00:00Z
            "Timestamp should match"
        );
        assert!((weather.metadata.battery_voltage - 3.6).abs() < eps, "Battery voltage should match");
        assert_eq!(weather.metadata.is_charging, false, "Charging status should match");

        assert!((weather.temperature - 20.5).abs() < eps, "Temperature should match");
        assert!((weather.air_humidity - 0.6).abs() < eps, "Air humidity should match");
        assert!((weather.soil_humidity - 0.3).abs() < eps, "Soil humidity should match");
        assert!((weather.air_pressure - 1013.2).abs() < eps, "Air pressure should match");
        assert!((weather.rain - 2.0).abs() < eps, "Rain should match");
        assert!((weather.wind_speed - 3.2).abs() < eps, "Wind speed should match");
        assert!((weather.wind_direction - 180.0).abs() < eps, "Wind direction should match"); 
    }
}
