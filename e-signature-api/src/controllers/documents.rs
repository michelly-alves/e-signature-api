use crate::services::documents::models::{CreateDocument, Document, UpdateDocument};
use crate::services::documents::services as document_service;
use crate::AppState;
use actix_multipart::Multipart;
use actix_web::{delete, get, post, put, web, Error, HttpResponse, Responder};
use futures_util::TryStreamExt;
use sanitize_filename::sanitize;
use sha2::{Digest, Sha256};
use std::fs::{create_dir_all, File};
use std::io::Write;
use uuid::Uuid;

#[post("/documents")]
async fn create_document_handler(
    state: web::Data<AppState>,
    mut payload: Multipart,
) -> Result<HttpResponse, Error> {
    let mut create_request = CreateDocument::default();
    let mut file_data: Vec<u8> = Vec::new();
    let mut original_filename = String::new();

    while let Some(mut field) = payload.try_next().await? {
        let filename = field.content_disposition()
            .and_then(|d| d.get_filename())
            .map(|f| sanitize(f).to_string());

        let field_name = field.content_disposition()
            .and_then(|d| d.get_name())
            .map(|n| n.to_string());

        if let Some(fname) = filename {
            original_filename = fname;
            while let Some(chunk) = field.try_next().await? {
                file_data.extend_from_slice(&chunk);
            }
        } else if let Some(name) = field_name {
            let mut field_data_bytes = Vec::new();
            while let Some(chunk) = field.try_next().await? {
                field_data_bytes.extend_from_slice(&chunk);
            }
            let value = String::from_utf8(field_data_bytes).unwrap_or_default();

            match name.as_str() {
                "company_id" => create_request.company_id = value.parse().unwrap_or(0),
                "status_id" => create_request.status_id = value.parse().unwrap_or(1),
                "signer_full_name" => create_request.signer_full_name = Some(value),
                "signer_phone_number" => create_request.signer_phone_number = Some(value),
                "signer_email" => create_request.signer_email = Some(value),
                "signer_national_id" => create_request.signer_national_id = Some(value),
                "photo_id_url" => create_request.photo_id_url = Some(value),
                _ => (),
            }
        }
    }

    if file_data.is_empty() {
        return Ok(HttpResponse::BadRequest().json("Arquivo PDF é obrigatório."));
    }

    let upload_dir = "./uploads";
    create_dir_all(upload_dir)?;

    let unique_filename = format!("{}-{}", Uuid::new_v4(), original_filename);
    let file_path = format!("{}/{}", upload_dir, unique_filename);

    let mut f = File::create(&file_path)?;
    f.write_all(&file_data)?;

    let mut hasher = Sha256::new();
    hasher.update(&file_data);
    let hash_result = hasher.finalize();
    let hash_hex = format!("{:x}", hash_result);

    create_request.file_name = Some(original_filename);
    create_request.file_path = Some(file_path);
    create_request.hash_sha256 = Some(hash_hex);

    match document_service::create_document_and_signer(&state.postgres_client, create_request).await {
        Ok(document) => Ok(HttpResponse::Created().json(document)),
        Err(e) => Ok(HttpResponse::InternalServerError().json(format!("Falha ao criar documento: {}", e))),
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
