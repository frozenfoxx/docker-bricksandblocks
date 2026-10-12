# Nightscout

[Nightscout](https://nightscout.github.io) (cgm-remote-monitor) is a remote CGM monitor. [Trio](https://github.com/nightscout/Trio) uploads glucose readings, loop status, predictions and treatments to it, and caregivers follow along in a browser or a follower app.

[nightscout.yml](../compose/tools/nightscout.yml) runs two containers:

* `nightscout`: the web app and API, published on `14337` as plain HTTP for Traefik.
* `nightscout-mongo`: MongoDB 5.0, the series upstream's compose uses. Its data lives on a local bind mount (`${LOCAL_PREFIX}/nightscout-mongo`) and is backed up as dumps, see [Backups](#backups).

## What depends on it

Trio loops on the phone with the CGM and pump directly, so a Nightscout outage stops remote following and remote treatments, not looping. That only holds while Trio's CGM source is the CGM itself. If Trio is set to use Nightscout as its CGM, Nightscout being down means Trio has no glucose data.

## Deploying

1. Set `NIGHTSCOUT_API_SECRET` in `.env`. It must be at least 12 characters, and it gets typed into Trio on the phone, so a long passphrase is easier than random hex.
2. Check the host's CPU supports AVX, which MongoDB 5.0 requires. If `grep -c avx /proc/cpuinfo` prints `0`, Mongo won't start on that host.
3. Deploy:

   ```shell
   task deploy -- compose/tools/nightscout.yml
   ```

4. Copy [configs/traefik/nightscout.yml](../configs/traefik/nightscout.yml) into the Traefik dynamic config share (`/volume1/Docker/traefik/conf`). Replace the backend host in it if Nightscout isn't on `docker-2`. The `*.bricksandblocks.net` wildcard certificate already covers `nightscout.bricksandblocks.net`.
5. Open `https://nightscout.bricksandblocks.net` and sign in with the API secret.

### Access

`AUTH_DEFAULT_ROLES` is `denied`, so nothing is visible without signing in. Don't hand out the API secret to followers, since it grants full write access. Instead create a subject under *Admin Tools → Subjects* with the `readable` role and share its access token. Follower apps such as LoopFollow or Nightguard take the URL with `?token=<token>`, or the token in their settings.

## Connecting Trio

In Trio, under *Settings → Services → Nightscout*:

1. Enter the URL, including `https://`: `https://nightscout.bricksandblocks.net`.
2. Enter the API secret.
3. Turn on *Allow uploads*, then use *Test connection*.

Readings, loop status and predictions should appear on the Nightscout page within one loop cycle (about five minutes). The `openaps` plugin draws Trio's prediction lines, and the pills at the top show IOB, COB, pump reservoir and battery, and site/sensor ages.

The plugin list, units and access role can be changed in `.env` with `NIGHTSCOUT_ENABLE`, `NIGHTSCOUT_DISPLAY_UNITS` (`mg/dl` or `mmol`) and `NIGHTSCOUT_AUTH_DEFAULT_ROLES`.

## Backups

Mongo has to stay on local disk, and copying a running Mongo data directory doesn't produce a consistent backup. [backup_nightscout.sh](../scripts/backup_nightscout.sh) runs `mongodump` in the container and writes a compressed archive to the data host:

```shell
task backup:nightscout
```

* Archives go to `${DATA_PREFIX}/nightscout/backups/nightscout-<timestamp>.archive.gz`.
* A dump is written under a temporary name and only renamed once it succeeds, so a failed run never leaves a file that looks like a good backup.
* Archives older than 30 days are removed. Change that with `NIGHTSCOUT_BACKUP_RETENTION_DAYS`.

Schedule it with cron on the host running Nightscout. Every six hours is cheap, since a dump is small and takes seconds:

```shell
0 */6 * * * cd /path/to/docker-bricksandblocks && task backup:nightscout >> /var/log/backup_nightscout.log 2>&1
```

`task backup:local` also rsyncs `${LOCAL_PREFIX}/nightscout-mongo` to the data host along with everything else. Don't restore from that copy: it was taken while Mongo was writing, so it may be inconsistent. Use the dumps.

### Restoring

Stop Nightscout so nothing writes during the restore, restore the archive (`--drop` replaces the existing collections), then start it again:

```shell
docker stop nightscout
docker exec -i nightscout-mongo mongorestore --archive --gzip --drop < ${DATA_PREFIX}/nightscout/backups/nightscout-<timestamp>.archive.gz
docker start nightscout
```

Practise this once after the first backup so the procedure is known before it's needed. Readings Trio uploads while Nightscout is stopped may not be backfilled, so keep the restore window short.

## Upgrades

Nightscout follows `:latest`, and diun reports new releases. Mongo tracks `5.0`, which only picks up 5.0.x patch releases; those keep the same data files and are safe to pull. Moving to a newer major version means a dump, a fresh data directory on the new version, and a restore, rather than swapping the image tag.
