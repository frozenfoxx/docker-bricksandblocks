# Docker Hangs When Shutting Down Containers

This might be related to the logging driver. If so, you may have to go digging with `ps` to find the process to kill, `systemctl restart docker.socket docker.service` to get Docker reinitialized, and possibly adjust the logging driver entirely.