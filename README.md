# docker-bricksandblocks

Docker deployment files for bricksandblocks.net

# Requirements

* [Docker](https://docker.io)
* [git](https://git-scm.com)
* [Task](https://taskfile.dev)
* [yq](https://github.com/mikefarah/yq)

# Configuration

* Make a copy of `env.dist` called `.env`
* Fill in appropriate values for `.env`
* Run update and setup tasks

```
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
