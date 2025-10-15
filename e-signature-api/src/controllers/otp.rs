use actix_web::{post, web, HttpResponse, Responder};
use chrono::{Duration, Utc};
use rand::Rng;
use serde::{Deserialize, Serialize};

use crate::AppState;

#[derive(Deserialize)]
pub struct OtpRequest {
    pub email: String,
}

#[derive(Serialize)]
pub struct OtpResponse {
    pub otp: String,
    pub expires_at: String,
}

#[post("/otp/generate")]
pub async fn generate_otp(data: web::Data<AppState>, req: web::Json<OtpRequest>) -> impl Responder {
    let otp_code: String = rand::thread_rng().gen_range(100_000..999_999).to_string();

    let expires_at = Utc::now() + Duration::minutes(5);

    let query = r#"
        INSERT INTO otp_codes (email, code, expires_at, used)
        VALUES ($1, $2, $3, FALSE)
        ON CONFLICT (email) DO UPDATE
        SET code = EXCLUDED.code, expires_at = EXCLUDED.expires_at, used = FALSE
    "#;

    if let Err(err) = sqlx::query(query)
        .bind(&req.email)
        .bind(&otp_code)
        .bind(expires_at)
        .execute(&data.postgres_client)
        .await
    {
        return HttpResponse::InternalServerError().body(format!("Erro: {}", err));
    }

    HttpResponse::Ok().json(OtpResponse {
        otp: otp_code,
        expires_at: expires_at.to_rfc3339(),
    })
}

#[derive(Deserialize)]
pub struct VerifyRequest {
    pub email: String,
    pub code: String,
}

#[post("/otp/verify")]
pub async fn verify_otp(
    data: web::Data<AppState>,
    req: web::Json<VerifyRequest>,
) -> impl Responder {
    let record = sqlx::query!(
        r#"
        SELECT code, expires_at, used FROM otp_codes
        WHERE email = $1
        "#,
        req.email
    )
    .fetch_optional(&data.postgres_client)
    .await;

    if let Ok(Some(rec)) = record {
        if rec.used {
            return HttpResponse::BadRequest().body("Código já utilizado");
        }

        if Utc::now() > rec.expires_at {
            return HttpResponse::BadRequest().body("Código expirado");
        }
        if rec.code == req.code {
            let _ = sqlx::query!(
                "UPDATE otp_codes SET used = TRUE WHERE email = $1",
                req.email
            )
            .execute(&data.postgres_client)
            .await;
            return HttpResponse::Ok().body("Validação bem-sucedida!");
        }
    }

    HttpResponse::BadRequest().body("Código inválido")
}
