use crate::services::users::models::{CreateUser, Role, UpdateUser, User};
use bcrypt::{hash, DEFAULT_COST};
use chrono::Utc;
use sqlx::PgPool;
use image::load_from_memory;
use face_detector::{FaceDetector, LandmarkDetector, FaceEmbedder};
use std::convert::TryInto;
use base64::{Engine as _, engine::general_purpose};

#[derive(serde::Deserialize, Debug)]
pub struct FaceEnrollmentRequest {
    pub image_base64: String,
}

#[derive(serde::Deserialize, Debug)]
pub struct FaceVerificationRequest {
    pub image_base64: String,
}

pub async fn create_user(pool: &PgPool, new_user: CreateUser) -> Result<User, sqlx::Error> {
    let mut tx = pool.begin().await?;

    let password_hash = hash(&new_user.password, DEFAULT_COST)
        .map_err(|_| sqlx::Error::Protocol("Failed to hash password".into()))?;

    let user = sqlx::query_as!(
        User,
        r#"
        INSERT INTO user_account (email, password_hash, role)
        VALUES ($1, $2, $3)
        RETURNING user_id, email, password_hash, role as "role: _", created_at as "created_at!", updated_at, deleted_at
        "#,
        new_user.email,
        password_hash,
        new_user.role as i32
    )
    .fetch_one(&mut *tx)
    .await?;

    if new_user.role == Role::Company {
        let legal_name = new_user
            .legal_name
            .ok_or_else(|| sqlx::Error::Protocol("Missing 'legal_name' for company user".into()))?;
        let tax_id = new_user.tax_id.ok_or_else(|| {
            sqlx::Error::Protocol("Missing 'tax_id' (CNPJ) for company user".into())
        })?;

        sqlx::query!(
            r#"
            INSERT INTO company (legal_name, tax_id, contact_email, user_id)
            VALUES ($1, $2, $3, $4)
            "#,
            legal_name,
            tax_id,
            &user.email,
            user.user_id
        )
        .execute(&mut *tx)
        .await?;
    }

    if new_user.role == Role::Signer {
        let full_name = new_user
            .full_name
            .ok_or_else(|| sqlx::Error::Protocol("Missing 'full_name' for Signer user".into()))?;
        let phone_number = new_user.phone_number
            .ok_or_else(|| sqlx::Error::Protocol("Missing 'phone_number' for signer user".into()))?;
        let national_id = new_user.national_id
            .ok_or_else(|| sqlx::Error::Protocol("Missing 'national_id' (CPF) for signer user".into()))?;

        sqlx::query!(
            r#"
            INSERT INTO signer (full_name, phone_number, contact_email, user_id, national_id)
            VALUES ($1, $2, $3, $4, $5)
            "#,
            full_name,
            phone_number,
            &user.email,
            user.user_id,
            national_id
        )
        .execute(&mut *tx)
        .await?;
    }

    tx.commit().await?;

    Ok(user)
}

pub async fn get_all_users(pool: &PgPool) -> Result<Vec<User>, sqlx::Error> {
    let users = sqlx::query_as!(
        User,
        r#"
        SELECT user_id, email, password_hash, role as "role: _", created_at as "created_at!", updated_at, deleted_at
        FROM user_account
        WHERE deleted_at IS NULL
        ORDER BY user_id
        "#
    )
    .fetch_all(pool)
    .await?;
    Ok(users)
}

pub async fn get_user_by_id(pool: &PgPool, user_id: i64) -> Result<Option<User>, sqlx::Error> {
    let user = sqlx::query_as!(
        User,
        r#"
        SELECT user_id, email, password_hash, role as "role: _", created_at as "created_at!", updated_at, deleted_at
        FROM user_account
        WHERE user_id = $1 AND deleted_at IS NULL
        "#,
        user_id
    )
    .fetch_optional(pool)
    .await?;
    Ok(user)
}

pub async fn update_user(
    pool: &PgPool,
    user_id: i64,
    data: UpdateUser,
) -> Result<Option<User>, sqlx::Error> {
    let current_user = match get_user_by_id(pool, user_id).await? {
        Some(user) => user,
        None => return Ok(None),
    };

    let email = data.email.unwrap_or(current_user.email);
    let role = data.role.unwrap_or(current_user.role);
    let now = Utc::now();

    let updated_user = sqlx::query_as!(
        User,
        r#"
        UPDATE user_account
        SET email = $1, role = $2, updated_at = $3
        WHERE user_id = $4
        RETURNING user_id, email, password_hash, role as "role: _", created_at as "created_at!", updated_at, deleted_at
        "#,
        email,
        role as i32,
        now,
        user_id
    )
    .fetch_one(pool)
    .await?;

    Ok(Some(updated_user))
}

pub async fn delete_user(pool: &PgPool, user_id: i64) -> Result<u64, sqlx::Error> {
    let now = Utc::now();
    let result = sqlx::query!(
        "UPDATE user_account SET deleted_at = $1 WHERE user_id = $2 AND deleted_at IS NULL",
        now,
        user_id
    )
    .execute(pool)
    .await?;

    Ok(result.rows_affected())
}

pub async fn enroll_user_face(pool: &PgPool, user_id: i64, request: FaceEnrollmentRequest) -> Result<(), String> {
    // 1. Decodifica a imagem Base64 recebida
    let image_bytes = general_purpose::STANDARD.decode(&request.image_base64)
        .map_err(|e| format!("Erro ao decodificar a imagem: {}", e))?;

    // 2. Processa a imagem para extrair o embedding
    let embedding = tokio::task::spawn_blocking(move || {
        extract_embedding_from_image(image_bytes)
    }).await.map_err(|e| format!("Erro no processamento da imagem: {}", e))?
     .ok_or_else(|| "Nenhum rosto encontrado na imagem de cadastro.".to_string())?;

    // 3. Salva o embedding no banco de dados
    sqlx::query!(
        "UPDATE user_account SET face_embedding = $1 WHERE user_id = $2",
        &embedding,
        user_id
    )
    .execute(pool)
    .await
    .map_err(|e| format!("Erro ao salvar embedding no banco: {}", e))?;

    Ok(())
}

/// Verifica o rosto de um usuário contra o embedding armazenado
pub async fn verify_user_face(pool: &PgPool, user_id: i64, request: FaceVerificationRequest) -> Result<bool, String> {
    // 1. Busca o embedding de referência do banco
    let record = sqlx::query!("SELECT face_embedding FROM user_account WHERE user_id = $1", user_id)
        .fetch_optional(pool)
        .await
        .map_err(|e| format!("Erro ao buscar usuário: {}", e))?
        .ok_or_else(|| "Usuário não encontrado.".to_string())?;

    let reference_embedding_bytes = record.face_embedding
        .ok_or_else(|| "Nenhum rosto cadastrado para este usuário.".to_string())?;
    
    // 2. Decodifica e processa a nova imagem
    let image_bytes = general_purpose::STANDARD.decode(&request.image_base64)
        .map_err(|e| format!("Erro ao decodificar a imagem: {}", e))?;

    let new_embedding = tokio::task::spawn_blocking(move || {
        extract_embedding_from_image(image_bytes)
    }).await.map_err(|e| format!("Erro no processamento da imagem: {}", e))?
     .ok_or_else(|| "Nenhum rosto encontrado na imagem de verificação.".to_string())?;

    // 3. Compara os embeddings
    let distance = face_detector::distance(&reference_embedding_bytes, &new_embedding);

    // O valor de threshold 0.6 é um padrão comum. Valores menores indicam maior similaridade.
    // Você pode ajustar este valor conforme necessário.
    const SIMILARITY_THRESHOLD: f32 = 0.6; 

    Ok(distance < SIMILARITY_THRESHOLD)
}


/// Função auxiliar para extrair o embedding de uma imagem
/// Esta função é computacionalmente intensiva e deve ser rodada em um blocking thread.
fn extract_embedding_from_image(image_bytes: Vec<u8>) -> Option<Vec<u8>> {
    // Carrega os modelos. Em uma aplicação real, você faria isso apenas uma vez no início.
    let face_detector = FaceDetector::new().ok()?;
    let landmark_detector = LandmarkDetector::new().ok()?;
    let face_embedder = FaceEmbedder::new().ok()?;

    let image = load_from_memory(&image_bytes).ok()?.to_rgb8();
    let (width, height) = image.dimensions();
    
    let faces = face_detector.detect(&image.into_raw(), width as usize, height as usize, 1);

    // Usa apenas o primeiro rosto encontrado na imagem
    if let Some(face) = faces.into_iter().next() {
        let landmarks = landmark_detector.detect(&face);
        let embedding: [f32; 128] = face_embedder.embed(&landmarks);
        
        // Converte o array de f32 para Vec<u8> para salvar no banco
        let embedding_bytes: Vec<u8> = embedding
            .iter()
            .flat_map(|&f| f.to_ne_bytes().to_vec())
            .collect();
        return Some(embedding_bytes);
    }
    
    None
}