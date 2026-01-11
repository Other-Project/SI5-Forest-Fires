use log::error;
use rdkafka::Message;
use rust_shared::redpanda_utils;
use std::sync::Arc;
use tokio::sync::{RwLock, broadcast};
use serde::de::DeserializeOwned;


/// A generic async listener that holds the latest value of `T` and
/// notifies subscribers when new values arrive.
pub struct Listener<T> {
    data: Arc<RwLock<T>>,
    notify: broadcast::Sender<()>,
}

impl<T> Listener<T>
where
    T: Clone + Send + Sync + 'static + DeserializeOwned,
{
    pub fn new(initial: T) -> Self {
        let (tx, _rx) = broadcast::channel(16);
        Self {
            data: Arc::new(RwLock::new(initial)),
            notify: tx,
        }
    }

    pub fn subscribe_notifications(&self) -> broadcast::Receiver<()> {
        self.notify.subscribe()
    }

    pub async fn get(&self) -> T {
        self.data.read().await.clone()
    }

    pub async fn init(&self, brokers: String, group_id: String, input_topic: String) {
        let consumer = redpanda_utils::setup_redpanda_consumer(brokers, group_id);
        let data_arc = self.data.clone();
        let notify = self.notify.clone();

        redpanda_utils::subscribe_to_topic(&consumer, input_topic, move |msg| {
            let data_arc = data_arc.clone();
            let notify = notify.clone();
            async move {
                let payload = match msg.payload() {
                    Some(p) => p,
                    None => {
                        error!("No payload in message");
                        return;
                    }
                };

                let parsed: T = match serde_json::from_slice(payload) {
                    Ok(v) => v,
                    Err(e) => {
                        error!("Failed to deserialize payload: {}", e);
                        return;
                    }
                };

                let mut data = data_arc.write().await;
                *data = parsed;

                let _ = notify.send(());
            }
        })
        .await;
    }
}