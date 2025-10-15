CREATE TABLE user_account (
    user_id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    password_hash CHAR(60) NOT NULL,
    is_verified INT NOT NULL DEFAULT 0,
    role INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,
    deleted_at TIMESTAMPTZ NULL
);

CREATE UNIQUE INDEX user_account_email_idx ON user_account (email) WHERE deleted_at IS NULL;
