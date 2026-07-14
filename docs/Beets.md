# Beets

[beets](https://beets.io) is a music catalog organizer.

## Paths

This is the [linuxserver.io](https://docs.linuxserver.io/images/docker-beets/) image, so its data directory is `/config`, not the beets default of `~/.config/beets`. This matters when clearing state or inspecting the library:

- Config: `/config/config.yaml`
- Library database: `/config/musiclibrary.blb`
- Import statefile: `/config/state.pickle`
- Music library mount: `/music` (import sources live here)

# Usage

While the container runs continually, import must be done via the command-line. Assuming the [compose](../compose/media/beets.yml) file has been used you can use the following to begin organizing:

```shell
docker exec -it beets /bin/bash
beet import '/music/'
```

Most operations below are shown as one-liners (`docker exec -it beets beet ...`) so they copy-paste directly, but you can also drop into a shell as above and run the `beet` commands bare.

## Import Flags

- `-A` / `--noautotag` — skip MusicBrainz auto-tagging
- `-I` / `--nowrite` — don't rewrite file tags
- `-C` / `--nocopy` — import in place, don't copy files
- `-m` / `--move` — move instead of copy
- `-t` / `--timid` — pause and ask before every decision
- `-L` / `--library` — reimport items already in the library; bypasses the statefile check, useful for targeting a single album
- `-v` — verbose; prints *why* beets skips a path instead of failing silently

## Interactive Import

To have beets look up a release and ask you to confirm each match rather than auto-accepting:

```shell
docker exec -it beets beet import -C -t '/music/Artist/Album'
```

> **Note:** `-A` and `-t` conflict. `--noautotag` skips the entire matching process, so there is nothing left for `--timid` to pause on — an import run with both will not prompt. For interactive tagging, use `-C -t` and leave `-A`/`-I` off so beets actually performs the MusicBrainz lookup.

At each interactive prompt:

- `s` — skip this album
- `u` — use the presented match as-is
- `m` — enter a MusicBrainz release ID or URL manually (use this to force a specific release)
- `e` — enter new search terms
- `b` — go back

## Removing and Re-adding an Album

`beet remove` only removes the entry from the library database; files on disk are untouched. Use `-d` only if you also want the files deleted.

```shell
# Confirm the target first
docker exec -it beets beet list album:"Album Name"

# Remove from the library (files kept)
docker exec -it beets beet remove album:"Album Name"

# Remove and delete files (destructive)
docker exec -it beets beet remove -d album:"Album Name"
```

Then re-import interactively:

```shell
docker exec -it beets beet import -C -t '/music/Artist/Album'
```

## Troubleshooting

### "No files imported" / "Skipping previously-imported path"

beets tracks every path it has already imported or skipped in the statefile and will not touch them again. Run a verbose import to confirm this is the cause:

```shell
docker exec -it beets beet -v import -C -t '/music/Artist/Album'
```

A line reading `Skipping previously-imported path` confirms it. Either target the single album with `-L` to bypass the statefile, or clear the statefile entirely:

```shell
# Bypass state for one path
docker exec -it beets beet import -L '/music/Artist/Album'

# Or reset state globally, then re-import
docker exec -it beets rm /config/state.pickle
docker exec -it beets beet import -C -t '/music/Artist/Album'
```

Remember the statefile is at `/config/state.pickle` for this image, not the beets default location.

### Ghost entries (library references a directory that no longer exists)

If beets lists an album whose files are gone from disk (e.g. after a rename), it is a stale database entry. Remove it from the library:

```shell
docker exec -it beets beet remove artist:"Artist" album:"Album"
```

To audit the whole library for entries whose files are missing:

```shell
docker exec -it beets beet list -f '$path' | while read f; do [ -e "$f" ] || echo "MISSING: $f"; done
```

> **Note:** there is no `beet check` command. The shell one-liner above is the reliable way to surface ghost entries.

### An album on disk is not picked up

Work through these in order:

```shell
# 1. Confirm the container can see the files and what formats they are
docker exec -it beets ls -la '/music/Artist/Album'

# 2. Confirm it isn't already in the library under another name
docker exec -it beets beet list artist:"Artist"

# 3. Verbose import to see the actual reason for the skip
docker exec -it beets beet -v import -C -t '/music/Artist/Album'
```

beets silently skips formats it doesn't recognize, so an unexpected extension is a common cause. If the verbose output shows a previously-imported skip, clear the statefile as above.
