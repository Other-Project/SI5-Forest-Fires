use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

/// Location information
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct MapMessage {
    /// Timestamp of the map realization
    pub timestamp: DateTime<Utc>,
    /// Latitude size of each grid cell
    pub cell_size_lat: f64,
    /// Longitude size of each grid cell
    pub cell_size_lon: f64,
    /// Grid cell values
    pub cells: Vec<MapCell>
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct MapCell {
    /// Geographic latitude
    pub latitude: f64,
    /// Geographic longitude
    pub longitude: f64,
    /// Value at the grid cell
    pub value: f64,
}