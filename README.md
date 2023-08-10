# Redis Sentinel Docker

Repository for running Redis in Sentinel mode locally through Docker.

## Docker image

- Ubuntu 22.04 LTS.
- Redis is based on `redis-stack-server`.
- `RediSearch` and `RedisJSON` modules are activated.

Build: `docker build --no-cache --progress=plain -t redis-ubuntu .`. `--no-cache` forces rebuild. `--progress-plain` logs output as `stdout`.

## Redis Sentinel

- No replication is enabled.
- 1 master, 2 slaves, 3 Sentinels.
- Static IP addresses and not hostnames. Clients outside of Docker network can't use hostnames.
- Set unique ports to allow back channel communication.

**Run**: `docker compose up -d`

**View logs**: `docker logs <CONTAINER>`

**Execute command in container**: `docker exec -it <CONTAINER> <COMMAND>`

**Connect to container**: `docker exec -it <CONTAINER> bash`
