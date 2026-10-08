create table users (
    id            uuid primary key default uuidv7(),
    email         text unique not null,
    password_hash text not null,
    name          text,
    is_admin      boolean not null default false,
    totp_secret   text,
    created_at    timestamptz not null default now(),
    last_login_at timestamptz,
    deleted_at    timestamptz
);

create table roles (
    id          uuid primary key default uuidv7(),
    name        text unique not null,
    description text,
    created_at  timestamptz not null default now()
);

create table user_roles (
    user_id uuid not null references users(id) on delete cascade,
    role_id uuid not null references roles(id) on delete cascade,
    primary key (user_id, role_id)
);

create table role_permissions (
    role_id    uuid not null references roles(id) on delete cascade,
    permission text not null,
    primary key (role_id, permission)
);

create table user_permissions (
    user_id    uuid not null references users(id) on delete cascade,
    permission text not null,
    primary key (user_id, permission)
);

create table settings (
    name       text primary key,
    value      text not null,
    updated_at timestamptz not null default now()
);
