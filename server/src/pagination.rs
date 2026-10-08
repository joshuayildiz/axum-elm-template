use serde::Deserialize;

#[derive(Debug, Deserialize)]
pub(crate) struct ListParams {
    pub(crate) page: Option<i64>,
    pub(crate) per_page: Option<i64>,
    pub(crate) search: Option<String>,
}

pub(crate) struct Window {
    pub(crate) page: i64,
    pub(crate) per_page: i64,
    pub(crate) limit: i64,
    pub(crate) offset: i64,
    pub(crate) search: Option<String>,
}

impl ListParams {
    pub(crate) fn window(self) -> Window {
        let page = self.page.unwrap_or(1).max(1);
        let per_page = self.per_page.unwrap_or(25).clamp(1, 100);
        let search = self
            .search
            .map(|value| value.trim().to_string())
            .filter(|value| !value.is_empty());

        Window {
            page,
            per_page,
            limit: per_page,
            offset: (page - 1) * per_page,
            search,
        }
    }
}
