use std::time::Duration;

use clap::{Arg, Command};
use futures::stream::FuturesUnordered;
use futures::{StreamExt, TryStreamExt};
use log::info;

use minio::s3::creds::StaticProvider;
use minio::s3::http::BaseUrl;
use minio::s3::types::S3Api;
use minio::s3::MinioClient;
use rdkafka::config::ClientConfig;
use rdkafka::consumer::stream_consumer::StreamConsumer;
use rdkafka::consumer::Consumer;
use rdkafka::message::OwnedMessage;
use rdkafka::producer::{FutureProducer, FutureRecord};
use rdkafka::Message;

use env_logger::Builder;
use log::LevelFilter;
use strfmt::strfmt;
use std::io::Write;

mod messages;
mod parser;
mod process;
mod raw_messages;
mod station_config;

use parser::parse_weather_data;
use process::process_weather_data;

use crate::station_config::StationConfig;

pub fn setup_logger(log_thread: bool, rust_log: Option<&String>) {
    let mut builder = Builder::new();

    // Default to info if not specified
    let filter_level = rust_log
        .map(|s| s.as_str())
        .unwrap_or("info")
        .parse::<LevelFilter>()
        .unwrap_or(LevelFilter::Info);

    builder.filter_level(filter_level);

    // Simplified format to avoid version compatibility issues with env_logger::fmt::Color
    builder.format(move |buf, record| {
        let thread_name = if log_thread {
            format!(" [{:?}]", std::thread::current().id())
        } else {
            "".to_string()
        };

        writeln!(
            buf,
            "{} {}{}: {}",
            buf.timestamp(),
            record.level(),
            thread_name,
            record.args()
        )
    });

    builder.init();
}

// Process weather data message
async fn process_message(msg: OwnedMessage, minio_client: &MinioClient, minio_bucket: &str) -> Result<(u16, String), String> {
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
        .get_object(minio_bucket, format!("{}.json", raw_weather_data.metadata.device_id))
        .build().send().await
        .map_err(|e| format!("Failed to fetch station ({}) config from MinIO: {}", raw_weather_data.metadata.device_id, e))?
        .content()
        .map_err(|e| format!("Failed to read station ({}) config content: {}", raw_weather_data.metadata.device_id, e))?
        .to_segmented_bytes().await
        .map_err(|e| format!("Failed to convert station ({}) config to bytes: {}", raw_weather_data.metadata.device_id, e))?
        .to_bytes();
    let station_config: StationConfig = serde_json::from_slice(&station_config_bytes)
        .map_err(|e| format!("Failed to parse station ({}) config JSON: {}", raw_weather_data.metadata.device_id, e))?;

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

async fn run_async_processor(
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
    let static_provider = StaticProvider::new(
        &minio_access_key,
        &minio_secret_key,
        None,
    );
    let minio_client =
        std::sync::Arc::new(MinioClient::new(base_url, Some(static_provider), None, None).unwrap());

    // Create the outer pipeline on the message stream.
    let stream_processor = consumer.stream().try_for_each(|borrowed_message| {
        let producer = producer.clone();
        let output_topic = output_topic.to_string();
        let minio_client = minio_client.clone();
        let minio_bucket = minio_bucket.to_string();
        async move {
            info!("Message received at offset {}", borrowed_message.offset());
            let owned_message = borrowed_message.detach();
            tokio::spawn(async move {
                // Process the message in an async task (await the async function)
                let minio_client = minio_client.clone();
                let process_handle =
                    tokio::spawn(
                        async move { process_message(owned_message, &*minio_client, &minio_bucket).await },
                    );

                match process_handle.await {
                    Ok(Ok(json_payload)) => {
                        // Successfully processed
                        let mut vars = std::collections::HashMap::new();
                        vars.insert("device_id".to_string(), json_payload.0.to_string());
                        let topic_name = strfmt(&output_topic, &vars).unwrap();
                        let produce_future = producer.send(
                            FutureRecord::<(), [u8]>::to(topic_name.as_str())
                                .payload(json_payload.1.as_bytes()),
                            Duration::from_secs(5),
                        );
                        match produce_future.await {
                            Ok(delivery) => info!("Published message: {:?}", delivery),
                            Err((e, _)) => eprintln!("Failed to publish message: {:?}", e),
                        }
                    }
                    Ok(Err(e)) => eprintln!("Failed to process message: {}", e),
                    Err(e) => eprintln!("Task join error: {}", e),
                }
            });
            Ok(())
        }
    });

    info!("Starting event loop");
    stream_processor.await.expect("stream processing failed");
    info!("Stream processing terminated");
}

#[tokio::main]
async fn main() {
    let matches = Command::new("Async example")
        .version(option_env!("CARGO_PKG_VERSION").unwrap_or(""))
        .about("Asynchronous computation example")
        .arg(
            Arg::new("brokers")
                .short('b')
                .long("brokers")
                .env("KAFKA_BROKERS")
                .help("Broker list in kafka format")
                .default_value("localhost:9092"),
        )
        .arg(
            Arg::new("group-id")
                .short('g')
                .long("group-id")
                .env("KAFKA_GROUP_ID")
                .help("Consumer group id")
                .default_value("example_consumer_group_id"),
        )
        .arg(
            Arg::new("log-conf")
                .long("log-conf")
                .env("RUST_LOG")
                .help("Configure the logging format (example: 'rdkafka=trace')"),
        )
        .arg(
            Arg::new("input-topic")
                .long("input-topic")
                .env("KAFKA_INPUT_TOPIC")
                .help("Input topic")
                .required(true),
        )
        .arg(
            Arg::new("output-topic")
                .long("output-topic")
                .env("KAFKA_OUTPUT_TOPIC")
                .help("Output topic")
                .required(true),
        )
        .arg(
            Arg::new("num-workers")
                .long("num-workers")
                .env("NUM_WORKERS")
                .help("Number of workers")
                .value_parser(clap::value_parser!(usize))
                .default_value("1"),
        )
        .arg(
            Arg::new("minio-endpoint")
                .long("minio-endpoint")
                .env("MINIO_ENDPOINT")
                .help("MinIO endpoint URL")
                .default_value("http://localhost:9000"),
        )
        .arg(
            Arg::new("minio-access-key")
                .long("minio-access-key")
                .env("MINIO_ACCESS_KEY")
                .help("MinIO access key")
                .default_value("minioadmin"),
        )
        .arg(
            Arg::new("minio-secret-key")
                .long("minio-secret-key")
                .env("MINIO_SECRET_KEY")
                .help("MinIO secret key")
                .default_value("minioadmin123"),
        )
        .arg(
            Arg::new("minio-bucket")
                .long("minio-bucket")
                .env("MINIO_BUCKET")
                .help("MinIO bucket name")
                .default_value("stations"),
        )
        .get_matches();

    setup_logger(true, matches.get_one("log-conf"));

    let brokers = matches.get_one::<String>("brokers").unwrap();
    let group_id = matches.get_one::<String>("group-id").unwrap();
    let input_topic = matches.get_one::<String>("input-topic").unwrap();
    let output_topic = matches.get_one::<String>("output-topic").unwrap();
    let num_workers = *matches.get_one::<usize>("num-workers").unwrap();
    let minio_endpoint = matches.get_one::<String>("minio-endpoint").unwrap();
    let minio_access_key = matches.get_one::<String>("minio-access-key").unwrap();
    let minio_secret_key = matches.get_one::<String>("minio-secret-key").unwrap();
    let minio_bucket = matches.get_one::<String>("minio-bucket").unwrap();

    info!("Starting {} worker(s)", num_workers);

    (0..num_workers)
        .map(|_| {
            tokio::spawn(run_async_processor(
                brokers.to_owned(),
                group_id.to_owned(),
                input_topic.to_owned(),
                output_topic.to_owned(),
                minio_endpoint.to_owned(),
                minio_access_key.to_owned(),
                minio_secret_key.to_owned(),
                minio_bucket.to_owned(),
            ))
        })
        .collect::<FuturesUnordered<_>>()
        .for_each(|_| async {})
        .await
}
