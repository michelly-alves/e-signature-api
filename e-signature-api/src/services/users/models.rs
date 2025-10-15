use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::decode::Decode;
use sqlx::encode::{Encode, IsNull};
use sqlx::error::BoxDynError;
use sqlx::postgres::{PgTypeInfo, PgValueRef};
use sqlx::{FromRow, Type};

#[derive(Debug, Serialize, Deserialize, Clone, Copy, PartialEq, Eq)]
#[repr(i32)]
pub enum Role {
    Company = 0,
    Admin = 1,
    Signer = 2,
}

impl Type<sqlx::Postgres> for Role {
    fn type_info() -> PgTypeInfo {
        PgTypeInfo::with_name("INT4")
    }
}

impl Encode<'_, sqlx::Postgres> for Role {
    fn encode_by_ref(
        &self,
        buf: &mut <sqlx::Postgres as sqlx::Database>::ArgumentBuffer<'_>,
    ) -> Result<IsNull, BoxDynError> {
        let val = *self as i32;
        <i32 as Encode<'_, sqlx::Postgres>>::encode_by_ref(&val, buf)
    }
}

impl Decode<'_, sqlx::Postgres> for Role {
    fn decode(value: PgValueRef<'_>) -> Result<Self, BoxDynError> {
        let val = <i32 as Decode<sqlx::Postgres>>::decode(value)?;
        Ok(match val {
            0 => Role::Company,
            1 => Role::Admin,
            2 => Role::Signer,
            _ => return Err("Invalid value for Role".into()),
        })
    }
}

#[derive(Debug, FromRow, Serialize, Deserialize)]
pub struct User {
    pub user_id: i64,
    pub email: String,
    #[serde(skip_serializing)]
    pub password_hash: String,
    pub role: Role,
    pub created_at: DateTime<Utc>,
    pub updated_at: Option<DateTime<Utc>>,
    #[serde(skip)]
    pub deleted_at: Option<DateTime<Utc>>,
    #[serde(skip_serializing)] 
    pub face_embedding: Option<Vec<u8>>,
}

#[derive(Debug, Deserialize)]
pub struct CreateUser {
    pub email: String,
    pub password: String,
    pub role: Role,
    pub legal_name: Option<String>,
    pub tax_id: Option<String>,
    pub full_name: Option<String>,
    pub phone_number: Option<String>,
    pub is_verified: Option<i32>,
    pub national_id: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct UpdateUser {
    pub email: Option<String>,
    pub role: Option<Role>,
}
