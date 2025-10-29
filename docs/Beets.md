# Usage

[beets](https://beets.io) is a music catalog organizer. While the container runs continually, import must be done via the command-line. Assuming the [compose](../compose/media/beets.yml) file has been used you can use the following to begin organizing:

```shell
docker exec -it beets /bin/bash
beet import '/music/'
```