# Upgrading

## DIUN
Docker Image Update Notifier ([DIUN](https://crazymax.dev/diun)) is a tool to watch and notify upon discovering updates available to containers on a host. It does not automatically upgrade but does have a slew of options for notification. This can work better when you have containers that are prone to failure to be restarted properly or just like to make sure you have complete control over the process.

## Watchtower
We can use tools like [watchtower](https://containrrr.dev/watchtower/) to automatically upgrade containers on a host. As long as the watchtower container is running it will seamlessly upgrade and clean up after containers as upgrades become available. To do so, simply run watchtower with the `` mode set to enabled and add the appropriate label to every container you wish to monitor for upgrades.

- __watchtower__
```yaml
[...]
environment:
  WATCHTOWER_LABEL_ENABLE: true
[...]
```

- __service to monitor__
```yaml
labels:
  - "com.centurylinklabs.watchtower.enable=true"
```