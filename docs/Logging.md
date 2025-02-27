# Logging

In the Compose files you can hook logging mechanisms provided in [lib/logging](../lib/logging.yml) by leveraging [extends](https://docs.docker.com/compose/how-tos/multiple-compose-files/extends/). For instance, hooking the Loki logging system can be done by adding this to the `services:` section of a Compose file:

```yaml
extends:
  file: ${ROOT_DIR-..}/lib/logging.yml
  service: logging-loki
```

To engage one of the other logging drivers, simply call the appropriate service:
```yaml
extends:
  file: ${ROOT_DIR-..}/lib/logging.yml
  service: logging-json
```