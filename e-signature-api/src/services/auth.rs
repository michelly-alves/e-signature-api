use chrono::{Duration, Utc};
use jsonwebtoken::{decode, encode, DecodingKey, EncodingKey, Header, Validation};
use serde::{Deserialize, Serialize};
use std::env;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Claims {
    pub sub: String,
    pub exp: usize, 
    pub iat: usize, 
}

pub fn create_jwt(user_id: &str) -> Result<String, jsonwebtoken::errors::Error> {
    let expiration = Utc::now()
        .checked_add_signed(Duration::hours(1)) 
        .expect("valid timestamp")
        .timestamp();

    let claims = Claims {
        sub: user_id.to_owned(),
        iat: Utc::now().timestamp() as usize,
        exp: expiration as usize,
    };

    let secret = env::var("JSON_WEB_TOKEN_SECRET").expect("JWT_SECRET must be set");
    let header = Header::default();
    let encoding_key = EncodingKey::from_secret(secret.as_ref());

    encode(&header, &claims, &encoding_key)
}

pub fn validate_jwt(token: &str) -> Result<Claims, jsonwebtoken::errors::Error> {
    let secret = env::var("JSON_WEB_TOKEN_SECRET").expect("JWT_SECRET must be set");
    let decoding_key = DecodingKey::from_secret(secret.as_ref());
    let validation = Validation::default();

    decode::<Claims>(token, &decoding_key, &validation).map(|data| data.claims)
}
