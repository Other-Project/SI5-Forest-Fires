use actix_web::{App, HttpResponse, HttpServer, Responder, get};
use geojson::{FeatureCollection, GeoJson};

#[get("/watch")]
async fn watch() -> impl Responder {

    let feature_collection: FeatureCollection = FeatureCollection { bbox: None, features: vec![], foreign_members: None };

    let serialized: String = GeoJson::from(feature_collection).to_string();
    HttpResponse::Ok()
        .content_type("application/geo+json")
        .body(serialized)
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    HttpServer::new(|| App::new().service(watch))
        .bind(("127.0.0.1", 8081))?
        .run()
        .await
}
