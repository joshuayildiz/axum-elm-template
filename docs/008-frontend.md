# Frontend

This page covers the client experience: theming, languages, pagination, and
real-time presence.

## Theming

Colors and corner radius are design tokens. A design token is a CSS variable that
every component reads. This follows the shadcn and Tailwind v4 model.

- Tokens: role-based names such as `primary`, `secondary`, `muted`, and
  `destructive`, each with a readable foreground pair.
- Light and dark: a `dark` class on the document switches from the light palette to
  the dark palette.
- Toggle: the user picks System, Light, or Dark. The browser stores the choice and
  applies it before paint, so there is no flash.
- Sharpness: one `--radius` value scales every rounded corner.
- Rebrand: you edit the token values in `client/app.css` in one place.

## Internationalization

The client holds every user-facing string in one record, with one complete record
per language.

- Languages: English and Turkish.
- Safety: the compiler rejects a language that misses a key.
- Switch: a selector in the sidebar and on the sign-in screen changes the language,
  and the browser stores the choice.

## Pagination

The server pages the user and role lists, so the client holds one page at a time.

- Request: the `page`, `per_page`, and `search` query parameters.
- Response: the page items, the total count, the page number, and the page size.
- Search: the server matches the term against the name and other text columns, and
  it ignores letter case.
- Page size: the client sizes a page to the window height, so a list fills the
  screen without its own scrollbar.

## Real-time presence and broadcast

The client opens a websocket once the user signs in. A websocket is a two-way
connection the server uses to push updates.

- Presence: the user list shows a live dot for each connected user.
- Broadcast: a user sends a line, and the server relays it to every connected
  client.
- Endpoint: `GET /api/v1/ws`.
