use geojson::{FeatureCollection, GeoJson};
use log::error;
use once_cell::sync::Lazy;
use rdkafka::Message;
use rust_shared::redpanda_utils;
use std::sync::Arc;
use tokio::sync::RwLock;

static GEOJSON_DATA: Lazy<Arc<RwLock<GeoJson>>> = Lazy::new(|| {
    Arc::new(RwLock::new(GeoJson::from(FeatureCollection {
        bbox: None,
        features: vec![],
        foreign_members: None,
    })))
});

pub async fn get_geojson() -> GeoJson {
    GEOJSON_DATA.read().await.clone()
}

pub async fn init(brokers: String, group_id: String, input_topic: String) {
    let consumer = redpanda_utils::setup_redpanda_consumer(brokers, group_id);
    redpanda_utils::subscribe_to_topic(&consumer, input_topic, move |msg| {
        let geojson_data = GEOJSON_DATA.clone();
        async move {
            let payload = match msg.payload() {
                Some(p) => p,
                None => {
                    error!("No payload in message");
                    return;
                }
            };

            let geojson: GeoJson = match serde_json::from_slice(payload) {
                Ok(gj) => gj,
                Err(e) => {
                    error!("Failed to deserialize GeoJSON: {}", e);
                    return;
                }
            };

            let mut data = geojson_data.write().await;
            *data = geojson;
        }
    })
    .await;
}
