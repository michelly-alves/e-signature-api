use crate::services::users::models::{CreateUser, Role, UpdateUser, User};
use bcrypt::{DEFAULT_COST, hash};
use chrono::Utc;
use sqlx::PgPool;

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
