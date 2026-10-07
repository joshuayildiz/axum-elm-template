use elm_rs::{Elm, ElmDecode, ElmEncode};
use serde::{Deserialize, Serialize};
use std::io;

pub(crate) fn genelm() -> io::Result<()> {
    let mut buf = Vec::new();
    elm_rs::export!("Api.Types", &mut buf, {
        encoders: [HelloResponse, LoginRequest, UserResponse, MeResponse, AuthError,
                   CreateUser, CreateRole, RoleResponse, PermissionBody, PermissionsBody,
                   RoleBody, PermissionInfo],
        decoders: [HelloResponse, LoginRequest, UserResponse, MeResponse, AuthError,
                   CreateUser, CreateRole, RoleResponse, PermissionBody, PermissionsBody,
                   RoleBody, PermissionInfo],
    })
    .expect("error generating Elm bindings");
    println!(
        "{}",
        String::from_utf8(buf).expect("error decoding Elm output as UTF-8")
    );
    Ok(())
}

#[derive(Clone, Debug, Serialize, Deserialize, Elm, ElmEncode, ElmDecode)]
pub(crate) struct HelloResponse {
    pub(crate) message: String,
}

#[derive(Clone, Debug, Serialize, Deserialize, Elm, ElmEncode, ElmDecode)]
pub(crate) struct LoginRequest {
    pub(crate) email: String,
    pub(crate) password: String,
}

#[derive(Clone, Debug, Serialize, Deserialize, Elm, ElmEncode, ElmDecode)]
pub(crate) struct UserResponse {
    pub(crate) id: String,
    pub(crate) email: String,
    pub(crate) name: Option<String>,
    pub(crate) is_admin: bool,
}

#[derive(Clone, Debug, Serialize, Deserialize, Elm, ElmEncode, ElmDecode)]
pub(crate) struct MeResponse {
    pub(crate) id: String,
    pub(crate) email: String,
    pub(crate) name: Option<String>,
    pub(crate) is_admin: bool,
    pub(crate) permissions: Vec<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize, Elm, ElmEncode, ElmDecode)]
pub(crate) enum AuthError {
    InvalidCredentials,
    AccountDeactivated,
    NotSignedIn,
}

#[derive(Clone, Debug, Serialize, Deserialize, Elm, ElmEncode, ElmDecode)]
pub(crate) struct CreateUser {
    pub(crate) email: String,
    pub(crate) password: String,
    pub(crate) name: Option<String>,
    pub(crate) is_admin: bool,
}

#[derive(Clone, Debug, Serialize, Deserialize, Elm, ElmEncode, ElmDecode)]
pub(crate) struct CreateRole {
    pub(crate) name: String,
    pub(crate) description: Option<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize, Elm, ElmEncode, ElmDecode)]
pub(crate) struct RoleResponse {
    pub(crate) id: String,
    pub(crate) name: String,
    pub(crate) description: Option<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize, Elm, ElmEncode, ElmDecode)]
pub(crate) struct PermissionBody {
    pub(crate) permission: String,
}

#[derive(Clone, Debug, Serialize, Deserialize, Elm, ElmEncode, ElmDecode)]
pub(crate) struct PermissionsBody {
    pub(crate) permissions: Vec<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize, Elm, ElmEncode, ElmDecode)]
pub(crate) struct RoleBody {
    pub(crate) role_id: String,
}

#[derive(Clone, Debug, Serialize, Deserialize, Elm, ElmEncode, ElmDecode)]
pub(crate) struct PermissionInfo {
    pub(crate) name: String,
    pub(crate) parent: Option<String>,
}

impl axum::response::IntoResponse for AuthError {
    fn into_response(self) -> axum::response::Response {
        use axum::http::StatusCode;

        let status = match &self {
            AuthError::InvalidCredentials => StatusCode::UNAUTHORIZED,
            AuthError::AccountDeactivated => StatusCode::FORBIDDEN,
            AuthError::NotSignedIn => StatusCode::UNAUTHORIZED,
        };
        (status, axum::Json(self)).into_response()
    }
}
