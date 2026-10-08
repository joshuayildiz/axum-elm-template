use crate::api::{AuthError, UserResponse};
use crate::router::AppState;
use crate::telemetry::Traced;
use axum::Json;
use axum::extract::{FromRequestParts, Request, State};
use axum::http::request::Parts;
use axum::middleware::Next;
use axum::response::{IntoResponse, Response};
use axum_extra::extract::cookie::CookieJar;

// The authenticated, active user. The auth middleware loads it once and puts it
// in the request; protected handlers read it with this as an extractor.
#[derive(Clone)]
pub(crate) struct CurrentUser {
    pub(crate) id: String,
    pub(crate) email: String,
    pub(crate) name: Option<String>,
    pub(crate) is_admin: bool,
    pub(crate) totp_enabled: bool,
}

impl From<CurrentUser> for UserResponse {
    fn from(user: CurrentUser) -> Self {
        UserResponse {
            id: user.id,
            email: user.email,
            name: user.name,
            is_admin: user.is_admin,
        }
    }
}

impl FromRequestParts<AppState> for CurrentUser {
    type Rejection = AuthError;

    async fn from_request_parts(
        parts: &mut Parts,
        _state: &AppState,
    ) -> Result<Self, Self::Rejection> {
        parts
            .extensions
            .get::<CurrentUser>()
            .cloned()
            .ok_or(AuthError::NotSignedIn)
    }
}

fn not_signed_in() -> Response {
    Json(Err::<UserResponse, AuthError>(AuthError::NotSignedIn)).into_response()
}

// The single auth gate for protected routes. It validates the token, loads the
// active user, rejects anyone not signed in or deactivated, puts the user in the
// request for the handler to read, and renews the token on the way out. Handlers
// behind it never touch tokens, cookies, or the account check.
pub(crate) async fn require_auth(
    State(state): State<AppState>,
    jar: CookieJar,
    mut request: Request,
    next: Next,
) -> Response {
    let Some(claims) = jar
        .get("token")
        .and_then(|cookie| crate::jwt::read_token(cookie.value(), &state.jwt_secret).ok())
    else {
        return not_signed_in();
    };

    if claims.totp_pending {
        return not_signed_in();
    }

    let Ok(id) = uuid::Uuid::parse_str(&claims.sub) else {
        return not_signed_in();
    };

    let row = sqlx::query!(
        r#"
        select id, email, name, is_admin,
               (totp_secret is not null) as "totp_enabled!"
        from users
        where id = $1 and deleted_at is null
        "#,
        id
    )
    .fetch_optional(&state.pool)
    .traced("auth.current_user")
    .await
    .expect("error querying user");

    let Some(row) = row else {
        return not_signed_in();
    };

    let user = CurrentUser {
        id: row.id.to_string(),
        email: row.email,
        name: row.name,
        is_admin: row.is_admin,
        totp_enabled: row.totp_enabled,
    };

    let span = tracing::Span::current();
    span.record("user.id", user.id.as_str());
    span.record("user.email", user.email.as_str());

    request.extensions_mut().insert(user.clone());
    let response = next.run(request).await;

    let token = crate::jwt::sign_token(&user.id, &state.jwt_secret);
    (jar.add(super::token_cookie(token)), response).into_response()
}
