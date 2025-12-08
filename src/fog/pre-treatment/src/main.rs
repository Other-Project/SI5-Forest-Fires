use std::time::Duration;

use clap::{Arg, Command};
use futures::stream::FuturesUnordered;
use futures::{StreamExt, TryStreamExt};
use log::info;

use rdkafka::config::ClientConfig;
use rdkafka::consumer::stream_consumer::StreamConsumer;
use rdkafka::consumer::Consumer;
use rdkafka::message::OwnedMessage;
use rdkafka::producer::{FutureProducer, FutureRecord};
use rdkafka::Message;

use env_logger::Builder;
use log::LevelFilter;
use std::io::Write;

mod messages;
mod parser;
mod process;
mod raw_messages;

use parser::parse_weather_data;
use process::process_weather_data;

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
fn process_message(msg: OwnedMessage, minio_endpoint: String) -> Result<String, String> {
    info!("Processing message at offset {}", msg.offset());

    // Extract payload as byte array
    let payload = msg
        .payload()
        .ok_or_else(|| "No payload in message".to_string())?;

    // Parse payload as RawWeatherData
    let raw_weather_data =
        parse_weather_data(payload).map_err(|e| format!("Failed to parse weather data: {}", e))?;

    // Process and convert to WeatherData
    let weather_data = process_weather_data(raw_weather_data, minio_endpoint)
        .map_err(|e| format!("Failed to process weather data: {}", e))?;

    // Serialize to JSON for publishing
    let json =
        serde_json::to_string(&weather_data).map_err(|e| format!("Failed to serialize: {}", e))?;

    info!(
        "Successfully processed message from device {}",
        weather_data.metadata.device_id
    );
    Ok(json)
}

async fn run_async_processor(
    brokers: String,
    group_id: String,
    input_topic: String,
    output_topic: String,
    minio_endpoint: String,
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

    // Create the outer pipeline on the message stream.
    let stream_processor = consumer.stream().try_for_each(|borrowed_message| {
        let producer = producer.clone();
        let output_topic = output_topic.to_string();
        let minio_endpoint = minio_endpoint.clone();
        async move {
            info!("Message received at offset {}", borrowed_message.offset());
            let owned_message = borrowed_message.detach();
            tokio::spawn(async move {
                // Process the message in a separate thread pool
                let process_result = tokio::task::spawn_blocking(move || {
                    process_message(owned_message, minio_endpoint)
                })
                .await;

                match process_result {
                    Ok(Ok(json_payload)) => {
                        // Successfully processed - produce to output topic
                        let produce_future = producer.send(
                            FutureRecord::<(), [u8]>::to(&output_topic)
                                .payload(json_payload.as_bytes()),
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
        .get_matches();

    setup_logger(true, matches.get_one("log-conf"));

    let brokers = matches.get_one::<String>("brokers").unwrap();
    let group_id = matches.get_one::<String>("group-id").unwrap();
    let input_topic = matches.get_one::<String>("input-topic").unwrap();
    let output_topic = matches.get_one::<String>("output-topic").unwrap();
    let num_workers = *matches.get_one::<usize>("num-workers").unwrap();
    let minio_endpoint = matches.get_one::<String>("minio-endpoint").unwrap();

    (0..num_workers)
        .map(|_| {
            tokio::spawn(run_async_processor(
                brokers.to_owned(),
                group_id.to_owned(),
                input_topic.to_owned(),
                output_topic.to_owned(),
                minio_endpoint.to_owned(),
            ))
        })
        .collect::<FuturesUnordered<_>>()
        .for_each(|_| async {})
        .await
}
