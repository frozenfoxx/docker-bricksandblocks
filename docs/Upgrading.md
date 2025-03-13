# Upgrading

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