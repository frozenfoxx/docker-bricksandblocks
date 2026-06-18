# docker-bricksandblocks

Docker deployment files for bricksandblocks.net

# Requirements

* [Docker](https://docker.io)
* [git](https://git-scm.com)
* [Loki Docker Driver](https://grafana.com/docs/loki/latest/send-data/docker-driver/)
* [Task](https://taskfile.dev)
* [yq](https://github.com/mikefarah/yq)

## Loki Docker Driver
 
All services ship logs to Loki via the Loki Docker logging driver plugin. This must be installed on each host before deploying any services:
 
```shell
docker plugin install grafana/loki-docker-driver:latest --alias loki --grant-all-permissions
```
 
> **Note for Synology DSM hosts:** the plugin must be installed over SSH as root. It survives container restarts but may need to be reinstalled after a DSM major version upgrade.

## tun Kernel Module
 
VPN-routed services — the `gluetun`-backed `qbittorrent_aio` stack — bind `/dev/net/tun`, which requires the host `tun` kernel module. Load it and persist it across reboots before deploying those services:
 
```shell
mkdir -p /etc/modules-load.d
echo tun > /etc/modules-load.d/tun.conf
modprobe tun
```
 
> **Note for Synology DSM hosts:** `systemd-modules-load.service` reads `/etc/modules-load.d/` at boot, but a DSM major version upgrade may clear the directory, so the file may need to be recreated afterward.

# Configuration

* Make a copy of `env.dist` called `.env`
* Fill in appropriate values for `.env`
* Run update and setup tasks

```shell
task update
task setup
```

# Usage

* **Backup local mounts to a data host**: `task backup:local`
* **Deploy a service**: `task deploy -- compose/[role].yml`
* **Deploy all services for a host**: `task deploy -- compose/[hostname].yml`
* **Destroy a service**: `task destroy -- compose/[role].yml`
* **Check a service's logs**: `docker logs --follow [role]`
* **Pull the latest containers for a service**: `task upgrade -- compose/[role].yml`
* **Update repository**: `task update`

# Contribution

Pull requests welcome.
