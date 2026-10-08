pub(crate) struct Config {
    pub(crate) database_url: String,
    pub(crate) jwt_secret: String,
    pub(crate) telemetry: Option<TelemetryConfig>,
}

pub(crate) struct TelemetryConfig {
    pub(crate) endpoint: String,
    pub(crate) service_name: String,
    pub(crate) environment: Option<Environment>,
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
            telemetry: telemetry_from_env(),
        }
    }
}

fn telemetry_from_env() -> Option<TelemetryConfig> {
    let endpoint = non_empty("OTEL_EXPORTER_OTLP_ENDPOINT")?;
    let service_name = non_empty("OTEL_SERVICE_NAME").expect(
        "error reading OTEL_SERVICE_NAME, which is required when OTEL_EXPORTER_OTLP_ENDPOINT is set",
    );

    Some(TelemetryConfig {
        endpoint,
        service_name,
        environment: non_empty("DEPLOY_ENV").map(|value| {
            Environment::parse(&value).unwrap_or_else(|| {
                panic!(
                    "error parsing DEPLOY_ENV '{value}', expected one of: local, development, staging, production"
                )
            })
        }),
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
