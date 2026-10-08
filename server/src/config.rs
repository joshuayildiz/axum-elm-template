pub(crate) struct Config {
    pub(crate) database_url: String,
    pub(crate) jwt_secret: String,
    pub(crate) environment: Environment,
    pub(crate) telemetry: Option<TelemetryConfig>,
}

pub(crate) struct TelemetryConfig {
    pub(crate) endpoint: String,
    pub(crate) service_name: String,
    pub(crate) host_name: Option<String>,
    pub(crate) sample_ratio: f64,
}

#[derive(Clone, Copy, Debug)]
pub(crate) enum Environment {
    Local,
    Development,
    Staging,
    Production,
}

impl Environment {
    pub(crate) fn as_str(self) -> &'static str {
        match self {
            Environment::Local => "local",
            Environment::Development => "development",
            Environment::Staging => "staging",
            Environment::Production => "production",
        }
    }

    pub(crate) fn is_secure(self) -> bool {
        !matches!(self, Environment::Local)
    }

    fn parse(value: &str) -> Option<Environment> {
        match value.trim().to_ascii_lowercase().as_str() {
            "local" => Some(Environment::Local),
            "development" | "dev" => Some(Environment::Development),
            "staging" | "stage" => Some(Environment::Staging),
            "production" | "prod" => Some(Environment::Production),
            _ => None,
        }
    }
}

impl Config {
    pub(crate) fn from_env() -> Config {
        Config {
            database_url: std::env::var("DATABASE_URL").expect("error reading DATABASE_URL"),
            jwt_secret: std::env::var("JWT_SECRET").expect("error reading JWT_SECRET"),
            environment: environment_from_env(),
            telemetry: telemetry_from_env(),
        }
    }
}

fn environment_from_env() -> Environment {
    let value = non_empty("DEPLOY_ENV").expect(
        "error reading DEPLOY_ENV, which must be one of: local, development, staging, production",
    );
    Environment::parse(&value).unwrap_or_else(|| {
        panic!(
            "error parsing DEPLOY_ENV '{value}', expected one of: local, development, staging, production"
        )
    })
}

fn telemetry_from_env() -> Option<TelemetryConfig> {
    let endpoint = non_empty("OTEL_EXPORTER_OTLP_ENDPOINT")?;
    let service_name = non_empty("OTEL_SERVICE_NAME").expect(
        "error reading OTEL_SERVICE_NAME, which is required when OTEL_EXPORTER_OTLP_ENDPOINT is set",
    );

    Some(TelemetryConfig {
        endpoint,
        service_name,
        host_name: non_empty("HOSTNAME"),
        sample_ratio: non_empty("OTEL_TRACES_SAMPLER_ARG")
            .expect(
                "error reading OTEL_TRACES_SAMPLER_ARG, which is required when OTEL_EXPORTER_OTLP_ENDPOINT is set",
            )
            .parse::<f64>()
            .expect("error parsing OTEL_TRACES_SAMPLER_ARG as a number between 0 and 1")
            .clamp(0.0, 1.0),
    })
}

fn non_empty(name: &str) -> Option<String> {
    std::env::var(name)
        .ok()
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
}

#[cfg(test)]
mod tests {
    use super::Environment;

    #[test]
    fn parses_known_environments_and_aliases() {
        assert!(matches!(
            Environment::parse("local"),
            Some(Environment::Local)
        ));
        assert!(matches!(
            Environment::parse("dev"),
            Some(Environment::Development)
        ));
        assert!(matches!(
            Environment::parse("development"),
            Some(Environment::Development)
        ));
        assert!(matches!(
            Environment::parse("stage"),
            Some(Environment::Staging)
        ));
        assert!(matches!(
            Environment::parse("  PRODUCTION "),
            Some(Environment::Production)
        ));
        assert!(Environment::parse("nonsense").is_none());
    }

    #[test]
    fn local_is_the_only_insecure_environment() {
        assert!(!Environment::Local.is_secure());
        assert!(Environment::Development.is_secure());
        assert!(Environment::Staging.is_secure());
        assert!(Environment::Production.is_secure());
        assert_eq!(Environment::Production.as_str(), "production");
    }
}
