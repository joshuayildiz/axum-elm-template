create table settings (
    name       text primary key,
    value      text not null,
    updated_at timestamptz not null default now()
);
