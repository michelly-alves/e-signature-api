use crate::services::telegram::models::TelegramLink;
use actix_web::middleware::Logger;
use actix_web::{get, web, App, HttpResponse, HttpServer, Responder};
use dotenv::dotenv;
use sqlx::postgres::PgPoolOptions;
use std::collections::HashMap;
use std::sync::Mutex;

mod bot;
mod controllers;
mod models;
mod services;

#[derive(Clone)]
pub struct AppState {
    postgres_client: sqlx::Pool<sqlx::Postgres>,
}

#[get("/")]
async fn root() -> impl Responder {
    HttpResponse::Ok().body("API está no ar! Use os endpoints em /api/users.")
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    dotenv().ok();

    tokio::spawn(async {
        bot::run_bot().await;
    });
    let telegram_data = web::Data::new(Mutex::new(HashMap::<String, TelegramLink>::new()));

    let database_url = std::env::var("DATABASE_URL").expect("DATABASE_URL must be set");

    let pool = PgPoolOptions::new()
        .max_connections(5)
        .connect(&database_url)
        .await
        .expect("Failed to create pool.");

    println!("Servidor iniciado em http://127.0.0.1:8080");

    HttpServer::new(move || {
        App::new()
            .wrap(Logger::default())
            .app_data(web::Data::new(AppState {
                postgres_client: pool.clone(),
            }))
            .service(root)
            .service(controllers::otp::generate_otp)
            .service(controllers::otp::verify_otp)
            .configure(controllers::users::config)
            .configure(controllers::telegram::config)
            .configure(controllers::documents::config)
            .app_data(telegram_data.clone())
    })
    .bind(("127.0.0.1", 8080))?
    .run()
    .await
}
