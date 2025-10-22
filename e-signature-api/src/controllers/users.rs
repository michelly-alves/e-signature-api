use crate::services::auth;
use crate::services::users as user_service;
use crate::services::users::models::{CreateUser, UpdateUser, User};
use crate::AppState;
use actix_web::{delete, get, post, put, web, HttpRequest, HttpResponse, Responder};
use serde::Deserialize;
use serde_json;
//use crate::services::users::services::{FaceEnrollmentRequest, FaceVerificationRequest};

#[derive(Deserialize)]
pub struct LoginPayload {
    email: String,
    password: String,
}

#[derive(Deserialize)]
pub struct FaceVerificationPayload {
    live_image_base64: String,
}

#[post("/auth/login")]
pub async fn login_handler(
    state: web::Data<AppState>,
    body: web::Json<LoginPayload>,
) -> impl Responder {
    let user = match sqlx::query_as::<_, User>("SELECT user_id, email, password_hash, role, created_at, updated_at, deleted_at FROM user_account WHERE email = $1 AND deleted_at IS NULL")
        .bind(&body.email)
        .fetch_one(&state.postgres_client)
        .await
    {
        Ok(user) => user,
        Err(_) => return HttpResponse::Unauthorized().json(serde_json::json!({"error": "Invalid credentials"})),
    };

    let valid_password = bcrypt::verify(&body.password, &user.password_hash).unwrap_or(false);

    if !valid_password {
        return HttpResponse::Unauthorized()
            .json(serde_json::json!({"error": "Invalid credentials"}));
    }

    match auth::create_jwt(&user.user_id.to_string()) {
        Ok(token) => HttpResponse::Ok().json(serde_json::json!({ "token": token })),
        Err(_) => HttpResponse::InternalServerError()
            .json(serde_json::json!({"error": "Failed to create token"})),
    }
}

#[post("/users")]
async fn create_user_handler(
    state: web::Data<AppState>,
    body: web::Json<CreateUser>,
) -> impl Responder {
    match user_service::create_user(&state.postgres_client, body.into_inner()).await {
        Ok(user) => HttpResponse::Created().json(user),
        Err(e) => {
            if let Some(db_err) = e.as_database_error() {
                if db_err.is_unique_violation() {
                    return HttpResponse::Conflict().json(serde_json::json!(
                        "Erro: E-mail já está em uso por um usuário ativo."
                    ));
                }
            }
            HttpResponse::InternalServerError()
                .json(serde_json::json!(format!("Failed to create user: {}", e)))
        }
    }
}

#[get("/users")]
async fn get_users_handler(state: web::Data<AppState>) -> impl Responder {
    match user_service::get_all_users(&state.postgres_client).await {
        Ok(users) => HttpResponse::Ok().json(users),
        Err(_) => {
            HttpResponse::InternalServerError().json(serde_json::json!("Failed to retrieve users."))
        }
    }
}

#[get("/users/{id}")]
async fn get_user_by_id_handler(
    state: web::Data<AppState>,
    path: web::Path<i64>,
) -> impl Responder {
    let user_id = path.into_inner();
    match user_service::get_user_by_id(&state.postgres_client, user_id).await {
        Ok(Some(user)) => HttpResponse::Ok().json(user),
        Ok(None) => HttpResponse::NotFound().json(serde_json::json!(format!(
            "User with ID {} not found.",
            user_id
        ))),
        Err(_) => {
            HttpResponse::InternalServerError().json(serde_json::json!("Failed to retrieve user."))
        }
    }
}

#[get("/signer/{id}")]
async fn get_signer_by_id_handler(
    state: web::Data<AppState>,
    path: web::Path<i64>,
) -> impl Responder {
    let user_id = path.into_inner();
    match user_service::get_signer_by_id(&state.postgres_client, user_id).await {
        Ok(Some(user)) => HttpResponse::Ok().json(user),
        Ok(None) => HttpResponse::NotFound().json(serde_json::json!(format!(
            "User with ID {} not found.",
            user_id
        ))),
        Err(_) => {
            HttpResponse::InternalServerError().json(serde_json::json!("Failed to retrieve user."))
        }
    }
}

#[post("/signers/{national_id}/facial-verify")]
pub async fn verify_signer_face_handler(
    state: web::Data<AppState>,
    path: web::Path<String>,
    body: web::Json<FaceVerificationPayload>,
) -> impl Responder {
    let national_id = path.into_inner();
    match user_service::verify_signer_face(&state.postgres_client, &national_id, &body.live_image_base64).await {
        Ok(Some(match_result)) => {
             HttpResponse::Ok().json(serde_json::json!({ "match": match_result }))
        },
        Ok(None) => {
            HttpResponse::NotFound().json(serde_json::json!({ "error": "Signer not found" }))
        },
        Err(e) => {
            HttpResponse::InternalServerError().json(serde_json::json!({ "error": format!("Verification failed: {}", e) }))
        }
    }
}

#[put("/users/{id}")]
async fn update_user_handler(
    state: web::Data<AppState>,
    path: web::Path<i64>,
    body: web::Json<UpdateUser>,
) -> impl Responder {
    let user_id = path.into_inner();
    match user_service::update_user(&state.postgres_client, user_id, body.into_inner()).await {
        Ok(Some(user)) => HttpResponse::Ok().json(user),
        Ok(None) => HttpResponse::NotFound().json(serde_json::json!(format!(
            "User with ID {} not found.",
            user_id
        ))),
        Err(_) => {
            HttpResponse::InternalServerError().json(serde_json::json!("Failed to update user."))
        }
    }
}

#[delete("/users/{id}")]
async fn delete_user_handler(state: web::Data<AppState>, path: web::Path<i64>) -> impl Responder {
    let user_id = path.into_inner();
    match user_service::delete_user(&state.postgres_client, user_id).await {
        Ok(0) => HttpResponse::NotFound().json(serde_json::json!(format!(
            "User with ID {} not found.",
            user_id
        ))),
        Ok(_) => HttpResponse::Ok().json(serde_json::json!(format!(
            "User with ID {} successfully deleted.",
            user_id
        ))),
        Err(_) => {
            HttpResponse::InternalServerError().json(serde_json::json!("Failed to delete user."))
        }
    }
}

#[get("/users/me")]
async fn get_current_user_handler(req: HttpRequest, state: web::Data<AppState>) -> impl Responder {
    let auth_header = match req.headers().get("Authorization") {
        Some(header) => header,
        None => {
            return HttpResponse::Unauthorized().json(serde_json::json!({
                "message": "Token de autorização não fornecido.",
                "received_token": null
            }));
        }
    };

    let auth_str = match auth_header.to_str() {
        Ok(s) => s,
        Err(_) => {
            return HttpResponse::BadRequest().json(serde_json::json!({
                "message": "Valor de cabeçalho inválido.",
                "received_header": format!("{:?}", auth_header)
            }));
        }
    };

    if !auth_str.starts_with("Bearer ") {
        return HttpResponse::BadRequest().json(serde_json::json!({
            "message": "Formato de token inválido. Use: Bearer <token>",
            "received_header": auth_str
        }));
    }

    let token = &auth_str["Bearer ".len()..];

    match auth::validate_jwt(token) {
        Ok(claims) => {
            let user_id: i64 = claims.sub.parse().unwrap_or(0);
            match user_service::get_user_by_id(&state.postgres_client, user_id).await {
                Ok(Some(user)) => HttpResponse::Ok().json(user),
                Ok(None) => {
                    HttpResponse::NotFound().json(serde_json::json!("Usuário não encontrado."))
                }
                Err(_) => HttpResponse::InternalServerError()
                    .json(serde_json::json!("Falha ao buscar usuário.")),
            }
        }
        Err(_) => HttpResponse::Unauthorized().json(serde_json::json!({
            "message": "Token inválido ou expirado.",
            "received_token": token
        })),
    }
}

/* */

pub fn config(cfg: &mut web::ServiceConfig) {
    println!("Módulo users carregado!");
    cfg.service(
        web::scope("/api")
            .service(login_handler)
            .service(get_current_user_handler)
            .service(create_user_handler)
            .service(get_users_handler)
            .service(get_user_by_id_handler)
            .service(update_user_handler)
            .service(delete_user_handler)
            .service(create_user_handler)
            .service(delete_user_handler)
            .service(get_signer_by_id_handler)
            .service(verify_signer_face_handler),
            //,(enroll_face_handler)
            //.service(verify_face_handler),
    );
}
