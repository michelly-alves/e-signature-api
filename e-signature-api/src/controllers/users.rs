use crate::services::users as user_service;
use actix_web::{HttpResponse, Responder, delete, get, post, put, web};
// Adicione as duas linhas abaixo para importar os modelos
use crate::AppState;
use crate::services::users::models::{CreateUser, UpdateUser};

/// POST /users - Cria um novo usuário
#[post("/users")]
async fn create_user_handler(
    state: web::Data<AppState>,
    body: web::Json<CreateUser>,
) -> impl Responder {
    match user_service::create_user(&state.postgres_client, body.into_inner()).await {
        Ok(user) => HttpResponse::Created().json(user),
        Err(e) => {
            // Verifica se o erro é de violação de unicidade (email já existe)
            if let Some(db_err) = e.as_database_error() {
                if db_err.is_unique_violation() {
                    return HttpResponse::Conflict().json("Error: Email already exists.");
                }
            }
            HttpResponse::InternalServerError().json(format!("Failed to create user: {}", e))
        }
    }
}

/// GET /users - Lista todos os usuários
#[get("/users")]
async fn get_users_handler(state: web::Data<AppState>) -> impl Responder {
    match user_service::get_all_users(&state.postgres_client).await {
        Ok(users) => HttpResponse::Ok().json(users),
        Err(_) => HttpResponse::InternalServerError().json("Failed to retrieve users."),
    }
}

/// GET /users/{id} - Busca um usuário por ID
#[get("/users/{id}")]
async fn get_user_by_id_handler(
    state: web::Data<AppState>,
    path: web::Path<i64>,
) -> impl Responder {
    let user_id = path.into_inner();
    match user_service::get_user_by_id(&state.postgres_client, user_id).await {
        Ok(Some(user)) => HttpResponse::Ok().json(user),
        Ok(None) => HttpResponse::NotFound().json(format!("User with ID {} not found.", user_id)),
        Err(_) => HttpResponse::InternalServerError().json("Failed to retrieve user."),
    }
}

/// PUT /users/{id} - Atualiza um usuário
#[put("/users/{id}")]
async fn update_user_handler(
    state: web::Data<AppState>,
    path: web::Path<i64>,
    body: web::Json<UpdateUser>,
) -> impl Responder {
    let user_id = path.into_inner();
    match user_service::update_user(&state.postgres_client, user_id, body.into_inner()).await {
        Ok(Some(user)) => HttpResponse::Ok().json(user),
        Ok(None) => HttpResponse::NotFound().json(format!("User with ID {} not found.", user_id)),
        Err(_) => HttpResponse::InternalServerError().json("Failed to update user."),
    }
}

/// DELETE /users/{id} - Deleta um usuário
#[delete("/users/{id}")]
async fn delete_user_handler(state: web::Data<AppState>, path: web::Path<i64>) -> impl Responder {
    let user_id = path.into_inner();
    match user_service::delete_user(&state.postgres_client, user_id).await {
        Ok(0) => HttpResponse::NotFound().json(format!("User with ID {} not found.", user_id)),
        Ok(_) => HttpResponse::Ok().json(format!("User with ID {} successfully deleted.", user_id)),
        Err(_) => HttpResponse::InternalServerError().json("Failed to delete user."),
    }
}

// Função para configurar os serviços (rotas) de usuários
pub fn config(cfg: &mut web::ServiceConfig) {
    cfg.service(
        web::scope("/api") // Prefixo /api para todas as rotas de usuário
            .service(create_user_handler)
            .service(get_users_handler)
            .service(get_user_by_id_handler)
            .service(update_user_handler)
            .service(delete_user_handler),
    );
}
