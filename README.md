# Redis Sentinel Docker

Repository for running Redis with replication and high availability with Sentinel locally in Docker.

## Docker

- Ubuntu 22.04 LTS.
- Redis 7.2.0 based on `redis-stack-server`.
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
  - HA with Sentinel: Communication to and from Sentinel has three main flows:
    - Sentinel -> Redis (user: `sentinelredis`): This communication is configured with `sentinel auth-user mymaster` and `sentinel auth-pass mymaster`. All Redis instances must have a user with the following permissions: `allchannels +multi +slaveof +ping +exec +subscribe +config|rewrite +role +publish +info +client|setname +client|kill +script|kill`.
    - Sentinel -> Sentinel (user: `sentinelsentinel`): This communication is configured with `sentinel sentinel-user` and `sentinel sentinel-pass`. All Sentinel instances must have a user with full permissions: `allchannels +@all`.
    - Client -> Sentinel (user: `clientsentinel`): This communication is used between the client and Sentinel. All Sentinel instance must have a user with the following permissions: `+auth +client|getname +client|id +client|setname +command +hello +ping +role +sentinel|get-master-addr-by-name +sentinel|master +sentinel|myid +sentinel|replicas +sentinel|sentinels`
- Replication is enabled.
- 1 master, 2 slaves, 3 Sentinels.
- Static IP addresses and not hostnames.
- Includes a network that is `attachable` so that it can be used from other containers. In the other container add the following:
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
- (Only available for Linux). To restore all configuration files to their original state, run `./script/create-conf-files.sh`.

## Failover

A failover will be triggered when the master instance is unreachable. The Sentinels will elect a new master from one of the remaining slaves. To test a failover scenario, do the following:

- Pause the master instance: `docker compose pause redis1`.
- Log in to one of the Sentinels (`docker exec -it sentinel1 bash`) to verify (`cat /var/log/redis`) that they have noticed that the master node is not responding and that the voting process has been completed. If all has goes well, the end of the log should indicate which Redis instances are slaves, which Redis instance is master and that the previous master (that is marked as a slave from now on) is down `+sdown`.
  ```
  +slave slave 192.168.55.12:6381 192.168.55.12 6381 @ mymaster 192.168.55.11 6380
  +slave slave 192.168.55.10:6379 192.168.55.10 6379 @ mymaster 192.168.55.11 6380
  +sdown slave 192.168.55.10:6379 192.168.55.10 6379 @ mymaster 192.168.55.11 6380
  ```
- We can now see that `redis2` is the new master.
- Log in to the Redis slave (`redis3`) and verify that there is a new master (`redis2`), that a sync has succeeded and that it could do a `config rewrite` with the new settings.
  ```
  Connection with master lost.
  Caching the disconnected master state.
  Connecting to MASTER 192.168.55.11:6380
  MASTER <-> REPLICA sync started
  REPLICAOF 192.168.55.11:6380 enabled (user request from 'id=13 addr=192.168.55.21:34886 laddr=192.168.55.12:6381 fd=10 name=sentinel-8f19c846-cmd age=89 idle=0 flags=x db=0 sub=0 psub=0 ssub=0 multi=4 qbuf=342 qbuf-free=20132 argv-mem=4 multi-mem=181 rbs=4096 rbp=4096 obl=45 oll=0 omem=0 tot-mem=25777 events=r cmd=exec user=sentinelredis redir=-1 resp=2 lib-name= lib-ver=')
  CONFIG REWRITE executed with success.
  Non blocking connect for SYNC fired the event.
  Master replied to PING, replication can continue...
  Trying a partial resynchronization (request c8c72055a21c7eae11da4843cbca9e8d5f6b5d3a:11961).
  Successful partial resynchronization with master.
  Master replication ID changed to d20cba53884aa6b72d1836001be05c46e0b9e8d6
  MASTER <-> REPLICA sync: Master accepted a Partial Resynchronization.
  ```

To add the paused instance to the fleet again, do the following:

- Start the paused instance: `docker compose unpause redis1`.
- Log in to one of the Sentinels to verify that `redis1` has been found and is active (`-sdown`) again.
  ```
  -sdown slave 192.168.55.10:6379 192.168.55.10 6379 @ mymaster 192.168.55.11 6380
  ```
- Log in to `redis1` and verify that it has found the master, that a sync has succeeded, that it could do a `config rewrite` with the new settings and that the AOF process succeeded.
  ```
  Connecting to MASTER 192.168.55.11:6380
  MASTER <-> REPLICA sync started
  REPLICAOF 192.168.55.11:6380 enabled (user request from 'id=322 addr=192.168.55.21:42796 laddr=192.168.55.10:6379 fd=312 name=sentinel-8f19c846-cmd age=11 idle=0 flags=x db=0 sub=0 psub=0 ssub=0 multi=4 qbuf=201 qbuf-free=20273 argv-mem=4 multi-mem=181 rbs=1024 rbp=1024 obl=45 oll=0 omem=0 tot-mem=22705 events=r cmd=exec user=sentinelredis redir=-1 resp=2 lib-name= lib-ver=')
  CONFIG REWRITE executed with success.
  Non blocking connect for SYNC fired the event.
  Master replied to PING, replication can continue...
  Trying a partial resynchronization (request c8c72055a21c7eae11da4843cbca9e8d5f6b5d3a:970620).
  Full resync from master: d20cba53884aa6b72d1836001be05c46e0b9e8d6:165003
  MASTER <-> REPLICA sync: receiving streamed RDB from master with EOF to disk
  Discarding previously cached master state.
  MASTER <-> REPLICA sync: Flushing old data
  MASTER <-> REPLICA sync: Loading DB in memory
  <search> Loading event starts
  Loading RDB produced by version 7.2.0
  RDB age 0 seconds
  RDB memory usage when created 2.02 Mb
  Done loading RDB, keys loaded: 114, keys expired: 0.
  <search> Skip background reindex scan, redis version contains loaded event.
  <search> Loading event ends
  MASTER <-> REPLICA sync: Finished with success
  Creating AOF incr file temp-appendonly.aof.incr on background rewrite
  Background append only file rewriting started by pid 17
  Successfully created the temporary AOF base file temp-rewriteaof-bg-17.aof
  Fork CoW for AOF rewrite: current 1 MB, peak 1 MB, average 1 MB
  Background AOF rewrite terminated with success
  Successfully renamed the temporary AOF base file temp-rewriteaof-bg-17.aof into appendonly.aof.2.base.rdb
  Successfully renamed the temporary AOF incr file temp-appendonly.aof.incr into appendonly.aof.2.incr.aof
  Removing the history file appendonly.aof.1.incr.aof in the background
  Removing the history file appendonly.aof in the background
  Background AOF rewrite finished successfully
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
