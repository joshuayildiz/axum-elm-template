use elm_rs::{Elm, ElmDecode, ElmEncode};
use serde::{Deserialize, Serialize};
use std::io;

pub(crate) fn genelm() -> io::Result<()> {
    let mut buf = Vec::new();
    elm_rs::export!("Api.Types", &mut buf, {
        encoders: [HelloResponse],
        decoders: [HelloResponse],
    })
    .expect("generate Elm bindings");
    println!("{}", String::from_utf8(buf).expect("elm output is utf8"));
    Ok(())
}

#[derive(Clone, Debug, Serialize, Deserialize, Elm, ElmEncode, ElmDecode)]
pub struct HelloResponse {
    pub message: String,
}
