use geojson::{Feature, FeatureCollection, GeoJson, Value, feature::Id};
use serde_json::value::Value as JsonValue;

fn gen_forest_area(area: f64) -> Feature {
    Feature {
        bbox: None,
        geometry: Some(Value::Polygon(vec![vec![
            vec![0.0 + area, 0.0 + area],
            vec![1.0 + area, 0.0 + area],
            vec![1.0 + area, 1.0 + area],
            vec![0.0 + area, 1.0 + area],
            vec![0.0 + area, 0.0 + area],
        ]]).into()),
        id: Some(Id::String(format!("forest_area_{}", area))),
        properties: Some(
            [
                ("status".to_string(), JsonValue::Number(serde_json::Number::from(0))),
            ]
            .iter().cloned().collect(),
        ),
        foreign_members: None,
    }
}

fn gen_geojson() -> String {
    let feature_collection: FeatureCollection =
        (0..10).map(|area| gen_forest_area(area as f64)).collect();

    GeoJson::from(feature_collection).to_string()
}

fn main() {
    println!("{}", gen_geojson());
}
