use std::io;

pub(crate) fn cmd() -> io::Result<()> {
    crate::api::genelm()
}
