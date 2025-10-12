use actix_web::{App, HttpResponse, HttpServer, Responder, get, web};
use dotenv::dotenv;
use sqlx::postgres::PgPoolOptions;

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

    let database_url = std::env::var("DATABASE_URL").expect("DATABASE_URL must be set");

    let pool = PgPoolOptions::new()
        .max_connections(5)
        .connect(&database_url)
        .await
        .expect("Failed to create pool.");

    println!("Servidor iniciado em http://127.0.0.1:8080");

    HttpServer::new(move || {
        App::new()
            .app_data(web::Data::new(AppState {
                postgres_client: pool.clone(),
            }))
            .service(root)
            .service(controllers::otp::generate_otp)
            .service(controllers::otp::verify_otp)
            .configure(controllers::users::config)
    })
    .bind(("127.0.0.1", 8080))?
    .run()
    .await
}
