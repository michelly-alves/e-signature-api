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
    
    let mut document_file_data: Vec<u8> = Vec::new();
    let mut document_filename = String::new();
    let mut photo_id_file_data: Vec<u8> = Vec::new();
    let mut photo_id_filename = String::new();

    while let Some(mut field) = payload.try_next().await? {
        let field_name_opt = field.content_disposition().and_then(|d| d.get_name()).map(|s| s.to_string());
        let filename_opt = field.content_disposition().and_then(|d| d.get_filename()).map(|s| sanitize(s).to_string());

        if let Some(fname) = filename_opt {
             let mut file_bytes = Vec::new();
            while let Some(chunk) = field.try_next().await? {
                file_bytes.extend_from_slice(&chunk);
            }
            
            if let Some(name) = field_name_opt {
                 match name.as_str() {
                    "document_file" => {
                        document_file_data = file_bytes;
                        document_filename = fname;
                    },
                    "signer_photo_id_file" => {
                        photo_id_file_data = file_bytes;
                        photo_id_filename = fname;
                    }
                    _ => {}
                }
            }
        } else if let Some(name) = field_name_opt {
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
                _ => (),
            }
        }
    }

    if document_file_data.is_empty() {
        return Ok(HttpResponse::BadRequest().json("Arquivo PDF do documento é obrigatório."));
    }
     if photo_id_file_data.is_empty() {
        return Ok(HttpResponse::BadRequest().json("Arquivo da foto de identificação é obrigatório."));
    }

    let upload_dir = "./uploads";
    create_dir_all(upload_dir)?;

    let doc_unique_filename = format!("{}-{}", Uuid::new_v4(), document_filename);
    let doc_file_path = format!("{}/{}", upload_dir, doc_unique_filename);
    let mut doc_file = File::create(&doc_file_path)?;
    doc_file.write_all(&document_file_data)?;

    let photo_unique_filename = format!("{}-{}", Uuid::new_v4(), photo_id_filename);
    let photo_file_path = format!("{}/{}", upload_dir, photo_unique_filename);
    let mut photo_file = File::create(&photo_file_path)?;
    photo_file.write_all(&photo_id_file_data)?;

    let mut hasher = Sha256::new();
    hasher.update(&document_file_data);
    let hash_hex = format!("{:x}", hasher.finalize());

    create_request.file_name = Some(document_filename);
    create_request.file_path = Some(doc_file_path);
    create_request.hash_sha256 = Some(hash_hex);
    create_request.photo_id_url = Some(photo_file_path);

    match document_service::create_document_and_signer(&state.postgres_client, create_request).await {
        Ok(document) => Ok(HttpResponse::Created().json(document)),
        Err(e) => Ok(HttpResponse::InternalServerError().json(format!("Falha ao criar documento: {}", e))),
    }
}


#[get("/documents")]
async fn get_documents_handler(state: web::Data<AppState>) -> impl Responder {
    match document_service::get_all_documents(&state.postgres_client).await {
        Ok(documents) => HttpResponse::Ok().json(documents),
        Err(_) => HttpResponse::InternalServerError()
            .json(serde_json::json!("Failed to retrieve documents.")),
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
        Err(_) => HttpResponse::InternalServerError()
            .json(serde_json::json!("Failed to retrieve document.")),
    }
}

#[put("/documents/{id}")]
async fn update_document_handler(
    state: web::Data<AppState>,
    path: web::Path<i64>,
    body: web::Json<UpdateDocument>,
) -> impl Responder {
    let doc_id = path.into_inner();
    match document_service::update_document(&state.postgres_client, doc_id, body.into_inner()).await
    {
        Ok(Some(document)) => HttpResponse::Ok().json(document),
        Ok(None) => HttpResponse::NotFound().json(serde_json::json!(format!(
            "Document with ID {} not found.",
            doc_id
        ))),
        Err(_) => HttpResponse::InternalServerError()
            .json(serde_json::json!("Failed to update document.")),
    }
}

#[delete("/documents/{id}")]
async fn delete_document_handler(
    state: web::Data<AppState>,
    path: web::Path<i64>,
) -> impl Responder {
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
        Err(_) => HttpResponse::InternalServerError()
            .json(serde_json::json!("Failed to delete document.")),
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
