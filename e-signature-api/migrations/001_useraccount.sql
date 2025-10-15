CREATE TABLE user_account (
    user_id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash CHAR(60) NOT NULL,
    role INT NOT NULL DEFAULT 0,
    face_embedding BYTEA NULL, 
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,
    deleted_at TIMESTAMPTZ NULL
);

CREATE UNIQUE INDEX user_account_email_idx ON user_account (email) WHERE deleted_at IS NULL;
