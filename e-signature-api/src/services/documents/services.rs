use super::models::{CreateDocument, Document, UpdateDocument, CreateSigner, Signer};
use sqlx::PgPool;

pub async fn create_document_and_signer(
    pool: &PgPool,
    new_document: CreateDocument,
) -> Result<Document, sqlx::Error> {
    let mut tx = pool.begin().await?;
    let document = sqlx::query_as!(
        Document,
        r#"
        INSERT INTO document (company_id, file_name, file_path, hash_sha256, status_id)
        VALUES ($1, $2, $3, $4, $5)
        RETURNING document_id, company_id, file_name, file_path, hash_sha256, status_id, created_at, updated_at, deleted_at
        "#,
        new_document.company_id,
        new_document.file_name,
        new_document.file_path,
        new_document.hash_sha256,
        new_document.status_id
    )
    .fetch_one(&mut *tx)
    .await?;

    let existing_signer = sqlx::query!(
        r#"
        SELECT signer_id
        FROM signer
        WHERE national_id = $1 AND deleted_at IS NULL
        "#,
        new_document.signer_national_id
    )
    .fetch_optional(&mut *tx)
    .await?;

    let signer_id = if let Some(s) = existing_signer {
        s.signer_id
    } else {
        let new_signer = sqlx::query!(
            r#"
            INSERT INTO signer (full_name, phone_number, contact_email, national_id, photo_id_url)
            VALUES ($1, $2, $3, $4, $5)
            RETURNING signer_id
            "#,
            new_document.signer_full_name,
            new_document.signer_phone_number,
            new_document.signer_email,
            new_document.signer_national_id,
            new_document.photo_id_url
        )
        .fetch_one(&mut *tx)
        .await?;
        new_signer.signer_id
    };

    sqlx::query!(
        r#"
        INSERT INTO document_signer (document_id, signer_id, status_id)
        VALUES ($1, $2, $3)
        "#,
        document.document_id,
        signer_id,
        1 
    )
    .execute(&mut *tx)
    .await?;

    tx.commit().await?;

    Ok(document)
}


pub async fn get_all_documents(pool: &PgPool) -> Result<Vec<Document>, sqlx::Error> {
    let documents = sqlx::query_as!(
        Document,
        r#"
        SELECT document_id, company_id, file_name, file_path, hash_sha256, status_id, created_at, updated_at, deleted_at
        FROM document
        WHERE deleted_at IS NULL
        ORDER BY document_id
        "#
    )
    .fetch_all(pool)
    .await?;
    Ok(documents)
}

pub async fn get_document_by_id(pool: &PgPool, document_id: i64) -> Result<Option<Document>, sqlx::Error> {
    let document = sqlx::query_as!(
        Document,
        r#"
        SELECT document_id, company_id, file_name, file_path, hash_sha256, status_id, created_at, updated_at, deleted_at
        FROM document
        WHERE document_id = $1 AND deleted_at IS NULL
        "#,
        document_id
    )
    .fetch_optional(pool)
    .await?;
    Ok(document)
}

pub async fn update_document(
    pool: &PgPool,
    document_id: i64,
    data: UpdateDocument,
) -> Result<Option<Document>, sqlx::Error> {
    let current_document = match get_document_by_id(pool, document_id).await? {
        Some(document) => document,
        None => return Ok(None),
    };

    let file_name = data.file_name.unwrap_or(current_document.file_name);
    let status_id = data.status_id.unwrap_or(current_document.status_id);
    let now = chrono::Utc::now();

    let updated_document = sqlx::query_as!(
        Document,
        r#"
        UPDATE document
        SET file_name = $1, status_id = $2, updated_at = $3
        WHERE document_id = $4
        RETURNING document_id, company_id, file_name, file_path, hash_sha256, status_id, created_at, updated_at, deleted_at
        "#,
        file_name,
        status_id,
        now,
        document_id
    )
    .fetch_one(pool)
    .await?;

    Ok(Some(updated_document))
}

pub async fn delete_document(pool: &PgPool, document_id: i64) -> Result<u64, sqlx::Error> {
    let now = chrono::Utc::now();
    let result = sqlx::query!(
        "UPDATE document SET deleted_at = $1 WHERE document_id = $2 AND deleted_at IS NULL",
        now,
        document_id
    )
    .execute(pool)
    .await?;

    Ok(result.rows_affected())
}


/*pub async fn get_signers_for_document(pool: &PgPool, document_id: i64) -> Result<Vec<Signer>, sqlx::Error> {
    let signers = sqlx::query_as!(
        Signer,
        r#"
        SELECT  s.signer_id, s.full_name, s.national_id, s.phone_number,
               s.contact_email, s.public_key, s.photo_id_url,
               s.created_at, s.updated_at, s.deleted_at, s.user_id
        FROM signer s
        INNER JOIN document_signer ds ON ds.signer_id = s.signer_id
        WHERE ds.document_id = $1 AND s.deleted_at IS NULL
        ORDER BY ds.sign_order
        "#,
        document_id
    )
    .fetch_all(pool)
    .await?;

    Ok(signers)
}*/
