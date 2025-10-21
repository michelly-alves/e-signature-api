use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;

#[derive(Debug, FromRow, Serialize, Deserialize)]
pub struct Document {
    pub document_id: i64,
    pub company_id: i64,
    pub file_name: String,
    pub file_path: String,
    pub hash_sha256: String,
    pub status_id: i32,
    pub created_at: DateTime<Utc>,
    pub updated_at: Option<DateTime<Utc>>,
    pub deleted_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Deserialize, Default)]
pub struct CreateDocument {
    pub company_id: i64,
    pub file_name: Option<String>,
    pub file_path: Option<String>,
    pub hash_sha256: Option<String>,
    pub status_id: i32,
    pub signer_full_name: Option<String>,
    pub signer_phone_number: Option<String>,
    pub signer_email: Option<String>,
    pub signer_national_id: Option<String>,
    pub photo_id_url: Option<String>,
}

#[derive(Deserialize, Debug)]
pub struct UpdateDocument {
    pub file_name: Option<String>,
    pub status_id: Option<i32>,
}

#[derive(Serialize, FromRow, Debug)]
pub struct Signer {
pub signer_id: i64,
    pub full_name: String,
    pub national_id: String,
    pub phone_number: String,
    pub contact_email: String,
    pub public_key: String,    
    pub created_at: DateTime<Utc>,
    pub updated_at: Option<DateTime<Utc>>,  
    pub deleted_at: Option<DateTime<Utc>>, 
    pub user_id: i64,
    pub photo_id_url: Option<String>, 
}


#[derive(Deserialize, Debug)]
pub struct CreateSigner {
    pub full_name: String,
    pub doc_id: i64,
    pub email: String,
    pub phone_number: String,
    pub national_id: String,
    pub photo_id_url: String,
}
