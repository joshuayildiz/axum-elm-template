use crate::config::Config;
use opentelemetry::Context;
use opentelemetry::trace::{Status, TraceId, TracerProvider as _};
use opentelemetry_otlp::{Protocol, WithExportConfig};
use opentelemetry_sdk::Resource;
use opentelemetry_sdk::error::OTelSdkResult;
use opentelemetry_sdk::propagation::TraceContextPropagator;
use opentelemetry_sdk::trace::{
    BatchSpanProcessor, SdkTracerProvider, Span, SpanData, SpanProcessor,
};
use std::collections::HashMap;
use std::future::Future;
use std::sync::Mutex;
use std::time::{Duration, Instant};
use tracing::Instrument;
use tracing_subscriber::layer::SubscriberExt;
use tracing_subscriber::util::SubscriberInitExt;
use tracing_subscriber::{EnvFilter, fmt};

pub(crate) fn init(config: &Config) -> Option<SdkTracerProvider> {
    let filter = EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| EnvFilter::new("info,sqlx::query=warn"));

    let registry = tracing_subscriber::registry()
        .with(filter)
        .with(fmt::layer().with_writer(std::io::stderr));

    match build_provider(config) {
        Some(provider) => {
            let tracer = provider.tracer(env!("CARGO_PKG_NAME"));
            registry
                .with(tracing_opentelemetry::layer().with_tracer(tracer))
                .init();
            if let Some(telemetry) = &config.telemetry {
                tracing::info!(
                    "exporting traces to {} as service {}",
                    telemetry.endpoint,
                    telemetry.service_name
                );
            }
            Some(provider)
        }

        None => {
            registry.init();
            None
        }
    }
}

fn build_provider(config: &Config) -> Option<SdkTracerProvider> {
    let telemetry = config.telemetry.as_ref()?;

    opentelemetry::global::set_text_map_propagator(TraceContextPropagator::new());

    let exporter = opentelemetry_otlp::SpanExporter::builder()
        .with_http()
        .with_protocol(Protocol::HttpBinary)
        .build()
        .expect("error building OTLP span exporter");

    let processor = TailSampler::new(
        BatchSpanProcessor::builder(exporter).build(),
        telemetry.sample_ratio,
    );

    let mut resource = Resource::builder()
        .with_service_name(telemetry.service_name.clone())
        .with_attribute(opentelemetry::KeyValue::new(
            "service.version",
            env!("CARGO_PKG_VERSION"),
        ))
        .with_attribute(opentelemetry::KeyValue::new(
            "service.instance.id",
            std::process::id().to_string(),
        ));

    if let Some(host) = &telemetry.host_name {
        resource = resource.with_attribute(opentelemetry::KeyValue::new("host.name", host.clone()));
    }

    resource = resource.with_attribute(opentelemetry::KeyValue::new(
        "deployment.environment",
        config.environment.as_str(),
    ));

    let resource = resource.build();

    Some(
        SdkTracerProvider::builder()
            .with_span_processor(processor)
            .with_resource(resource)
            .build(),
    )
}

pub(crate) fn shutdown(provider: Option<SdkTracerProvider>) {
    if let Some(provider) = provider {
        if let Err(error) = provider.shutdown() {
            tracing::warn!("error shutting down tracer provider: {error}");
        }
    }
}

const MAX_TRACE_AGE: Duration = Duration::from_secs(20);
const MAX_SPANS_PER_TRACE: usize = 2048;
const MAX_DECIDED: usize = 10_000;

#[derive(Debug)]
struct Buffered {
    first_seen: Instant,
    spans: Vec<SpanData>,
}

#[derive(Debug, Default)]
struct TailState {
    buffers: HashMap<TraceId, Buffered>,
    decided: HashMap<TraceId, bool>,
}

#[derive(Debug)]
struct TailSampler<P> {
    inner: P,
    keep_per_million: u64,
    state: Mutex<TailState>,
}

impl<P> TailSampler<P> {
    fn new(inner: P, sample_ratio: f64) -> Self {
        TailSampler {
            inner,
            keep_per_million: (sample_ratio * 1_000_000.0) as u64,
            state: Mutex::new(TailState::default()),
        }
    }

    fn decide(&self, trace_id: TraceId, spans: &[SpanData]) -> bool {
        let errored = spans
            .iter()
            .any(|span| matches!(span.status, Status::Error { .. }));
        let bytes = trace_id.to_bytes();
        let tail = u64::from_be_bytes(bytes[8..16].try_into().unwrap());
        errored || tail % 1_000_000 < self.keep_per_million
    }
}

fn remember(decided: &mut HashMap<TraceId, bool>, trace_id: TraceId, keep: bool) {
    if decided.len() >= MAX_DECIDED {
        decided.clear();
    }
    decided.insert(trace_id, keep);
}

impl<P: SpanProcessor> TailSampler<P> {
    fn flush_all(&self) {
        let mut forward = Vec::new();
        {
            let mut state = self.state.lock().expect("error locking tail sampler state");
            let ids: Vec<TraceId> = state.buffers.keys().copied().collect();
            for id in ids {
                let spans = state.buffers.remove(&id).unwrap().spans;
                if self.decide(id, &spans) {
                    forward.extend(spans);
                }
            }
        }
        for span in forward {
            self.inner.on_end(span);
        }
    }
}

impl<P: SpanProcessor> SpanProcessor for TailSampler<P> {
    fn on_start(&self, span: &mut Span, cx: &Context) {
        self.inner.on_start(span, cx);
    }

    fn on_end(&self, span: SpanData) {
        let trace_id = span.span_context.trace_id();
        let is_local_root = span.parent_span_id == opentelemetry::trace::SpanId::INVALID
            || span.parent_span_is_remote;

        let mut forward: Vec<SpanData> = Vec::new();
        {
            let mut state = self.state.lock().expect("error locking tail sampler state");

            if let Some(&keep) = state.decided.get(&trace_id) {
                if keep {
                    forward.push(span);
                }
            } else {
                let buffered = state.buffers.entry(trace_id).or_insert_with(|| Buffered {
                    first_seen: Instant::now(),
                    spans: Vec::new(),
                });
                buffered.spans.push(span);

                if is_local_root || buffered.spans.len() >= MAX_SPANS_PER_TRACE {
                    let spans = state.buffers.remove(&trace_id).unwrap().spans;
                    let keep = self.decide(trace_id, &spans);
                    remember(&mut state.decided, trace_id, keep);
                    if keep {
                        forward = spans;
                    }
                }
            }

            let expired: Vec<TraceId> = state
                .buffers
                .iter()
                .filter(|(_, buffered)| buffered.first_seen.elapsed() > MAX_TRACE_AGE)
                .map(|(id, _)| *id)
                .collect();
            for id in expired {
                let spans = state.buffers.remove(&id).unwrap().spans;
                let keep = self.decide(id, &spans);
                remember(&mut state.decided, id, keep);
                if keep {
                    forward.extend(spans);
                }
            }
        }

        for span in forward {
            self.inner.on_end(span);
        }
    }

    fn force_flush(&self) -> OTelSdkResult {
        self.flush_all();
        self.inner.force_flush()
    }

    fn shutdown_with_timeout(&self, timeout: Duration) -> OTelSdkResult {
        self.flush_all();
        self.inner.shutdown_with_timeout(timeout)
    }

    fn set_resource(&mut self, resource: &Resource) {
        self.inner.set_resource(resource);
    }
}

pub(crate) trait Traced: Future + Sized {
    fn traced(self, name: &'static str) -> tracing::instrument::Instrumented<Self> {
        self.instrument(tracing::info_span!(
            "db.query",
            otel.name = name,
            otel.kind = "client"
        ))
    }
}

impl<F: Future> Traced for F {}
