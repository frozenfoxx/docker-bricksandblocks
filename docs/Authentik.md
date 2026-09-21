# Authentik

[Authentik](https://goauthentik.io) is the identity provider for bricksandblocks.net, serving SSO to internal services via OAuth2/OIDC, SAML, and proxy providers. It is deployed via the [compose](../compose/operations/authentik.yml) file on `docker-1`, published on ports `9000` (HTTP) and `9443` (HTTPS), and served publicly at `https://authentik.bricksandblocks.net` through the external Traefik.

The stack is three containers: `authentik` (server), `authentik-worker` (background tasks, email, blueprints, outpost management), and `authentik-postgres`. Since 2025.10 there is no Redis — sessions, cache, and the task queue all live in Postgres.

Configuration comes from two places. Version pins live in `compose/operations/.env.authentik`; everything else comes from the `authentik-bricksandblocks` secret in AWS Secrets Manager via `task setup:secrets`:

* `AUTHENTIK_SECRET_KEY` — signs sessions and tokens
* `AUTHENTIK_PG_USER`, `AUTHENTIK_PG_PASSWORD`
* `AUTHENTIK_EMAIL_HOST`, `AUTHENTIK_EMAIL_PORT`, `AUTHENTIK_EMAIL_USER`, `AUTHENTIK_EMAIL_PASSWORD`, `AUTHENTIK_EMAIL`
* `AUTHENTIK_WEB_BASE_URL` — public URL, mandatory from 2026.11
* `AUTHENTIK_TRUSTED_PROXY_CIDRS` — proxies permitted to set `X-Forwarded-*` headers

> **Note:** the compose default for `AUTHENTIK_TRUSTED_PROXY_CIDRS` is every private range (`172.16.0.0/12,10.0.0.0/8,192.168.0.0/16`) so a fresh deployment works out of the box. Narrow it to the actual Traefik source address via the secret — any host inside a trusted range can spoof its client IP, which poisons the audit log and defeats IP-based policies.

Email is sent by the worker, not the server, so both containers carry the `AUTHENTIK_EMAIL__*` variables.

File storage is the NFS volume `authentik-data`, mounted at `/data` on the server and the worker, with uploads written to `/data/media`. `AUTHENTIK_STORAGE__FILE__PATH` defaults to `/data`; a volume mounted directly at `/data/media` is treated as legacy storage, readable but not writable.

User-facing flows are assigned on the brand (Brands → the `bricksandblocks.net` brand): authentication, invalidation, recovery, and user settings. The enrollment flow is deliberately left unset so no sign-up link appears; enrollment happens by invitation link only.

## Procedures

### Deploying

```shell
task setup:secrets
task deploy:host HOSTNAME=docker-1
docker logs --follow authentik
```

### Creating a user

Normal path is an invitation — see below. Directory → Users → Create makes an account directly, for service accounts or when no mailbox exists yet; such an account has no MFA device and is pushed into TOTP setup at first login.

Assign groups at creation. Application access is granted by binding a group to an application, not per user.

### Resetting a user

Directory → Users → the user → Update password sets one directly. Preferred instead: Email recovery link, which sends a self-service reset and requires working SMTP.

To force a reset at next login, set the user's `Password change date` to the past or attach a password-change stage to the authentication flow.

### Recovering admin access

With shell access on `docker-1`, a recovery link can be minted for any user without going through a login:

```shell
docker compose -f compose/docker-1.yml run --rm authentik create_recovery_key 10 <username>
```

This is the break-glass path. The default `akadmin` account has been deleted; admin access depends on accounts in the `authentik Admins` group plus this command.

> **Note:** keep at least two admin accounts with enrolled MFA devices, or one admin plus verified shell access to `docker-1`.

### Rotating the secret key

```shell
openssl rand -base64 60 | tr -d '\n'
```

Update `AUTHENTIK_SECRET_KEY` in the `authentik-bricksandblocks` secret, then `task setup:secrets` and redeploy. All sessions are invalidated and every user must log in again. Nothing stored becomes unreadable — the key signs, it does not encrypt at rest.

### Inviting a user

Enrollment is invitation-only: `default-enrollment-flow` begins with the `enrollment-invitation` stage, which has "Continue flow without invitation" off, and the brand has no enrollment flow set.

Directory → Invitations → Create, with flow `default-enrollment-flow`, single use, and an expiry. Copy the resulting link and send it:

```
https://authentik.bricksandblocks.net/if/flow/default-enrollment-flow/?itoken=<token>
```

The invited user sets username and password, verifies their email, enrols TOTP, and is shown recovery codes once before being logged in. Add them to the groups their applications are bound to — an account in no group reaches no application.

### Adding an application

1. Applications → Providers → Create → OAuth2/OpenID Provider: confidential client, redirect URI in `Strict` mode, default scopes.
2. Applications → Applications → Create with a slug matching the discovery URL the application will use, and select the provider.
3. Set the application's policy engine mode to `ALL`.
4. Bind **one** group for access (Policy / Group / User Bindings → Group tab), order `0`, failure `Don't Pass`. Groups appear on the Group tab of that dialog, not in the policy picker.

The discovery URL is `https://authentik.bricksandblocks.net/application/o/<slug>/.well-known/openid-configuration`, and returns 404 if the slug is wrong or no application references the provider.

> **Note:** with policy engine mode `ALL`, every binding must pass, so two group bindings mean the user must be in both. Grant access with a single group and use additional groups only for role mapping inside the application (as Grafana does with `grafana-admins` and `grafana-editors`). Multiple groups for access need mode `ANY` instead.

Applications also need a **Launch URL** to appear in the user library; `blank://blank` hides them deliberately. Access and visibility are separate — "Check Access" can pass while the tile is missing.

### Per-application notes

Grafana (`grafana`): OAuth config lives in Grafana's database via Administration → Authentication → Generic OAuth, not in [compose](../compose/synology/grafana-compose.yaml); the compose file only sets `GF_SERVER_ROOT_URL`. Access is granted by `grafana-users`; `grafana-admins` and `grafana-editors` drive `role_attribute_path`. Grafana links OAuth identities to local users by login, and a conflicting local account fails the login with "user sync failed" — delete the local account before its first SSO login, or set `GF_AUTH_OAUTH_ALLOW_INSECURE_EMAIL_LOOKUP`.

Gitea (`gitea`): the auth source is created in Site Administration → Identity & Access → Authentication Sources, named `authentik` so the callback matches `https://gitea.bricksandblocks.net/user/oauth2/authentik/callback`. Additional Scopes must be `email profile`. Account linking is set in app.ini on the NFS volume, not by env var:

```ini
[oauth2_client]
ENABLE_AUTO_REGISTRATION = true
ACCOUNT_LINKING = auto
USERNAME = preferred_username
```

Enable **Skip Local 2FA** on the source so authentik's MFA is not duplicated by Gitea's own TOTP. To retire local logins entirely, set `ENABLE_PASSWORD_SIGNIN_FORM = false` under `[service]`.

> **Note:** `GITEA__section__KEY` environment variables are written into app.ini at every container start, overwriting hand-edited values for those keys. The `[database]` section is generated this way; `[oauth2_client]` and `[service]` are hand-edited.

BookOrbit (`bookorbit`): OIDC is configured in BookOrbit's own admin UI under Settings → OIDC / SSO and stored in its database; no environment variables carry the client ID or secret. Record the client secret in the password manager, since a database rebuild loses it.

### Requiring MFA

MFA is enforced globally by `default-authentication-mfa-validation`, bound into `default-authentication-flow`:

* Device classes: TOTP, WebAuthn, Static — any one satisfies login
* Not configured action: `Configure`, with `default-authenticator-totp-setup` as the configuration stage

A user with no device is pushed into TOTP setup at next login. Passkeys and additional devices are optional and self-service from `/if/user/` → Settings → MFA Devices, which lists a device type only if its setup stage has a Configuration flow assigned.

### Upgrading

Authentik forbids skipping major versions. Upgrade to the latest patch of each `major.minor` in sequence; the server refuses to start and logs `RuntimeError: Major version skips are not allowed` otherwise.

Per hop:

1. Snapshot `/volume1/Docker/authentik/postgres` on `nas-1`.
2. Bump `AUTHENTIK_TAG` in `compose/operations/.env.authentik`.
3. `task deploy:host HOSTNAME=docker-1`
4. Watch `docker logs --follow authentik` until migrations finish.
5. Log in, then confirm the worker is processing tasks under System → Tasks.

Check each release's notes for compose changes before the hop. Past examples: 2025.10 removed Redis (service, volume, `AUTHENTIK_REDIS__HOST`, `depends_on`; deploy with `--remove-orphans`), 2025.12 moved file storage to `/data` (media under `/data/media`) and enforced unique group names, 2026.8 added trusted-proxy enforcement and `AUTHENTIK_WEB__BASE_URL`.

Outposts must run the same version as the server; upgrade them in the same window.

### Backing up and restoring

The database is the entire state. Snapshot the NFS directory `/volume1/Docker/authentik/postgres` on `nas-1`, or dump it:

```shell
docker exec authentik-postgres pg_dump -U authentik authentik > authentik-$(date +%F).sql
```

Restore by stopping the stack, replacing the data directory from snapshot, and redeploying the tag that produced it — an older image cannot run a newer schema.

## Troubleshooting

### Failed upgrade

Check `docker logs authentik` for the migration error. Migrations run in the server container on start.

`RuntimeError: Major version skips are not allowed` means the tag jumped too far; set the tag back and step through each `major.minor` in turn. No migration has run at that point, so the database is untouched.

`InconsistentMigrationHistory` or a mid-migration failure means restoring the snapshot and retrying the hop. A partially migrated database cannot be run by either version.

Duplicate group names fail the 2025.12 migration. Check before the hop:

```shell
docker exec -it authentik-postgres psql -U authentik -d authentik \
  -c "SELECT name, count(*) FROM authentik_core_group GROUP BY name HAVING count(*) > 1;"
```

### Server or worker exits immediately

Recent versions run a Rust supervisor around the Python process. `the server has exited unexpectedly` or `one or more workers have exited unexpectedly` is the supervisor reporting a dead child — the real error is earlier in the log:

```shell
docker logs authentik 2>&1 | head -100
```

If the log holds nothing but the supervisor message, run it in the foreground so the traceback is visible:

```shell
docker compose -f compose/docker-1.yml run --rm authentik server
```

Both containers dying identically points to something shared: config, database, or version. Only one dying points to that container's own configuration.

### Email not sending

Email is sent by the worker. Confirm both containers actually received the settings:

```shell
docker compose -f compose/docker-1.yml config | grep -A12 AUTHENTIK_EMAIL__HOST
```

Empty values mean the secret is missing keys or `task setup:secrets` has not run. The variables interpolated by the compose file are single-underscore (`AUTHENTIK_EMAIL_HOST`); the container variables are double-underscore (`AUTHENTIK_EMAIL__HOST`). Test from Admin → System → Settings, and check `docker logs authentik-worker` for the send result.

Port `587` needs `AUTHENTIK_EMAIL_USE_TLS=true` and `AUTHENTIK_EMAIL_USE_SSL=false`; port `465` needs the reverse.

### Login redirects to http or mixed content is blocked

From 2026.8, Authentik only honours `X-Forwarded-*` headers from addresses in `AUTHENTIK_TRUSTED_PROXY_CIDRS`. If Traefik's source address is outside that list, HTTPS requests are treated as HTTP. With ports published on the host, the source is a Docker bridge address on `docker-1`, not Traefik's LAN address — check the peer address in the server log and set the value accordingly.

### Worker not processing tasks

Check System → Tasks in the admin interface and `docker logs authentik-worker`. Workers that fail to fork after a database restart or version change are a known issue; the documented remedy is Postgres maintenance followed by a restart:

```shell
docker exec -it authentik-postgres psql -U authentik -d authentik -c "VACUUM ANALYZE;"
docker exec -it authentik-postgres psql -U authentik -d authentik -c "REINDEX DATABASE authentik;"
docker restart authentik-worker
```

### Icon upload fails with no file backend configured

The storage volume is mounted at the wrong path. `authentik-data` must mount at `/data`, not `/data/media`, on both the server and the worker; media is then written to `/data/media` inside it. Confirm the directory is writable by the container user:

```shell
docker exec authentik ls -la /data
```

The `media` directory should be owned by `1028`. On `nas-1` the backing path is `/volume1/Docker/authentik/data`, which needs `chown -R 1028:50` plus the usual `synoacltool` grants.

### Application reports a missing email or username claim

The application received only the `openid` scope. Both ends must agree:

* authentik — Applications → Providers → the provider → the selected scope mappings must include `email` and `profile`; `groups` is carried inside `profile`
* the application — it must actually request them. Grafana ships GitHub-style defaults (`user:email`) that must be replaced with `openid email profile`; Gitea sends only what is listed in the auth source's **Additional Scopes** field (`email profile`)

Symptoms differ by application: Grafana probes `<api_url>/emails` and reports a 404 from authentik's error page, Gitea reports `missing fields: email,preferred_username`.

### An application is missing from a user's library

Access and visibility are separate. Run **Check Access** on the application for that user first.

If access is granted but the tile is missing: confirm the application has a Launch URL, then re-save the application — the per-user library list is cached, and a stale entry survives logout. `docker restart authentik` clears it if re-saving does not.

If access is denied: check group membership, and check for a second binding while the policy engine mode is `ALL`.

### SECRET_KEY security warning

`(security.W009) Your SECRET_KEY has less than 50 characters` means the key is too short or too low in entropy. Rotate it per the procedure above.
