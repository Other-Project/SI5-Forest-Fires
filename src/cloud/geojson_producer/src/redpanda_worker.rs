use std::time::Duration;

use log::{error, info};

use minio::s3::MinioClient;
use minio::s3::builders::ObjectContent;
use minio::s3::creds::StaticProvider;
use minio::s3::http::BaseUrl;
use minio::s3::types::S3Api;
use rdkafka::Message;
use rdkafka::message::OwnedMessage;
use rdkafka::producer::FutureRecord;

use rust_shared::redpanda_utils;
use strfmt::strfmt;

use crate::map_message;
use crate::process::{gen_geojson, gen_wind_message};

// Process weather data message
async fn process_message(msg: OwnedMessage) -> Result<(String, Option<String>), String> {
    info!("Processing message at offset {}", msg.offset());

    // Extract payload as byte array
    let payload = msg
        .payload()
        .ok_or_else(|| "No payload in message".to_string())?;

    // Process
    let map_message: map_message::MapMessage = serde_json::from_slice(payload)
        .map_err(|e| format!("Failed to deserialize MapMessage: {}", e))?;

    // Serialize to JSON for publishing
    let map_json = gen_geojson(&map_message);
    let wind_json = gen_wind_message(&map_message);
    Ok((map_json, wind_json))
}

async fn upload_to_minio(
    minio_client: std::sync::Arc<MinioClient>,
    bucket: String,
    json_payload: String,
) -> Result<(), minio::s3::error::Error> {
    let exists = minio_client
        .bucket_exists(&bucket)
        .build()
        .send()
        .await?
        .exists();
    if !exists {
        info!("Bucket {} does not exist. Creating...", bucket);
        minio_client.create_bucket(&bucket).build().send().await?;
        info!("Bucket {} created.", bucket);
    }

    let object_name = format!(
        "map_watch_{}.json",
        chrono::Utc::now().format("%Y%m%dT%H%M%SZ")
    );

    let content = ObjectContent::from(json_payload.as_bytes().to_vec());
    minio_client
        .put_object_content(bucket, object_name, content)
        .build()
        .send()
        .await
        .map(|_| ())
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
    let consumer = redpanda_utils::setup_redpanda_consumer(brokers.clone(), group_id.clone());
    let producer = redpanda_utils::setup_redpanda_producer(brokers.clone());

    let base_url = minio_endpoint.parse::<BaseUrl>().unwrap();
    let static_provider = StaticProvider::new(&minio_access_key, &minio_secret_key, None);
    let minio_client =
        std::sync::Arc::new(MinioClient::new(base_url, Some(static_provider), None, None).unwrap());

    redpanda_utils::subscribe_to_topic(&consumer, input_topic.clone(), {
        move |msg| {
            let minio_client = minio_client.clone();
            let minio_bucket = minio_bucket.clone();
            let output_topic = output_topic.clone();
            let producer = producer.clone();
            async move {
                match process_message(msg).await {
                    Ok((map_json, wind_json)) => {
                        info!(
                            "Uploading GeoJSON payload to MinIO bucket: {}",
                            minio_bucket
                        );
                        match upload_to_minio(minio_client, minio_bucket, map_json.clone())
                            .await
                        {
                            Ok(_) => info!("Successfully uploaded GeoJSON to MinIO"),
                            Err(e) => error!("Failed to upload to MinIO: {}", e),
                        };

                        let vars: std::collections::HashMap<String, String> =
                            std::collections::HashMap::new();

                        if let Ok(topic_name) = strfmt(&output_topic, &vars) {
                            let produce_future = producer.send(
                                FutureRecord::<(), [u8]>::to(topic_name.as_str())
                                    .payload(map_json.as_bytes()),
                                Duration::from_secs(5),
                            );
                            match produce_future.await {
                                Ok(delivery) => info!("Published map message: {:?}", delivery),
                                Err((e, _)) => error!("Failed to publish map message: {:?}", e),
                            }
                        } else {
                            error!("Failed to format output topic string: {}", output_topic);
                        }

                        if let Some(wind_json) = wind_json {
                            let wind_topic = "maps.wind";
                            let produce_future = producer.send(
                                FutureRecord::<(), [u8]>::to(wind_topic)
                                    .payload(wind_json.as_bytes()),
                                Duration::from_secs(5),
                            );
                            match produce_future.await {
                                Ok(delivery) => info!("Published wind message: {:?}", delivery),
                                Err((e, _)) => error!("Failed to publish wind message: {:?}", e),
                            }
                        }
                    }
                    Err(e) => error!("Failed to process message logic: {}", e),
                }
            }
        }
    }).await;

    info!("Stream processing terminated");
}
