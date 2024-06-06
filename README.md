# docker-bricksandblocks

Docker deployment files for bricksandblocks.net

# Requirements

* [git](http://git-scm.com)
* [Task](https://taskfile.dev)

# Configuration

* Make a copy of `env.dist` called `.env`
* Fill in appropriate values for `.env`
* Run update and setup tasks

```
task update
task setup
```

# Usage

## Deploy All

To deploy all manifests run:

```
task deploy
```

# Contribution

Pull requests welcome.
