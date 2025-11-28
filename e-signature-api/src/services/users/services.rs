use crate::services::documents::models::Signer;
use crate::services::users::models::{CreateUser, Role, UpdateUser, User};
use base64::{engine::general_purpose, Engine as _};
use bcrypt::{hash, DEFAULT_COST};
use chrono::Utc;
use serde_json::json;
use sqlx::PgPool;
use std::fs;
use std::io::Write;
use std::process::Command;
use std::process::Stdio;

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
    // 1. Busca o signatário
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
        None => {
            return Err(sqlx::Error::Protocol(
                "Signatário sem foto de referência.".into(),
            ))
        }
    };

    // 2. Lê a imagem de referência e converte para base64
    let reference_image_bytes = fs::read(&reference_photo_path)
        .map_err(|e| sqlx::Error::Protocol(format!("Erro ao ler a foto de referência: {}", e)))?;
    let reference_image_base64 = general_purpose::STANDARD.encode(&reference_image_bytes);

    // 3. Chama script Python
    let mut child = Command::new("python")
        .arg("./scripts/compare_faces.py")
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .spawn()
        .map_err(|e| sqlx::Error::Protocol(format!("Erro ao iniciar Python: {}", e)))?;

    // 4. Envia JSON para o Python via stdin
    let input_json = json!({
        "ref_image_base64": reference_image_base64,
        "live_image_base64": live_image_base64
    });

    let stdin = child.stdin.as_mut().ok_or_else(|| {
        sqlx::Error::Protocol("Não foi possível abrir stdin do processo Python.".into())
    })?;
    stdin
        .write_all(input_json.to_string().as_bytes())
        .map_err(|e| sqlx::Error::Protocol(format!("Erro ao escrever stdin: {}", e)))?;

    // 5. Recebe resultado do Python
    let output = child
        .wait_with_output()
        .map_err(|e| sqlx::Error::Protocol(format!("Erro ao executar Python: {}", e)))?;

    if !output.status.success() {
        return Err(sqlx::Error::Protocol(format!(
            "Python retornou erro: {}",
            String::from_utf8_lossy(&output.stderr)
        )));
    }

    let output_json: serde_json::Value = serde_json::from_slice(&output.stdout)
        .map_err(|e| sqlx::Error::Protocol(format!("Erro ao parsear JSON do Python: {}", e)))?;

    let match_result = output_json
        .get("match")
        .and_then(|v| v.as_bool())
        .unwrap_or(false);

    println!("Base64 reference length: {}", reference_image_base64.len());
    println!("Base64 live image length: {}", live_image_base64.len());
    println!("Resultado da comparação: {}", match_result);

    Ok(Some(match_result))
}
