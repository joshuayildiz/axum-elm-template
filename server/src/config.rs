pub(crate) struct Config {
    pub(crate) database_url: String,
    pub(crate) jwt_secret: String,
}

impl Config {
    pub(crate) fn from_env() -> Config {
        Config {
            database_url: std::env::var("DATABASE_URL").expect("error reading DATABASE_URL"),
            jwt_secret: std::env::var("JWT_SECRET").expect("error reading JWT_SECRET"),
        }
    }
}
