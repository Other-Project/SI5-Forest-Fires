use actix_web::{App, HttpResponse, HttpServer, Responder, get};
use clap::{Arg, Command};
use log::info;
use rust_shared::logger;

mod redpanda_watcher;

#[get("/watch")]
async fn watch() -> impl Responder {
    let serialized: String = redpanda_watcher::get_geojson().to_string();
    HttpResponse::Ok()
        .content_type("application/geo+json")
        .body(serialized)
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    let matches = Command::new("API Server")
        .version(option_env!("CARGO_PKG_VERSION").unwrap_or(""))
        .about("Cloud API server")
        .arg(
            Arg::new("log-conf")
                .long("log-conf")
                .env("RUST_LOG")
                .help("Configure the logging level"),
        )
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
                .default_value("geojson_producer"),
        )
        .arg(
            Arg::new("input-topic")
                .long("input-topic")
                .env("KAFKA_INPUT_TOPIC")
                .help("Input topic")
                .default_value("maps.watch.geojson"),
        )
        .get_matches();

    logger::setup_logger(true, matches.get_one("log-conf"));

    let brokers = matches.get_one::<String>("brokers").unwrap();
    let group_id = matches.get_one::<String>("group-id").unwrap();
    let input_topic = matches.get_one::<String>("input-topic").unwrap();

    info!("Starting API server...");

    redpanda_watcher::init(brokers.clone(), group_id.clone(), input_topic.clone()).await;

    HttpServer::new(|| App::new().service(watch))
        .bind(("127.0.0.1", 8081))?
        .run()
        .await
}
