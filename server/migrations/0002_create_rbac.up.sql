create table roles (
    id         uuid primary key default uuidv7(),
    name       text unique not null,
    created_at timestamptz not null default now()
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
