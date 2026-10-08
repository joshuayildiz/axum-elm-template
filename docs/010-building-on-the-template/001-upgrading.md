# Upgrade to a newer template

This page explains how to move a project onto a newer version of the template. It
assumes you started the project by cloning the template, so the two share a git
history. See [Build on the template](000-index.md).

## Merge the update

Fetch the template remote and merge its main branch:

```sh
git fetch template
git merge template/main
```

Most of your own work is in new files, such as new routes, new Elm pages, and new
migrations. Those files merge without conflict. Conflicts group in a small set of
shared files that both you and the template change:

- `server/src/api.rs`: the two type lists for the shared types.
- `server/src/router/mod.rs`: the route wiring.
- `client/src/Main.elm`: the top-level client wiring.
- `server/Cargo.toml`: the dependency list.
- `client/app.css`: the theme tokens.

Resolve those files by hand.

## Rebuild the generated types

The file `client/src/Api/Types.elm` is generated from the Rust types. It often shows
conflict markers after a merge. Ignore them and rebuild the file:

```sh
make genelm
```

## Make sure the result works

Run the build, the tests, and the format checks:

```sh
cd server && cargo build
cd client && elm make src/Main.elm --output /dev/null
make coverage
make format
```

## Record the new baseline

Stamp `.template-version` with the template commit you merged, so the next upgrade
starts from the right point:

```sh
git rev-parse template/main > .template-version
git add .template-version && git commit -m "Upgrade template baseline"
```

## Apply new migrations

The database applies migrations in timestamp order. A template update can add new
migrations with a timestamp prefix. Your own migrations also carry a timestamp, so
the two sets interleave by time and do not collide. Apply the new migrations the same
way as any other:

```sh
cd server && sqlx migrate run
```

## If the project has no shared history

If you started the project without a shared history, a merge does not work well. Use
a patch instead. The commit in `.template-version` is your baseline. Build a diff
between that baseline and the new version in a template checkout, then apply it to
your project:

```sh
git -C ../axum-elm-template diff $(cat .template-version)..template/main > update.patch
git apply --3way update.patch
```

Resolve any rejected parts by hand. The clone-with-history path avoids this work, so
plan for it when you start a new project.
