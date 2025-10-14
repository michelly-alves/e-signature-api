use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, sqlx::FromRow)]
pub struct TelegramLink {
    pub id: i32,
    pub email: String,
    pub token: String,
    pub chat_id: Option<i64>,
    pub confirmed: bool,
    pub created_at: Option<DateTime<Utc>>,
    pub confirmed_at: Option<DateTime<Utc>>,
}

#[derive(Deserialize)]
pub struct ConfirmTelegramRequest {
    pub token: String,
    pub chat_id: i64,
}
