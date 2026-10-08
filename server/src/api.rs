use elm_rs::{Elm, ElmDecode, ElmEncode};
use serde::{Deserialize, Serialize};
use std::io;

pub(crate) fn genelm() -> io::Result<()> {
    let mut buf = Vec::new();
    elm_rs::export!("Api.Types", &mut buf, {
        encoders: [LoginRequest, UserResponse, MeResponse, AuthError,
                   CreateUser, CreateRole, RoleResponse, PermissionBody, PermissionsBody,
                   RoleBody, PermissionInfo, ServerMessage, ClientMessage,
                   LoginResponse, ChangePassword, PasswordError, TotpSetup, TotpCode,
                   TotpConfirm, TotpDisable, SettingKind, SettingInfo, SettingUpdate,
                   SettingsBody, PublicConfig, RegisterRequest, RegistrationError,
                   UserPage, RolePage],
        decoders: [LoginRequest, UserResponse, MeResponse, AuthError,
                   CreateUser, CreateRole, RoleResponse, PermissionBody, PermissionsBody,
                   RoleBody, PermissionInfo, ServerMessage, ClientMessage,
                   LoginResponse, ChangePassword, PasswordError, TotpSetup, TotpCode,
                   TotpConfirm, TotpDisable, SettingKind, SettingInfo, SettingUpdate,
                   SettingsBody, PublicConfig, RegisterRequest, RegistrationError,
                   UserPage, RolePage],
    })
    .expect("error generating Elm bindings");
    println!(
        "{}",
        String::from_utf8(buf).expect("error decoding Elm output as UTF-8")
    );
    Ok(())
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
    pub(crate) totp_enabled: bool,
    pub(crate) company_name: String,
}

#[derive(Clone, Debug, Serialize, Deserialize, Elm, ElmEncode, ElmDecode)]
pub(crate) enum AuthError {
    InvalidCredentials,
    AccountDeactivated,
    NotSignedIn,
    InvalidCode,
}

#[derive(Clone, Debug, Serialize, Deserialize, Elm, ElmEncode, ElmDecode)]
pub(crate) enum LoginResponse {
    Authenticated { user: UserResponse },
    TotpRequired,
}

#[derive(Clone, Debug, Serialize, Deserialize, Elm, ElmEncode, ElmDecode)]
pub(crate) struct ChangePassword {
    pub(crate) current_password: String,
    pub(crate) new_password: String,
}

#[derive(Clone, Debug, Serialize, Deserialize, Elm, ElmEncode, ElmDecode)]
pub(crate) enum PasswordError {
    IncorrectPassword,
    PasswordTooShort,
}

#[derive(Clone, Debug, Serialize, Deserialize, Elm, ElmEncode, ElmDecode)]
pub(crate) struct TotpSetup {
    pub(crate) secret: String,
    pub(crate) otpauth_url: String,
    pub(crate) qr_png: String,
}

#[derive(Clone, Debug, Serialize, Deserialize, Elm, ElmEncode, ElmDecode)]
pub(crate) struct TotpCode {
    pub(crate) code: String,
}

#[derive(Clone, Debug, Serialize, Deserialize, Elm, ElmEncode, ElmDecode)]
pub(crate) struct TotpConfirm {
    pub(crate) secret: String,
    pub(crate) code: String,
}

#[derive(Clone, Debug, Serialize, Deserialize, Elm, ElmEncode, ElmDecode)]
pub(crate) struct TotpDisable {
    pub(crate) password: String,
}

#[derive(Clone, Debug, Serialize, Deserialize, Elm, ElmEncode, ElmDecode)]
pub(crate) struct CreateUser {
    pub(crate) email: String,
    pub(crate) password: String,
    pub(crate) name: Option<String>,
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

#[derive(Clone, Copy, Debug, Serialize, Deserialize, Elm, ElmEncode, ElmDecode)]
pub(crate) enum SettingKind {
    Bool,
    Text,
}

#[derive(Clone, Debug, Serialize, Deserialize, Elm, ElmEncode, ElmDecode)]
pub(crate) struct SettingInfo {
    pub(crate) name: String,
    pub(crate) value: String,
    pub(crate) kind: SettingKind,
}

#[derive(Clone, Debug, Serialize, Deserialize, Elm, ElmEncode, ElmDecode)]
pub(crate) struct SettingUpdate {
    pub(crate) name: String,
    pub(crate) value: String,
}

#[derive(Clone, Debug, Serialize, Deserialize, Elm, ElmEncode, ElmDecode)]
pub(crate) struct SettingsBody {
    pub(crate) settings: Vec<SettingUpdate>,
}

#[derive(Clone, Debug, Serialize, Deserialize, Elm, ElmEncode, ElmDecode)]
pub(crate) struct PublicConfig {
    pub(crate) company_name: String,
    pub(crate) registration_enabled: bool,
}

#[derive(Clone, Debug, Serialize, Deserialize, Elm, ElmEncode, ElmDecode)]
pub(crate) struct UserPage {
    pub(crate) items: Vec<UserResponse>,
    pub(crate) total: i64,
    pub(crate) page: i64,
    pub(crate) per_page: i64,
}

#[derive(Clone, Debug, Serialize, Deserialize, Elm, ElmEncode, ElmDecode)]
pub(crate) struct RolePage {
    pub(crate) items: Vec<RoleResponse>,
    pub(crate) total: i64,
    pub(crate) page: i64,
    pub(crate) per_page: i64,
}

#[derive(Clone, Debug, Serialize, Deserialize, Elm, ElmEncode, ElmDecode)]
pub(crate) struct RegisterRequest {
    pub(crate) email: String,
    pub(crate) password: String,
    pub(crate) name: Option<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize, Elm, ElmEncode, ElmDecode)]
pub(crate) enum RegistrationError {
    RegistrationDisabled,
    EmailTaken,
    InvalidEmail,
    WeakPassword,
}

// A message the server pushes down the websocket to a client. The server owns
// the truth, so a client learns who is online and sees every broadcast only
// from these messages, never from its own local state.
#[derive(Clone, Debug, Serialize, Deserialize, Elm, ElmEncode, ElmDecode)]
pub(crate) enum ServerMessage {
    // The full set of online user ids, sent once when a socket opens.
    Snapshot { online: Vec<String> },
    // A user opened their first connection.
    Online { user_id: String },
    // A user closed their last connection.
    Offline { user_id: String },
    // A broadcast line, relayed to every connected client. `from` is the
    // sender email, for display.
    Broadcast { from: String, text: String },
}

// A message a client sends up the websocket. The server relays it to everyone.
// The variant name differs from `ServerMessage::Broadcast` because both enums
// share one Elm module, where two constructors cannot have the same name.
#[derive(Clone, Debug, Serialize, Deserialize, Elm, ElmEncode, ElmDecode)]
pub(crate) enum ClientMessage {
    SendBroadcast { text: String },
}

impl axum::response::IntoResponse for AuthError {
    fn into_response(self) -> axum::response::Response {
        use axum::http::StatusCode;

        let status = match &self {
            AuthError::InvalidCredentials => StatusCode::UNAUTHORIZED,
            AuthError::AccountDeactivated => StatusCode::FORBIDDEN,
            AuthError::NotSignedIn => StatusCode::UNAUTHORIZED,
            AuthError::InvalidCode => StatusCode::UNAUTHORIZED,
        };
        (status, axum::Json(self)).into_response()
    }
}
