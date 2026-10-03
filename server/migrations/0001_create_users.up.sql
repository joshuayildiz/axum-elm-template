create table users (
    id            uuid primary key default uuidv7(),
    email         text unique not null,
    password_hash text not null,
    name          text,
    is_admin      boolean not null default false,
    created_at    timestamptz not null default now(),
    last_login_at timestamptz,
    deleted_at    timestamptz
);
