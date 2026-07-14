# Wizarr

[Wizarr](https://docs.wizarr.dev) is a user invitation and management front-end for media servers (Jellyfin, Plex, Emby). It is deployed via the [compose](../compose/operations/wizarr.yml) file and served on port `5690`.

## Notifiarr Notifications

Wizarr ships a native `Notifiarr` notification agent (Settings → Notifications). It POSTs a Notifiarr [Passthrough](https://notifiarr.wiki/pages/integrations/passthrough/) payload to the passthrough webhook; Notifiarr's Discord bot then renders it as an embed in the target channel. Flow is `Wizarr → Notifiarr Passthrough → Discord bot → channel`.

Prerequisites on the Notifiarr side:

* The **Notifiarr Discord bot** must be in the server with permission to post in the target channel.
* The **Passthrough** integration must be enabled; copy its API key from *Basic Instructions*. The webhook URL is `https://notifiarr.com/api/v1/notification/passthrough/<API_KEY>`.
* The numeric Discord **Channel ID** (enable Developer Mode in Discord, then right-click the channel → Copy Channel ID).

Create the agent in Wizarr with:

* **Notification Service**: `Notifiarr`
* **Channel ID**: the numeric Discord channel ID
* **Agent URL**: the full passthrough webhook URL above (the placeholder is generic; it expects the passthrough URL, not a bare API key)
* **Notification Events**: Wizarr only emits `user_joined` (invite redeemed) and `update_available` (new Wizarr release)

Saving triggers a test send; a "Wizarr test message" embed should land in the channel. If nothing arrives, check bot presence/permissions, the channel ID, and that the Passthrough integration is enabled.

> **Note:** the embed is fixed on the Wizarr side (white color, no pings, title + description only) and Passthrough is not templatable. For role pings or multi-channel fan-out, use the `Apprise` agent instead with `notifiarr://<GLOBAL_API_KEY>/<CHANNEL_ID>` — note Apprise requires the *global* Notifiarr API key, not the integration key.

## Persistence

The notification agent is stored in Wizarr's SQLite database (the `notification` table under `/data/database`), not in any Compose, Ansible, or Terraform config — Wizarr has no declarative seeding path for agents. Record the passthrough API key in the usual secret store for reference and treat the agent as UI-managed runtime state. To reconstruct after a rebuild: service `Notifiarr`, the passthrough URL, and the channel ID above.

> **Note:** the [compose](../compose/operations/wizarr.yml) file currently mounts `/data/database` on NFS. Wizarr is SQLite-backed, which runs against the local-bind-mount guidance in [Backups.md](./Backups.md). Consider moving `wizarr-data` to a `LOCAL_PREFIX` bind mount with periodic `task backup:local`, or at minimum ensure the NFS path is backed up so the agent (and all Wizarr state) survives a rebuild.
