use raw_messages::*;

mod message_parsing {
    use super::*;

    pub fn parse_metadata(data: &[u8]) -> Option<RawMetadata> {
        if data.len() < 8 {
            return None;
        }

        Some(RawMetadata {
            device_id: u16::from_be_bytes([data[0], data[1]]),
            timestamp: u32::from_be_bytes([data[2], data[3], data[4], data[5]]),
            battery_voltage: data[6],
            status_bits: data[7],
        })
    }

    pub fn parse_weather_data(data: &[u8]) -> Option<RawWeatherData> {
        if data.len() < 20 {
            return None;
        }

        Some(RawWeatherData {
            metadata: parse_metadata(&data[0..8])?,
            temperature: i16::from_be_bytes([data[8], data[9]]),
            air_humidity: data[10],
            soil_humidity: data[11],
            air_pressure: u16::from_be_bytes([data[12], data[13]]),
            rain: u16::from_be_bytes([data[14], data[15]]),
            wind_speed: data[16],
            wind_direction: u16::from_be_bytes([data[17], data[18]]),
        })
    }
}
