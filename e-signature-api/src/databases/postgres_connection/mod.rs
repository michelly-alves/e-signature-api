use sqlx::{postgres::PgPoolOptions, Pool, Postgres};

pub async fn start_connection() -> Pool<Postgres> {
    let postgres_environment = std::env::var("DATABASE_URL").expect("DATABASE_URL must be set");

    let pool = PgPoolOptions::new()
        .max_connections(15)
        .connect(&postgres_environment)
        .await
        .expect("Failed to connect to Postgres.");

    sqlx::migrate!("./migrations")
        .run(&pool)
        .await
        .expect("Failed to run migrations.");

    pool
}