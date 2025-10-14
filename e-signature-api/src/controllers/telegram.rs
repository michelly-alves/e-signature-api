use crate::services::telegram::models::{ConfirmTelegramRequest, TelegramLink};
use crate::services::users::models::User;
use crate::AppState;
use actix_web::{post, web, HttpResponse, Responder};
use chrono::Utc;
use serde_json::json;
use sqlx::PgPool;

use crate::services::auth; 

#[post("/telegram/confirm")]
pub async fn confirm_link(
    data: web::Data<AppState>,
    payload: web::Json<ConfirmTelegramRequest>,
) -> impl Responder {
    let pool: &PgPool = &data.postgres_client;

    let link = sqlx::query_as::<_, TelegramLink>(
        "SELECT * FROM telegram_links WHERE token = $1 AND confirmed = FALSE",
    )
    .bind(&payload.token)
    .fetch_optional(pool)
    .await;

    match link {
        Ok(Some(link)) => {

            let _ = sqlx::query(
                "UPDATE telegram_links 
                 SET chat_id = $1, confirmed = TRUE, confirmed_at = $2 
                 WHERE token = $3",
            )
            .bind(payload.chat_id)
            .bind(Utc::now())
            .bind(&payload.token)
            .execute(pool)
            .await;
            let user = sqlx::query_as::<_, User>(
                "SELECT * FROM user_account WHERE email = $1 AND deleted_at IS NULL",
            )
            .bind(&link.email)
            .fetch_one(pool)
            .await;

            match user {
                Ok(user) => {
                    let jwt = auth::create_jwt(&user.user_id.to_string())
                        .unwrap_or_else(|_| "".to_string());

                    HttpResponse::Ok().json(json!({
                        "status": "success",
                        "message": "Telegram vinculado com sucesso!",
                        "jwt": jwt
                    }))
                }
                Err(_) => HttpResponse::InternalServerError().json(json!({
                    "status": "error",
                    "message": "Não foi possível encontrar usuário para gerar JWT."
                })),
            }
        }
        Ok(None) => HttpResponse::BadRequest().json(json!({
            "status": "error",
            "message": "Token inválido ou já confirmado."
        })),
        Err(e) => HttpResponse::InternalServerError().json(json!({
            "status": "error",
            "message": format!("Erro ao consultar banco: {}", e)
        })),
    }
}

#[post("/telegram/create_link")]
pub async fn create_link(
    data: web::Data<AppState>,
    payload: web::Json<serde_json::Value>,
) -> impl Responder {
    let pool: &PgPool = &data.postgres_client;

    let email = match payload.get("email").and_then(|v| v.as_str()) {
        Some(email) => email,
        None => {
            return HttpResponse::BadRequest().json(json!({
                "status": "error",
                "message": "E-mail é obrigatório."
            }));
        }
    };

    let token = uuid::Uuid::new_v4().to_string();

    let result = sqlx::query("INSERT INTO telegram_links (email, token) VALUES ($1, $2)")
        .bind(email)
        .bind(&token)
        .execute(pool)
        .await;

    match result {
        Ok(_) => {
            let link = format!(
                "https://web.telegram.org/k/#@e_signature_bot?start={}",
                token
            );
            HttpResponse::Ok().json(json!({
                "status": "success",
                "link": link,
                "token": token
            }))
        }
        Err(e) => HttpResponse::InternalServerError().json(json!({
            "status": "error",
            "message": format!("Erro ao salvar token: {}", e)
        })),
    }
}

pub fn config(cfg: &mut web::ServiceConfig) {
    println!("Módulo Telegram carregado!");
    cfg.service(create_link).service(confirm_link);
}
