mod definition;

pub(crate) use definition::{Definition, all, definition, get, set};

use crate::api::SettingKind;

pub(crate) const REGISTRATION_ENABLED: &str = "registration.enabled";
pub(crate) const COMPANY_NAME: &str = "company.name";

pub(crate) const DEFINITIONS: &[Definition] = &[
    Definition {
        name: REGISTRATION_ENABLED,
        default: "false",
        kind: SettingKind::Bool,
    },
    Definition {
        name: COMPANY_NAME,
        default: "Axum Elm Template",
        kind: SettingKind::Text,
    },
];
