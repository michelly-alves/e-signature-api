use crate::services::users::models::{CreateUser, UpdateUser, User};
use bcrypt::{DEFAULT_COST, hash};
use chrono::{DateTime, Utc};
use sqlx::PgPool;

// --- Funções CRUD ---

/// Cria um novo usuário no banco de dados
pub async fn create_user(pool: &PgPool, new_user: CreateUser) -> Result<User, sqlx::Error> {
    let password_hash = hash(new_user.password, DEFAULT_COST).expect("Failed to hash password");

    let user = sqlx::query_as!(
        User,
        r#"
        INSERT INTO user_account (email, password_hash, role) 
        VALUES ($1, $2, $3) 
        RETURNING user_id, email, password_hash, role, created_at as "created_at!", updated_at, deleted_at
        "#,
        new_user.email,
        password_hash,
        new_user.role.unwrap_or(0) // Default role = 0
    )
    .fetch_one(pool)
    .await?;

    Ok(user)
}

/// Busca todos os usuários (que não foram deletados)
pub async fn get_all_users(pool: &PgPool) -> Result<Vec<User>, sqlx::Error> {
    let users = sqlx::query_as!(
        User,
        r#"
        SELECT user_id, email, password_hash, role, created_at as "created_at!", updated_at, deleted_at 
        FROM user_account 
        WHERE deleted_at IS NULL 
        ORDER BY user_id
        "#
    )
    .fetch_all(pool)
    .await?;
    Ok(users)
}

/// Busca um usuário pelo ID
pub async fn get_user_by_id(pool: &PgPool, user_id: i64) -> Result<Option<User>, sqlx::Error> {
    let user = sqlx::query_as!(
        User,
        r#"
        SELECT user_id, email, password_hash, role, created_at as "created_at!", updated_at, deleted_at 
        FROM user_account 
        WHERE user_id = $1 AND deleted_at IS NULL
        "#,
        user_id
    )
    .fetch_optional(pool)
    .await?;
    Ok(user)
}

/// Atualiza os dados de um usuário
pub async fn update_user(pool: &PgPool, user_id: i64, data: UpdateUser) -> Result<Option<User>, sqlx::Error> {
    // Primeiro, busca o usuário para garantir que ele existe e para usar dados atuais como fallback
    let current_user = match get_user_by_id(pool, user_id).await? {
        Some(user) => user,
        None => return Ok(None), // Se não encontrar, retorna None
    };

    // Define os valores a serem atualizados, usando os dados atuais se nenhum novo for fornecido
    let email = data.email.unwrap_or(current_user.email);
    let role = data.role.unwrap_or(current_user.role);
    let now = Utc::now();

    let updated_user = sqlx::query_as!(
        User,
        r#"
        UPDATE user_account
        SET email = $1, role = $2, updated_at = $3
        WHERE user_id = $4
        RETURNING user_id, email, password_hash, role, created_at as "created_at!", updated_at, deleted_at
        "#,
        email,
        role,
        now,
        user_id
    )
    .fetch_one(pool)
    .await?;

    Ok(Some(updated_user))
}

/// Realiza um "soft delete" (marca como deletado) em um usuário
pub async fn delete_user(pool: &PgPool, user_id: i64) -> Result<u64, sqlx::Error> {
    let now = Utc::now();
    let result = sqlx::query!(
        "UPDATE user_account SET deleted_at = $1 WHERE user_id = $2 AND deleted_at IS NULL",
        now,
        user_id
    )
    .execute(pool)
    .await?;

    // Retorna o número de linhas afetadas. Será 0 se o usuário não foi encontrado ou já estava deletado.
    Ok(result.rows_affected())
}