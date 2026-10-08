# Authentication

A user signs in with an email and a password. The server replies with a session
token in an HTTP-only cookie, so client code never reads the token. HTTP-only means
the browser sends the cookie but scripts cannot read it.

- Sign in: `POST /api/v1/auth/login`.
- Sign out: `POST /api/v1/auth/logout` clears the cookie.
- Current user: `GET /api/v1/auth/me` returns the signed-in user and permissions.
- Change password: `POST /api/v1/auth/password`.

The server hashes passwords with Argon2 before it stores them. A session token is
a JWT. A JWT is a signed token. Because the server signs it with a secret, the
server can accept it later without a database lookup. A sign-in for a missing
account still computes a password hash, so a wrong email and a wrong password take
the same time to answer.

## Two-factor authentication

A user can add a time-based one-time password (TOTP) as a second factor. TOTP is
the six-digit code an authenticator app shows.

- Start setup: `POST /api/v1/auth/totp/setup` returns a secret and a QR code.
- Confirm and enable: `POST /api/v1/auth/totp/enable`.
- Disable: `POST /api/v1/auth/totp/disable`.
- Sign in with a code: `POST /api/v1/auth/login/totp` after the password step.

## Self-service registration

A visitor can create an account when registration is open. Registration is a
stored setting. An administrator turns it on or off at runtime without a new
deploy.

- Register: `POST /api/v1/auth/register`.
- Gate: the `registration.enabled` setting controls whether the endpoint accepts a
  new account.
- Result: a successful registration signs the user in and sets the cookie.

A registered account is never an administrator. The server creates an administrator
only through the terminal, with the `register` command. See
[Development](002-development/000-index.md).
