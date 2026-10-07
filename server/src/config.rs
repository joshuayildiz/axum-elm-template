pub(crate) struct Config {
    pub(crate) database_url: String,
    pub(crate) jwt_secret: String,
    pub(crate) enable_registration: bool,
    pub(crate) totp_issuer: String,
}

impl Config {
    pub(crate) fn from_env() -> Config {
        Config {
            database_url: std::env::var("DATABASE_URL").expect("error reading DATABASE_URL"),
            jwt_secret: std::env::var("JWT_SECRET").expect("error reading JWT_SECRET"),
            enable_registration: std::env::var("ENABLE_REGISTRATION")
                .map(|v| v == "true")
                .unwrap_or(false),
            totp_issuer: std::env::var("TOTP_ISSUER").expect("error reading TOTP_ISSUER"),
        }
    }
}
