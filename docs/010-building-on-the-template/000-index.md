# Build on the template

This page explains how to start a new project from the template so that the project
can take later template updates. The important choice is the git history. Your
project and the template must share a common git ancestor, because a shared ancestor
is what lets git merge template updates later.

## Start a new project

Clone the template. Then point the default remote at your own repository, and keep
the template as a second remote named `template`:

```sh
git clone git@github.com:joshuayildiz/axum-elm-template.git my-app
cd my-app
git remote rename origin template
git remote add origin git@github.com:you/my-app.git
git push -u origin main
```

Do not use the GitHub "Use this template" button or a tool such as `degit`. Both
start a new history with no shared ancestor. Without a shared ancestor, every later
merge treats every file as a conflict.

## Record the template baseline

The file `.template-version` holds the template commit that this project builds on.
Stamp it with the commit you cloned, so the first upgrade has an exact starting
point:

```sh
git rev-parse template/main > .template-version
git add .template-version && git commit -m "Record template baseline"
```

Update this file again after each upgrade. See
[Upgrade to a newer template](001-upgrading.md).

## Make the project your own

Change the parts that name the template:

1. Set `PROJECT` in the `Makefile`.
2. Set `DATABASE_URL`, `JWT_SECRET`, and `DEPLOY_ENV` in `server/.env`. See
   [Configuration](../004-configuration.md).
3. Set the package name in `server/Cargo.toml`, if you want a different binary name.
4. Set the default value for `company.name` in `server/src/settings/mod.rs`.

Then create the database, apply the migrations, and create the first administrator.
The database name must match the name in `DATABASE_URL`:

```sh
createdb my_app
cd server && sqlx migrate run && cargo run -- register
```

## Add your own migrations

The template ships one baseline migration with a timestamp prefix, for example
`20261007181920_initial_schema.up.sql`. Create your own migrations the same way, so
they sort after the template migrations by time. A timestamp prefix also keeps your
migrations from colliding with a future template migration:

```sh
cd server && sqlx migrate add -r --timestamp <name>
```

The `-r` flag creates a matching pair of an `up` file and a `down` file, which is how
the template writes every migration.
