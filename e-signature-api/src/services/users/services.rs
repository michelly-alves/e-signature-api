use crate::services::documents::models::Signer;
use crate::services::users::models::{CreateUser, Role, UpdateUser, User};
use base64::{engine::general_purpose, Engine as _};
use bcrypt::{hash, DEFAULT_COST};
use chrono::Utc;
use image::load_from_memory;
use sqlx::PgPool;
use std::convert::TryInto;
use std::fs;

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
        let phone_number = new_user.phone_number.ok_or_else(|| {
            sqlx::Error::Protocol("Missing 'phone_number' for signer user".into())
        })?;
        let national_id = new_user.national_id.ok_or_else(|| {
            sqlx::Error::Protocol("Missing 'national_id' (CPF) for signer user".into())
        })?;

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

pub async fn get_signer_by_id(
    pool: &PgPool,
    signer_id: i64,
) -> Result<Option<Signer>, sqlx::Error> {
    let signer = sqlx::query_as::<_, Signer>(
        r#"
    SELECT photo_id_url, user_id, signer_id, full_name, national_id, phone_number,
           public_key, contact_email, created_at, updated_at, deleted_at
    FROM signer
    WHERE signer_id = $1 AND deleted_at IS NULL
    "#,
    )
    .bind(signer_id)
    .fetch_optional(pool)
    .await?;

    Ok(signer)
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

pub async fn verify_signer_face(
    pool: &PgPool,
    national_id: &str,
    live_image_base64: &str,
) -> Result<Option<bool>, sqlx::Error> {
    let signer_record = sqlx::query!(
        r#"
        SELECT photo_id_url
        FROM signer
        WHERE national_id = $1 AND deleted_at IS NULL
        "#,
        national_id
    )
    .fetch_optional(pool)
    .await?;

    let record = match signer_record {
        Some(r) => r,
        None => return Ok(None),
    };

    let reference_photo_path = match record.photo_id_url {
        Some(path) => path,
        None => return Err(sqlx::Error::Protocol("Signatário encontrado, mas sem foto de referência cadastrada.".into())),
    };

    let reference_image_bytes = fs::read(&reference_photo_path)
        .map_err(|e| sqlx::Error::Protocol(format!("Falha ao ler a foto de referência: {}", e).into()))?;

    let live_image_bytes = general_purpose::STANDARD.decode(live_image_base64)
        .map_err(|e| sqlx::Error::Protocol(format!("Imagem base64 inválida: {}", e).into()))?;

        //TO DO/; Integrar com serviço real de reconhecimento facial aqui       
    
    let match_result = !reference_image_bytes.is_empty() && !live_image_bytes.is_empty();
    println!("SIMULAÇÃO: Comparando faces. Resultado: {}", match_result);

    Ok(Some(match_result))
}
