# Minecraft

Minecraft Java servers run on [itzg/minecraft-server](https://docker-minecraft-server.readthedocs.io) with [Paper](https://papermc.io) as the server software. Paper is a drop-in replacement for the vanilla server: players connect with the normal game client, it performs much better, and it runs server-side plugins.

Two compose files:

* [mc-router.yml](../compose/games/minecraft/mc-router.yml): one per host. Listens on `25565/tcp` and hands each connection to the right server based on the hostname the player typed.
* [minecraft.yml](../compose/games/minecraft/minecraft.yml): one per server, configured by an env file such as [.env.survival](../compose/games/minecraft/.env.survival).

## Why not Traefik

Traefik can only tell TCP connections apart by TLS SNI. Minecraft doesn't use TLS, so Traefik would need a separate port for every server. [mc-router](https://github.com/itzg/mc-router) reads the hostname from the Minecraft handshake, so every server can share `25565`. It finds servers through the Docker socket using the `mc-router.host` label, so no routing config is needed.

## Deploying

1. Forward `25565/tcp` on the router to the Docker host.
2. Create a DNS record for each server's FQDN pointing at the host. On Cloudflare, set it to **DNS only** (grey cloud). The Cloudflare proxy doesn't carry Minecraft traffic.
3. Deploy the router once:

   ```shell
   task deploy -- compose/games/minecraft/mc-router.yml
   ```

4. Copy `.env.survival` to `.env.<name>`, set a unique `MINECRAFT_INSTANCE` and `MINECRAFT_HOST`, then deploy:

   ```shell
   docker compose --env-file .env --env-file compose/games/minecraft/.env.<name> -f compose/games/minecraft/minecraft.yml up -d
   ```

Each instance becomes its own Compose project (`minecraft-<instance>`) and container (`minecraft-<instance>`). Its data goes to `${LOCAL_PREFIX}/minecraft-<instance>`. The first start downloads Paper and generates the world, which takes a few minutes. Follow it with `docker logs -f minecraft-<instance>`.

Players add the server in-game under *Multiplayer → Add Server* using the FQDN, with no port.

## Running server commands

RCON is on by default, and `rcon-cli` inside the container authenticates automatically:

```shell
docker exec minecraft-<instance> rcon-cli <command>
```

Run with no command for an interactive console. Any command an operator can type in chat works here, without the leading `/`.

## Allow list

The server only admits players on the allow list (Java edition calls it the *whitelist*), which is enforced by `ENABLE_WHITELIST` and `ENFORCE_WHITELIST`. `ONLINE_MODE` makes sure a username belongs to a real Mojang/Microsoft account.

Manage it live, with no restart:

```shell
docker exec minecraft-<instance> rcon-cli whitelist add <username>
docker exec minecraft-<instance> rcon-cli whitelist remove <username>
docker exec minecraft-<instance> rcon-cli whitelist list
```

Give your friend operator (admin) rights so they can manage it in-game with `/whitelist add <name>`:

```shell
docker exec minecraft-<instance> rcon-cli op <username>
```

`MINECRAFT_WHITELIST` and `MINECRAFT_OPS` in the env file are comma-separated usernames that get **added** on every start. Removing a name from the env file does not remove that player, so use `whitelist remove` / `deop` for that.

## Limits and abuse

With an allow list, the players are people you chose, so the main job is keeping the server stable.

Set in the env file (defaults in parentheses):

| Variable | Effect |
|---|---|
| `MINECRAFT_MAX_PLAYERS` (10) | Player cap |
| `MINECRAFT_VIEW_DISTANCE` (10) | Chunks sent to clients; the biggest factor in RAM and bandwidth use |
| `MINECRAFT_SIMULATION_DISTANCE` (8) | Chunks that actually tick (farms, mobs); the biggest factor in CPU use |
| `MINECRAFT_IDLE_TIMEOUT` (30) | Minutes before an AFK player is kicked; `0` disables |
| `MINECRAFT_SPAWN_PROTECTION` (16) | Radius around spawn that only ops can build in |
| `MINECRAFT_PVP` (false) | Player-vs-player damage |
| `MINECRAFT_MEMORY` (4G) | Java heap; 4G suits a handful of players, add more for modpacks |

**Chat spam:** vanilla already kicks non-ops who send chat or commands too fast, and there's no setting for that. Paper adds limits for other packet spam in `config/paper-global.yml` under `spam-limiter` (tab-complete and recipe-book spam) and `packet-limiter`. The defaults are sensible.

**Other `server.properties` keys:** edit `${LOCAL_PREFIX}/minecraft-<instance>/server.properties` and restart. Keys backed by an env var above are rewritten from the env on every start, so change those in the env file instead.

**Moderation:** `kick`, `ban`, `ban-ip`, `pardon`, and `whitelist` are built in. For mutes and temp-bans, add [EssentialsX](https://modrinth.com/plugin/essentialsx). [CoreProtect](https://modrinth.com/plugin/coreprotect) logs every block change so you can roll back griefing, which makes it worth having even among friends.

## Plugins and mods

These are different things:

* **Plugins** (Paper, this setup) run only on the server. Players keep the normal client. Good for admin tools, protection, economy, minigames, and quality-of-life features.
* **Mods** (Fabric or NeoForge) can add new blocks, mobs, and dimensions. Every player has to install the same mods, usually as a modpack through a launcher like Prism or the CurseForge app. Choose this before generating the world. Changing `TYPE` on an existing world can break it.

**Adding Paper plugins:** find a plugin on [Modrinth](https://modrinth.com/plugins) and put its slug (the last part of the URL) in `MINECRAFT_MODRINTH_PROJECTS`, comma-separated. Redeploy, and the image downloads versions that match the server's Minecraft version. You can also drop `.jar` files into `${LOCAL_PREFIX}/minecraft-<instance>/plugins/` and restart. Plugin configs go in `plugins/<PluginName>/` after the first start.

The example env file installs:

* `luckperms`: permissions, so you can give players specific abilities without full op.
* `coreprotect`: block logging and rollback.

**Running a modpack instead:** set `MINECRAFT_TYPE=MODRINTH` in the env file and add `MODRINTH_MODPACK: "<slug>"` to the service environment. Pure Fabric mods work through `MINECRAFT_TYPE=FABRIC` plus `MINECRAFT_MODRINTH_PROJECTS`. CurseForge packs need a CurseForge API key; see the [itzg docs](https://docker-minecraft-server.readthedocs.io/en/latest/types-and-platforms/mod-platforms/auto-curseforge/).

**Bedrock players** (consoles, phones) can't join a Java server directly. The [Geyser](https://geysermc.org) plugin adds support, but it listens on its own UDP port (`19132`), which mc-router can't route. Each Bedrock-enabled server would need its own published port.

## Versions and upgrades

`VERSION=LATEST` follows new Minecraft releases on the next restart. Plugins often lag behind major releases, and worlds can't be downgraded. Once the server is settled, pin `MINECRAFT_VERSION` to the version shown in the startup log in the env file and bump it deliberately.

## Backups

The world lives on local disk, so `task backup:local` picks it up. It copies files while the server is running, so a backup can catch a chunk mid-write. For a consistent copy, pause saving around it:

```shell
docker exec minecraft-<instance> rcon-cli save-off
docker exec minecraft-<instance> rcon-cli save-all flush
task backup:local
docker exec minecraft-<instance> rcon-cli save-on
```
