# Local Mounts

Some containers unfortunately do not do well with network mounting. For these, the container must have a local bind mount (default `LOCAL_PREFIX=/local`) which must then have periodic backups made. Most often this will be for performance reasons or becuase of certain database requirements (SQLite most notably). You can manually back up with rsync:

```shell
rsync -avP --delete /local/[container mount] ${DATA_PREFIX}/
```