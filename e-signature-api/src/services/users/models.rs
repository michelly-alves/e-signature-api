use serde::{Deserialize, Serialize};
use sqlx::FromRow;
// Corrigido para usar DateTime<Utc> em toda a struct
use chrono::{DateTime, Utc};

#[derive(Debug, FromRow, Serialize, Deserialize)]
pub struct User {
    pub user_id: i64,
    pub email: String,
    #[serde(skip_serializing)]
    pub password_hash: String,
    pub role: i32,
    // Corrigido para DateTime<Utc>
    pub created_at: DateTime<Utc>,
    // Corrigido para DateTime<Utc>
    pub updated_at: Option<DateTime<Utc>>,
    #[serde(skip)]
    // Corrigido para DateTime<Utc>
    pub deleted_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Deserialize)]
pub struct CreateUser {
    pub email: String,
    pub password: String,
    pub role: Option<i32>,
}

#[derive(Debug, Deserialize)]
pub struct UpdateUser {
    pub email: Option<String>,
    pub role: Option<i32>,
}
