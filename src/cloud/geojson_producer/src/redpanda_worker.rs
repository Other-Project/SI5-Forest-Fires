use std::time::Duration;

use futures::StreamExt;
use log::{error, info, warn};

use minio::s3::MinioClient;
use minio::s3::builders::ObjectContent;
use minio::s3::creds::StaticProvider;
use minio::s3::http::BaseUrl;
use minio::s3::types::S3Api;
use rdkafka::Message;
use rdkafka::config::ClientConfig;
use rdkafka::consumer::Consumer;
use rdkafka::consumer::stream_consumer::StreamConsumer;
use rdkafka::error::RDKafkaErrorCode;
use rdkafka::message::OwnedMessage;
use rdkafka::producer::{FutureProducer, FutureRecord};

use strfmt::strfmt;

use crate::map_message;
use crate::process::gen_geojson;

// Process weather data message
async fn process_message(msg: OwnedMessage) -> Result<String, String> {
    info!("Processing message at offset {}", msg.offset());

    // Extract payload as byte array
    let payload = msg
        .payload()
        .ok_or_else(|| "No payload in message".to_string())?;

    // Process
    let map_message: map_message::MapMessage = serde_json::from_slice(payload)
        .map_err(|e| format!("Failed to deserialize MapMessage: {}", e))?;

    // Serialize to JSON for publishing
    let json = gen_geojson(map_message);
    Ok(json)
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
    if !exists  {
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
    // Create the `StreamConsumer`, to receive the messages from the topic in form of a `Stream`.
    let consumer: StreamConsumer = ClientConfig::new()
        .set("group.id", &group_id)
        .set("bootstrap.servers", &brokers)
        .set("enable.partition.eof", "false")
        .set("session.timeout.ms", "6000")
        .set("enable.auto.commit", "false")
        .set("topic.metadata.refresh.interval.ms", "10000")
        .create()
        .expect("Consumer creation failed");

    consumer
        .subscribe(&[&input_topic])
        .expect("Can't subscribe to specified topic");

    // Create the `FutureProducer` to produce asynchronously.
    let producer: FutureProducer = ClientConfig::new()
        .set("bootstrap.servers", &brokers)
        .set("message.timeout.ms", "5000")
        .create()
        .expect("Producer creation error");

    let base_url = minio_endpoint.parse::<BaseUrl>().unwrap();
    let static_provider = StaticProvider::new(&minio_access_key, &minio_secret_key, None);
    let minio_client =
        std::sync::Arc::new(MinioClient::new(base_url, Some(static_provider), None, None).unwrap());

    info!(
        "Starting event loop, waiting for topics matching: {}",
        input_topic
    );

    let mut stream = consumer.stream();
    while let Some(message_result) = stream.next().await {
        match message_result {
            Ok(borrowed_message) => {
                let producer = producer.clone();
                let output_topic = output_topic.clone();
                let minio_client = minio_client.clone();
                let minio_bucket = minio_bucket.clone();

                info!("Message received at offset {}", borrowed_message.offset());
                let owned_message = borrowed_message.detach();

                tokio::spawn(async move {
                    let process_handle =
                        tokio::spawn(async move { process_message(owned_message).await });

                    match process_handle.await {
                        Ok(Ok(json_payload)) => {
                            info!(
                                "Uploading GeoJSON payload to MinIO bucket: {}",
                                minio_bucket
                            );
                            match upload_to_minio(minio_client, minio_bucket, json_payload.clone())
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
                                        .payload(json_payload.as_bytes()),
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
                        Ok(Err(e)) => error!("Failed to process message logic: {}", e),
                        Err(e) => error!("Task join error: {}", e),
                    }
                });
            }
            Err(e) => match e.rdkafka_error_code() {
                Some(RDKafkaErrorCode::UnknownTopicOrPartition) => {
                    warn!("Topic matching regex not found yet. Waiting...");
                }
                _ => {
                    error!("Error receiving message: {:?}", e);
                }
            },
        }
    }

    info!("Stream processing terminated");
}
