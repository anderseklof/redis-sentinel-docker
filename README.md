# Redis Sentinel Docker

Repository for running Redis with replication and high availability with Sentinel locally in Docker.

## Docker

- Ubuntu 22.04 LTS.
- Redis based on `redis-stack-server`.
- `RediSearch` and `RedisJSON` modules are loaded.

Docker commands:

- Build: `docker build --no-cache --progress=plain -t redis-ubuntu .`
  - `--no-cache` forces rebuild.
  - `--progress-plain` logs output to `stdout`.
- Run: `docker compose up -d`
- View logs: `docker logs <CONTAINER>`
- Connect to container: `docker exec -it <CONTAINER> bash`

## Redis

- Authentication setup:
  - User `default` with `nopass` is disabled.
  - An admin user (`admin`) with full permissions is created in all instances for administrative purposes.
  - Replication: All Redis instances communicate with each other with a user configured with `masteruser` and a password configured with `masterauth`. All Redis instances must have a user with the following permissions: `+psync +replconf +ping`.
  - HA with Sentinel: Communication to and from Sentinels have three scenarios:
    - Sentinel -> Redis: This communication is configured with `sentinel auth-user mymaster` and `sentinel auth-pass mymaster`. All Redis instances must have a user with the following permissions: `allchannels +multi +slaveof +ping +exec +subscribe +config|rewrite +role +publish +info +client|setname +client|kill +script|kill`.
    - Sentinel -> Sentinel: This communication is configured with `sentinel sentinel-user` and `sentinel sentinel-pass`. All Sentinel instances must have a user with full permissions: `allchannels +@all`.
    - Client -> Sentinel: This communication is used between the client and Sentinel. All Sentinel instance must have a user with the following permissions: `-@all +auth +client|getname +client|id +client|setname +command +hello +ping +role +sentinel|get-master-addr-by-name +sentinel|master +sentinel|myid +sentinel|replicas +sentinel|sentinels`
- Replication is enabled.
- 1 master, 2 slaves, 3 Sentinels.
- Static IP addresses and not hostnames. Clients outside of Docker network can't use hostnames.
- Set unique ports to allow back channel communication.
- Includes a network that is `attachable` so that it can be used from other containers. In the other containers add the following:
  - Add top-level `networks` to find `redisnet` network:
    ```yaml
    networks:
      redisnet:
        name: redisnet
    ```
  - Add service level `networks` to set the IP-address for the container:
    ```yaml
    networks:
      redisnet:
        ipv4_address: 192.168.55.30
    ```
- (Only available for Linux). To restore all configuration files to their original state, run `create-conf-files.sh` script in `script` folder.

## Failover

A failover will be triggered when the master instance is unreachable. The Sentinels will elect a new master from one of the remaining slaves. To test a failover scenario, do the following:

- Pause the master instance: `docker compose pause redis1`.
- Log in to one of the Sentinels (`docker exec -it sentinel1 bash`) to verify (`cat /var/log/redis`) that they have noticed that the master node is not responding and that the voting process has been completed. If all goes well the end of the log should indicate which Redis instances are slaves, which Redis instance is master and that the previous master (that is a slave now) is down `+sdown`.
  ```
  +slave slave 192.168.55.10:6379 192.168.55.10 6379 @ mymaster 192.168.55.12 6380
  +slave slave 192.168.55.12:6381 192.168.55.11 6381 @ mymaster 192.168.55.12 6380
  +sdown slave 192.168.55.10:6379 192.168.55.10 6379 @ mymaster 192.168.55.12 6380
  ```
- Log in to the Redis slave (192.168.55.11) and verify that there is a new master, that a sync has succeeded and that it could do a `config rewrite` with the new settings.
  ```
  Connection with master lost.
  Caching the disconnected master state.
  Connecting to MASTER 192.168.55.12:6381
  MASTER <-> REPLICA sync started
  REPLICAOF 192.168.55.12:6381 enabled (user request from 'id=18 addr=192.168.55.20:43906 laddr=192.168.55.11:6380 fd=11 name=sentinel-4d46d78e-cmd age=128 idle=0 flags=x db=0 sub=0 psub=0 multi=4 qbuf=342 qbuf-free=40612 argv-mem=4 obl=45 oll=0 omem=0 tot-mem=61468 events=r cmd=exec user=sentinel_to_redis redir=-1')
  CONFIG REWRITE executed with success.
  ```

To add the paused instance to the fleet again, do the following:

- Start the paused instance: `docker compose unpause redis1`.
- Log in to one of the Sentinels to verify that `redis1` has been found and is active `-sdown`.
  ```
  -sdown slave 192.168.55.10:6379 192.168.55.10 6379 @ mymaster 192.168.55.12 6380
  ```
- Log in to `redis1` and verify that it has found the master, that a sync has succeeded and that i could do a `config rewrite` with the new settings.
  ```
  Connecting to MASTER 192.168.55.12:6381
  MASTER <-> REPLICA sync started
  REPLICAOF 192.168.55.12:6381 enabled (user request from 'id=223 addr=192.168.55.21:44820 laddr=192.168.55.10:6379 fd=215 name=sentinel-1b62845d-cmd age=10 idle=0 flags=x db=0 sub=0 psub=0 multi=4 qbuf=201 qbuf-free=40753 argv-mem=4 obl=45 oll=0 omem=0 tot-mem=61468 events=r cmd=exec user=sentinel_to_redis redir=-1')
  CONFIG REWRITE executed with success.
  Non blocking connect for SYNC fired the event.
  Master replied to PING, replication can continue...
  Trying a partial resynchronization (request 1887c0a26ae433cd13fdb22946c0ccb697f3814e:669385).
  Full resync from master: 3219faeb8399b93e74cd548a38eca7af397605ef:122858
  Discarding previously cached master state.
  MASTER <-> REPLICA sync: receiving 26157 bytes from master to disk
  MASTER <-> REPLICA sync: Flushing old data
  MASTER <-> REPLICA sync: Loading DB in memory
  <search> Loading event starts
  Loading RDB produced by version 6.2.13
  RDB age 0 seconds
  RDB memory usage when created 2.50 Mb
  Done loading RDB, keys loaded: 114, keys expired: 0.
  <search> Skip background reindex scan, redis version contains loaded event.
  <search> Loading event ends
  MASTER <-> REPLICA sync: Finished with success
  ```

## Redis and Sentinel "good to know"

- Replication does not replicate ACL or configurations. Configurations must be applied to all Redis instances where needed.
- Persist configuration that has been updated at runtime:
  - Redis: You need to run `config rewrite`. `config rewrite` writes the updated configuration to the configuration file.
  - Sentinel: Sentinel automatically writes some of the configuration changes to disk. To be sure that all changes are persisted, run `sentinel flushconfig`.
- If you want to configure Sentinel at runtime, remember to connect to the Sentinel instance port and not the Redis instance port.
- Sentinel configuration has two flavours; standard configuration and global configuration. The standard configuration API at runtime uses `sentinel set` command and the global configuration API uses the `sentinel config set` command. Note that the syntax for setting the configuration in the configuration file is `sentinel <COMMAND> <PARAMETERS>` for both APIs.
- If you get connection error like `ECONNRESET` or `ECONNABORTED`, check that:
  - Username and passwords are correctly configured.
  - If you use ACL: verify that the users has been created with the right permissions.
  - Protected mode in destination instance is disabled; `protected-mode no`.
- Sentinel needs write permission to the folder where the configuration file resides to be able to write temporary files and update the configuration file. If these permissions are missing, one or many of the following errors are written to the Sentinel log file:
  - `Could not create tmp config file (Permission denied)`.
  - `WARNING: Sentinel was not able to save the new configuration on disk!!!: Permission denied`
  - `Sentinel config file /etc/redis/sentinel.conf is not writable: Permission denied. Exiting...`
- When using Docker and mounting local files in `volumes`, verify that you not reuse the same resources between Sentinel services. If two services try to access the same file, the following errors are written to the Sentinel log file:
  - `Could not rename tmp config file (Device or resource busy)`
  - `WARNING: Sentinel was not able to save the new configuration on disk!!!: Device or resource busy`
