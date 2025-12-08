use crate::raw_messages::*;

pub fn parse_metadata(data: &[u8]) -> Option<RawMetadata> {
    if data.len() < 9 {
        return None;
    }

    Some(RawMetadata {
        device_id: u16::from_be_bytes([data[0], data[1]]),
        timestamp: u32::from_be_bytes([data[2], data[3], data[4], data[5]]),
        battery_voltage: u16::from_be_bytes([data[6], data[7]]),
        status_bits: data[8],
    })
}

pub fn parse_weather_data(data: &[u8]) -> Option<RawWeatherData> {
    if data.len() < 20 {
        return None;
    }

    Some(RawWeatherData {
        metadata: parse_metadata(&data[0..9])?,
        temperature: i16::from_be_bytes([data[9], data[10]]),
        air_humidity: data[11],
        soil_humidity: data[12],
        air_pressure: u16::from_be_bytes([data[13], data[14]]),
        rain: u16::from_be_bytes([data[15], data[16]]),
        wind_speed: data[17],
        wind_direction: u16::from_be_bytes([data[18], data[19]]),
    })
}
