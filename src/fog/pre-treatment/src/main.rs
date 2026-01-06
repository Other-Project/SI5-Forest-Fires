use clap::{Arg, Command};
use futures::stream::FuturesUnordered;
use futures::StreamExt;
use log::info;



mod messages;
mod parser;
mod process;
mod raw_messages;
mod station_config;
mod logger;
mod minio_worker;


use crate::logger::setup_logger;
use crate::minio_worker::run_async_processor;

#[tokio::main]
async fn main() {
    let matches = Command::new("Pretreatment")
        .version(option_env!("CARGO_PKG_VERSION").unwrap_or(""))
        .about("Pretreatment service for processing station data")
        .arg(
            Arg::new("brokers")
                .short('b')
                .long("brokers")
                .env("KAFKA_BROKERS")
                .help("Broker list in kafka format")
                .default_value("localhost:19092"),
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
                .default_value("^sensors\\.meteo\\..*\\.raw$"),
        )
        .arg(
            Arg::new("output-topic")
                .long("output-topic")
                .env("KAFKA_OUTPUT_TOPIC")
                .help("Output topic")
                .default_value("sensors.meteo.{device_id}.data"),
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
