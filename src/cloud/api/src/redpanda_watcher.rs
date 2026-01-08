use geojson::{FeatureCollection, GeoJson};

pub fn get_geojson() -> GeoJson {
    let feature_collection: FeatureCollection = FeatureCollection { bbox: None, features: vec![], foreign_members: None };
    GeoJson::from(feature_collection)
}
