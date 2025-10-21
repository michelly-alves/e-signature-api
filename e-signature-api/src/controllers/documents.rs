use crate::services::documents::models::{CreateDocument, UpdateDocument, CreateSigner};
use crate::services::documents::services as document_service;
use crate::AppState;
use actix_web::{delete, get, post, put, web, HttpResponse, Responder};

#[post("/documents")]
async fn create_document_handler(
    state: web::Data<AppState>,
    body: web::Json<CreateDocument>,
) -> impl Responder {
    match document_service::create_document_and_signer(&state.postgres_client, body.into_inner()).await {
        Ok(document) => HttpResponse::Created().json(document),
        Err(e) => HttpResponse::InternalServerError()
            .json(serde_json::json!(format!("Failed to create document: {}", e))),
    }
}

#[get("/documents")]
async fn get_documents_handler(state: web::Data<AppState>) -> impl Responder {
    match document_service::get_all_documents(&state.postgres_client).await {
        Ok(documents) => HttpResponse::Ok().json(documents),
        Err(_) => {
            HttpResponse::InternalServerError().json(serde_json::json!("Failed to retrieve documents."))
        }
    }
}

#[get("/documents/{id}")]
async fn get_document_by_id_handler(
    state: web::Data<AppState>,
    path: web::Path<i64>,
) -> impl Responder {
    let doc_id = path.into_inner();
    match document_service::get_document_by_id(&state.postgres_client, doc_id).await {
        Ok(Some(document)) => HttpResponse::Ok().json(document),
        Ok(None) => HttpResponse::NotFound().json(serde_json::json!(format!(
            "Document with ID {} not found.",
            doc_id
        ))),
        Err(_) => {
            HttpResponse::InternalServerError().json(serde_json::json!("Failed to retrieve document."))
        }
    }
}

#[put("/documents/{id}")]
async fn update_document_handler(
    state: web::Data<AppState>,
    path: web::Path<i64>,
    body: web::Json<UpdateDocument>,
) -> impl Responder {
    let doc_id = path.into_inner();
    match document_service::update_document(&state.postgres_client, doc_id, body.into_inner()).await {
        Ok(Some(document)) => HttpResponse::Ok().json(document),
        Ok(None) => HttpResponse::NotFound().json(serde_json::json!(format!(
            "Document with ID {} not found.",
            doc_id
        ))),
        Err(_) => {
            HttpResponse::InternalServerError().json(serde_json::json!("Failed to update document."))
        }
    }
}

#[delete("/documents/{id}")]
async fn delete_document_handler(state: web::Data<AppState>, path: web::Path<i64>) -> impl Responder {
    let doc_id = path.into_inner();
    match document_service::delete_document(&state.postgres_client, doc_id).await {
        Ok(0) => HttpResponse::NotFound().json(serde_json::json!(format!(
            "Document with ID {} not found.",
            doc_id
        ))),
        Ok(_) => HttpResponse::Ok().json(serde_json::json!(format!(
            "Document with ID {} successfully deleted.",
            doc_id
        ))),
        Err(_) => {
            HttpResponse::InternalServerError().json(serde_json::json!("Failed to delete document."))
        }
    }
}

/*#[post("/signers")]
async fn add_signer_handler(
    state: web::Data<AppState>,
    body: web::Json<CreateSigner>,
) -> impl Responder {
    match document_service::add_signer_to_document(&state.postgres_client, body.into_inner()).await {
        Ok(signer) => HttpResponse::Created().json(signer),
        Err(e) => HttpResponse::InternalServerError()
            .json(serde_json::json!(format!("Failed to add signer: {}", e))),
    }
}*/

/*#[get("/documents/{id}/signers")]
async fn get_signers_handler(
    state: web::Data<AppState>,
    path: web::Path<i64>,
) -> impl Responder {
    let doc_id = path.into_inner();
    match document_service::get_signers_for_document(&state.postgres_client, doc_id).await {
        Ok(signers) => HttpResponse::Ok().json(signers),
        Err(_) => {
            HttpResponse::InternalServerError().json(serde_json::json!("Failed to retrieve signers."))
        }
    }
}*/

pub fn config(cfg: &mut web::ServiceConfig) {
    println!("Módulo documents carregado!");
    cfg
            .service(create_document_handler)
            .service(get_documents_handler)
            .service(get_document_by_id_handler)
            .service(update_document_handler)
            .service(delete_document_handler)
            //.service(add_signer_handler)
           //.service(get_signers_handler)
    ;
}
