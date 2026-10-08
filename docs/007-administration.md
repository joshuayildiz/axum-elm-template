# Administration

This page covers the admin console: access control, user management, role
management, and settings.

## Authorization

Role-based access control (RBAC) controls access. RBAC grants a user a permission
directly, or through a role the user holds.

- Permissions: a fixed catalog in code, for example `users.read` and
  `settings.update`.
- Roles: named groups of permissions that an administrator creates and edits.
- Direct grants: a permission for one user, on top of the roles the user holds.
- Admin: an administrator holds every permission.

The client shows the permission catalog as a tree. A parent node toggles all the
leaf permissions under it. The client locks a permission that comes from a role,
because you change it on the role.

## User management

An administrator manages the user list from the client.

- List: `GET /api/v1/users` with pagination and search.
- Create: `POST /api/v1/users`.
- Delete: `DELETE /api/v1/users/{id}` marks the row deleted but keeps it, so other
  records keep their links.
- Roles: assign and remove the roles of a user.
- Permissions: grant and revoke the direct permissions of a user.

The create form never sets the administrator flag. The server always creates a
non-administrator through this endpoint.

## Role management

An administrator manages roles from the client. The administrator lists, creates,
updates, and deletes roles, and edits the permissions a role grants through the
same permission tree.

## Settings

Settings follow a scaled-down version of the ABP Framework model. The server
defines each setting once in code with a name, a default, and a kind. A database
row, when present, overrides the code default.

- Access: the `settings.read` and `settings.update` permissions guard `GET` and
  `PUT /api/v1/settings`.
- Kinds: a setting is a boolean or a text value.
- Built-in settings: `registration.enabled` and `company.name`.
- New setting: one registry entry in code, with no migration.
