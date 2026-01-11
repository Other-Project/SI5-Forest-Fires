use actix_web::{App, Error, HttpRequest, HttpResponse, HttpServer, Responder, get, rt, web};
use actix_ws::AggregatedMessage;
use clap::{Arg, Command};
use futures::StreamExt;
use geojson::{FeatureCollection, GeoJson};
use log::info;
use once_cell::sync::Lazy;
use rust_shared::{logger};

use crate::{messages::WindMessage, redpanda_listener::Listener};

mod messages;
mod redpanda_listener;

static GEOJSON_LISTENER: Lazy<Listener<GeoJson>> = Lazy::new(|| {
    Listener::new(GeoJson::from(FeatureCollection {
        bbox: None,
        features: vec![],
        foreign_members: None,
    }))
});

static WIND_LISTENER: Lazy<Listener<WindMessage>> = Lazy::new(|| {
    Listener::new(WindMessage {
        speed: 0.0,
        direction: 0.0,
    })
});


#[get("/watch")]
async fn watch() -> impl Responder {
    info!("Received request for GeoJSON data");
    let serialized: String = GEOJSON_LISTENER.get().await.to_string();
    info!("Returning GeoJSON data: {}", serialized);
    HttpResponse::Ok()
        .content_type("application/geo+json")
        .body(serialized)
}

#[get("/ws")]
async fn echo(req: HttpRequest, stream: web::Payload) -> Result<HttpResponse, Error> {
    let (res, mut session, ws_stream) = actix_ws::handle(&req, stream)?;

    // Task to send GeoJSON data on notification
    let mut geojson_notifications = GEOJSON_LISTENER.subscribe_notifications();
    rt::spawn({
        let mut session = session.clone();
        async move {
            loop {
                match geojson_notifications.recv().await {
                    Ok(_) => {
                        let geojson = GEOJSON_LISTENER.get().await;
                        let msg = messages::ApiMessage {
                            message_type: "areas".to_string(),
                            payload: Some(geojson),
                        };
                        let json = serde_json::to_string(&msg);
                        if json.is_err() {
                            log::error!("Failed to serialize GeoJSON data");
                            continue;
                        }
                        match session.text(json.unwrap()).await {
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

    // Task to send Wind data on notification
    let mut wind_notifications = WIND_LISTENER.subscribe_notifications();
    rt::spawn({
        let mut session = session.clone();
        async move {
            loop {
                match wind_notifications.recv().await {
                    Ok(_) => {
                        let wind = WIND_LISTENER.get().await;
                        let msg = messages::ApiMessage {
                            message_type: "wind".to_string(),
                            payload: Some(wind),
                        };
                        let json = serde_json::to_string(&msg);
                        if json.is_err() {
                            log::error!("Failed to serialize Wind data");
                            continue;
                        }
                        match session.text(json.unwrap()).await {
                            Ok(()) => log::info!("Sent updated Wind data over websocket"),
                            Err(e) => log::error!("Failed to send Wind data: {}", e),
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

    tokio::spawn(GEOJSON_LISTENER.init(
        brokers.clone(),
        group_id.clone(),
        input_topic.clone(),
    ));
    tokio::spawn(WIND_LISTENER.init(
        brokers.clone(),
        group_id.clone(),
        "maps.wind".to_string(),
    ));

    HttpServer::new(|| App::new().service(watch).service(echo))
        .bind(("0.0.0.0", 8889))?
        .run()
        .await
}
