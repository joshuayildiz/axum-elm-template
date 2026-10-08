use jsonwebtoken::{DecodingKey, EncodingKey, Header, Validation, decode, encode};
use serde::{Deserialize, Serialize};
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Serialize, Deserialize)]
pub(crate) struct Claims {
    pub(crate) sub: String,
    pub(crate) exp: usize,
    pub(crate) totp_pending: bool,
}

pub(crate) fn sign_token(user_id: &str, secret: &str) -> String {
    sign(user_id, secret, 60, false)
}

pub(crate) fn sign_pending_token(user_id: &str, secret: &str) -> String {
    sign(user_id, secret, 300, true)
}

fn sign(user_id: &str, secret: &str, ttl_seconds: usize, totp_pending: bool) -> String {
    let exp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .expect("error reading system clock")
        .as_secs() as usize
        + ttl_seconds;

    let claims = Claims {
        sub: user_id.to_string(),
        exp,
        totp_pending,
    };

    encode(
        &Header::default(), // Header::default() uses HS256
        &claims,
        &EncodingKey::from_secret(secret.as_bytes()),
    )
    .expect("error signing token")
}

pub(crate) fn read_token(token: &str, secret: &str) -> Result<Claims, jsonwebtoken::errors::Error> {
    let data = decode::<Claims>(
        token,
        &DecodingKey::from_secret(secret.as_bytes()),
        &Validation::default(), // HS256 and checks the expiry
    )?;
    Ok(data.claims)
}
