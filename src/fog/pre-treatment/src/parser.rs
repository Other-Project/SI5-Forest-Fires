use crate::raw_messages::*;
use nom::{
    number::complete::{be_i16, be_u16, be_u32, be_u8},
    IResult,
};

fn parse_metadata_i(input: &[u8]) -> IResult<&[u8], RawMetadata> {
    let (input, device_id) = be_u16(input)?;
    let (input, timestamp) = be_u32(input)?;
    let (input, battery_voltage) = be_u16(input)?;
    let (input, status_bits) = be_u8(input)?;
    Ok((
        input,
        RawMetadata {
            device_id,
            timestamp,
            battery_voltage,
            status_bits,
        },
    ))
}

fn parse_weather_i(input: &[u8]) -> IResult<&[u8], RawWeatherData> {
    let (input, metadata) = parse_metadata_i(input)?;
    let (input, temperature) = be_i16(input)?;
    let (input, air_humidity) = be_u8(input)?;
    let (input, soil_humidity) = be_u8(input)?;
    let (input, air_pressure) = be_u16(input)?;
    let (input, rain) = be_u16(input)?;
    let (input, wind_speed) = be_u8(input)?;
    let (input, wind_direction) = be_u16(input)?;
    Ok((
        input,
        RawWeatherData {
            metadata,
            temperature,
            air_humidity,
            soil_humidity,
            air_pressure,
            rain,
            wind_speed,
            wind_direction,
        },
    ))
}

pub fn parse_weather_data(data: &[u8]) -> Result<RawWeatherData, nom::Err<nom::error::Error<&[u8]>>> {
    match parse_weather_i(data) {
        Ok((_, weather)) => Ok(weather),
        Err(err) => Err(err),
    }
}
