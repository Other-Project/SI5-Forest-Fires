use actix_web::{App, Error, HttpRequest, HttpResponse, HttpServer, Responder, get, rt, web};
use actix_ws::AggregatedMessage;
use clap::{Arg, Command};
use futures::StreamExt;
use log::info;
use rust_shared::logger;

mod redpanda_watcher;

#[get("/watch")]
async fn watch() -> impl Responder {
    info!("Received request for GeoJSON data");
    let serialized: String = redpanda_watcher::get_geojson().await.to_string();
    info!("Returning GeoJSON data: {}", serialized);
    HttpResponse::Ok()
        .content_type("application/geo+json")
        .body(serialized)
}

#[get("/ws")]
async fn echo(req: HttpRequest, stream: web::Payload) -> Result<HttpResponse, Error> {
    let (res, mut session, ws_stream) = actix_ws::handle(&req, stream)?;
    let mut geojson_notifications = redpanda_watcher::subscribe_geojson_notifications();

    // Task to send GeoJSON data on notification
    rt::spawn({
        let mut session = session.clone();
        async move {
            loop {
                match geojson_notifications.recv().await {
                    Ok(_) => {
                        let geojson = redpanda_watcher::get_geojson().await.to_string();
                        match session.text(geojson).await {
                            Ok(()) => log::info!("Sent updated GeoJSON data over websocket"),
                            Err(e) => log::error!("Failed to send GeoJSON data: {}", e),
                        };
                    }
                    Err(tokio::sync::broadcast::error::RecvError::Closed) => break,
                    Err(tokio::sync::broadcast::error::RecvError::Lagged(_)) => continue,
                }
            }
        }
    });

    // Task to handle incoming websocket messages
    rt::spawn(async move {
        let mut ws_stream = ws_stream
            .aggregate_continuations()
            .max_continuation_size(2_usize.pow(20));
        while let Some(msg) = ws_stream.next().await {
            match msg {
                Ok(AggregatedMessage::Ping(msg)) => session.pong(&msg).await.unwrap(),
                _ => {}
            }
        }
    });

    Ok(res)
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

    tokio::spawn(redpanda_watcher::init(
        brokers.clone(),
        group_id.clone(),
        input_topic.clone(),
    ));

    HttpServer::new(|| App::new().service(watch).service(echo))
        .bind(("0.0.0.0", 8889))?
        .run()
        .await
}
