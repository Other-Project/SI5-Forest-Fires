use geojson::{Feature, FeatureCollection, GeoJson, Value, feature::Id};
use serde::{Deserialize, Serialize};
use serde_json::value::Value as JsonValue;

use crate::map_message;

fn gen_forest_area(cell: &map_message::MapCell, cell_size_lat: f64, cell_size_lon: f64) -> Feature {
    Feature {
        bbox: None,
        geometry: Some(
            Value::Polygon(vec![vec![
                vec![cell.longitude, cell.latitude],
                vec![cell.longitude + cell_size_lon, cell.latitude],
                vec![
                    cell.longitude + cell_size_lon,
                    cell.latitude + cell_size_lat,
                ],
                vec![cell.longitude, cell.latitude + cell_size_lat],
                vec![cell.longitude, cell.latitude],
            ]])
            .into(),
        ),
        id: Some(Id::String(format!(
            "forest_area_{}_{}",
            cell.latitude, cell.longitude
        ))),
        properties: Some(
            [
                (
                    "status".to_string(),
                    JsonValue::Number(serde_json::Number::from_f64(cell.value).unwrap()),
                ),
                //("risk".to_string(), JsonValue::Number(serde_json::Number::from_f64(cell.value).unwrap())),
            ]
            .iter()
            .cloned()
            .collect(),
        ),
        foreign_members: None,
    }
}

pub fn gen_geojson(map_message: &map_message::MapMessage) -> String {
    let feature_collection: FeatureCollection = map_message
        .cells
        .iter()
        .map(|cell| gen_forest_area(cell, map_message.cell_size_lat, map_message.cell_size_lon))
        .collect();

    GeoJson::from(feature_collection).to_string()
}

#[derive(Serialize, Deserialize)]
struct WindMessage {
    speed: f64,
    direction: f64,
}

pub fn gen_wind_message(map_message: &map_message::MapMessage) -> Option<String> {
    
    match (map_message.wind_speed, map_message.wind_direction) {
        (Some(speed), Some(direction)) => {
            let wind_message = WindMessage { speed, direction };
            Some(serde_json::to_string(&wind_message).unwrap())
        }
        _ => None,
    }
}
