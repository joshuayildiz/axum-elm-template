use crate::api::{SettingInfo, SettingKind};
use sqlx::PgPool;
use std::collections::HashMap;

pub(crate) struct Definition {
    pub(crate) name: &'static str,
    pub(crate) default: &'static str,
    pub(crate) kind: SettingKind,
}

pub(crate) fn definition(name: &str) -> Option<&'static Definition> {
    super::DEFINITIONS.iter().find(|def| def.name == name)
}

pub(crate) async fn get(pool: &PgPool, name: &str) -> String {
    let row = sqlx::query!("select value from settings where name = $1", name)
        .fetch_optional(pool)
        .await
        .expect("error reading setting");

    match row {
        Some(row) => row.value,
        None => definition(name)
            .map(|def| def.default.to_string())
            .unwrap_or_default(),
    }
}

pub(crate) async fn get_bool(pool: &PgPool, name: &str) -> bool {
    get(pool, name).await == "true"
}

pub(crate) async fn all(pool: &PgPool) -> Vec<SettingInfo> {
    let rows = sqlx::query!("select name, value from settings")
        .fetch_all(pool)
        .await
        .expect("error reading settings");

    let stored: HashMap<String, String> =
        rows.into_iter().map(|row| (row.name, row.value)).collect();

    super::DEFINITIONS
        .iter()
        .map(|def| SettingInfo {
            name: def.name.to_string(),
            value: stored
                .get(def.name)
                .cloned()
                .unwrap_or_else(|| def.default.to_string()),
            kind: def.kind,
        })
        .collect()
}

pub(crate) async fn set(pool: &PgPool, name: &str, value: &str) {
    sqlx::query!(
        r#"
        insert into settings (name, value)
        values ($1, $2)
        on conflict (name) do update set value = $2, updated_at = now()
        "#,
        name,
        value
    )
    .execute(pool)
    .await
    .expect("error writing setting");
}
