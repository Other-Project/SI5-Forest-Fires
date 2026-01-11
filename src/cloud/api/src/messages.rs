use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ApiMessage<T> {
    pub message_type: String,
    pub payload: Option<T>
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct WindMessage {
    pub speed: f64,
    pub direction: f64,
}