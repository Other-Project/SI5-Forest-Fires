use std::time::Duration;

use log::{error, info};

use minio::s3::creds::StaticProvider;
use minio::s3::http::BaseUrl;
use minio::s3::types::S3Api;
use minio::s3::MinioClient;
use rdkafka::message::OwnedMessage;
use rdkafka::producer::FutureRecord;
use rdkafka::Message;

use rust_shared::redpanda_utils;
use strfmt::strfmt;

use crate::parser::parse_weather_data;
use crate::process::process_weather_data;
use crate::station_config::StationConfig;

// Process weather data message
async fn process_message(
    msg: OwnedMessage,
    minio_client: &MinioClient,
    minio_bucket: &str,
) -> Result<(u16, String), String> {
    info!("Processing message at offset {}", msg.offset());

    // Extract payload as byte array
    let payload = msg
        .payload()
        .ok_or_else(|| "No payload in message".to_string())?;

    // Parse payload as RawWeatherData
    let raw_weather_data =
        parse_weather_data(payload).map_err(|e| format!("Failed to parse weather data: {}", e))?;

    // Fetch station config from MinIO
    let station_config_bytes = minio_client
        .get_object(
            minio_bucket,
            format!("{}.json", raw_weather_data.metadata.device_id),
        )
        .build()
        .send()
        .await
        .map_err(|e| {
            format!(
                "Failed to fetch station ({}) config from MinIO: {}",
                raw_weather_data.metadata.device_id, e
            )
        })?
        .content()
        .map_err(|e| {
            format!(
                "Failed to read station ({}) config content: {}",
                raw_weather_data.metadata.device_id, e
            )
        })?
        .to_segmented_bytes()
        .await
        .map_err(|e| {
            format!(
                "Failed to convert station ({}) config to bytes: {}",
                raw_weather_data.metadata.device_id, e
            )
        })?
        .to_bytes();
    let station_config: StationConfig =
        serde_json::from_slice(&station_config_bytes).map_err(|e| {
            format!(
                "Failed to parse station ({}) config JSON: {}",
                raw_weather_data.metadata.device_id, e
            )
        })?;

    // Process and convert to WeatherData
    let weather_data = process_weather_data(raw_weather_data, &station_config)
        .map_err(|e| format!("Failed to process weather data: {}", e))?;

    // Serialize to JSON for publishing
    let json =
        serde_json::to_string(&weather_data).map_err(|e| format!("Failed to serialize: {}", e))?;

    info!(
        "Successfully processed message from device {}",
        weather_data.metadata.device_id
    );
    Ok((weather_data.metadata.device_id, json))
}

pub async fn run_async_processor(
    brokers: String,
    group_id: String,
    input_topic: String,
    output_topic: String,
    minio_endpoint: String,
    minio_access_key: String,
    minio_secret_key: String,
    minio_bucket: String,
) {
    // Create the `StreamConsumer`, to receive the messages from the topic in form of a `Stream`.
    let consumer = redpanda_utils::setup_redpanda_consumer(brokers.clone(), group_id.clone());
    let producer = redpanda_utils::setup_redpanda_producer(brokers.clone());

    let base_url = minio_endpoint.parse::<BaseUrl>().unwrap();
    let static_provider = StaticProvider::new(&minio_access_key, &minio_secret_key, None);
    let minio_client =
        std::sync::Arc::new(MinioClient::new(base_url, Some(static_provider), None, None).unwrap());

    redpanda_utils::subscribe_to_topic(&consumer, input_topic.clone(), {
        move |msg| {
            let producer = producer.clone();
            let output_topic = output_topic.clone();
            let minio_client = minio_client.clone();
            let minio_bucket = minio_bucket.clone();
            async move {
                match process_message(msg, &*minio_client, &minio_bucket).await {
                    Ok(json_payload) => {
                        let mut vars: std::collections::HashMap<String, String> =
                            std::collections::HashMap::new();
                        vars.insert("device_id".to_string(), json_payload.0.to_string());

                        if let Ok(topic_name) = strfmt(&output_topic, &vars) {
                            let produce_future = producer.send(
                                FutureRecord::<(), [u8]>::to(topic_name.as_str())
                                    .payload(json_payload.1.as_bytes()),
                                Duration::from_secs(5),
                            );
                            match produce_future.await {
                                Ok(delivery) => info!("Published message: {:?}", delivery),
                                Err((e, _)) => error!("Failed to publish message: {:?}", e),
                            }
                        } else {
                            error!("Failed to format output topic string: {}", output_topic);
                        }
                    }
                    Err(e) => error!("Failed to process message logic: {}", e),
                }
            }
        }
    })
    .await;

    info!("Stream processing terminated");
}
