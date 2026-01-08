use geojson::{FeatureCollection, GeoJson};

use crate::redpanda_utils::{setup_redpanda_consumer, subscribe_to_topic};

pub fn get_geojson() -> GeoJson {
    let feature_collection: FeatureCollection = FeatureCollection {
        bbox: None,
        features: vec![],
        foreign_members: None,
    };
    GeoJson::from(feature_collection)
}

pub async fn init(brokers: String, group_id: String, input_topic: String) {
    let consumer = setup_redpanda_consumer(brokers, group_id);
    subscribe_to_topic(&consumer, input_topic, |msg| async move {
        // Handle the message
        println!("Received message: {:?}", msg);
    })
    .await;
}
