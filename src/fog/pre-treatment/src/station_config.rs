use serde::Deserialize;

use crate::messages::Location;

/// Station configuration fetched from MinIO
#[derive(Debug, Deserialize)]
pub struct StationConfig {
    /// Unique identifier for the device
    pub device_id: u16,

    /// Device location
    pub location: Location,

    /// Forest area identifier
    pub forest_area: String,
}
