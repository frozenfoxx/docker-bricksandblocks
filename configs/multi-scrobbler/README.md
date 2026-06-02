# multi-scrobbler config

Templates for [multi-scrobbler](https://docs.multi-scrobbler.app/) running on the
`docker-4` host (see `compose/media/multi-scrobbler.yml`).

This setup sources plays from **Plex** and scrobbles them to **ListenBrainz**.
A source scrobbles to all configured clients by default, so the Plex source
flows to ListenBrainz with no extra wiring.

> Navidrome already scrobbles its own plays to ListenBrainz natively. Plex is a
> separate player, so there is no overlap and no duplicate scrobbles.

## Deploying

These files are templates with placeholder credentials. The live config lives on
the NFS share that backs the container's `/config` volume, **not** in this repo:

    <DATA_HOST>:/volume1/Docker/multi-scrobbler/config

For each template:

1. Copy it onto the share, dropping the `.example` suffix
   (`plex.json.example` -> `plex.json`).
2. Fill in the real values (Plex token/URL, ListenBrainz user token).
3. Restart the container: `docker restart multi-scrobbler`.

| File                | Purpose            |
| ------------------- | ------------------ |
| `plex.json`         | Plex source        |
| `listenbrainz.json` | ListenBrainz client |

ListenBrainz only needs a user token (Settings -> get your token); there is no
OAuth callback step.
