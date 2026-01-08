use actix_web::{App, HttpResponse, HttpServer, Responder, get};

mod redpanda_watcher;

#[get("/data")]
async fn data() -> impl Responder {
    let serialized: String = redpanda_watcher::get_geojson().to_string();
    HttpResponse::Ok()
        .content_type("application/geo+json")
        .body(serialized)
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    HttpServer::new(|| App::new().service(data))
        .bind(("127.0.0.1", 8081))?
        .run()
        .await
}
