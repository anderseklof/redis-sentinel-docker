#!/bin/bash

# Go to script directory to be sure of correct working directory.
cd "$(dirname "$0")"

for i in 1 2 3; do
	redis_conf_file="../config/redis$i.conf"

	rm -f $redis_conf_file

	echo "# Allow remote connections" | tee $redis_conf_file
	echo "protected-mode no" | tee -a $redis_conf_file

	redis_port=$((6378 + $i))
	echo "port $redis_port" | tee -a $redis_conf_file

	if [ $i -gt 1 ]; then
		echo "# Set Redis instance as a replica" | tee -a $redis_conf_file
		echo "replicaof 192.168.55.10 $redis_port" | tee -a $redis_conf_file
	fi

	echo "# Set log file location" | tee -a $redis_conf_file
	echo "logfile /var/log/redis" | tee -a $redis_conf_file

	echo "# Set persistance (.aof, .rdb files) location" | tee -a $redis_conf_file
	echo "dir /var/lib/redis" | tee -a $redis_conf_file

	echo "# Enable appendonly persistance" | tee -a $redis_conf_file
	echo "appendonly yes" | tee -a $redis_conf_file

	echo "# Disable default user" | tee -a $redis_conf_file
	echo "user default off" | tee -a $redis_conf_file

	echo "# Create admin user" | tee -a $redis_conf_file
	echo "user admin on >admin123 ~* &* +@all" | tee -a $redis_conf_file

	echo "# Create replicator user for replication between Redis instances" | tee -a $redis_conf_file
	echo "user replicator on >replicator123 +psync +replconf +ping" | tee -a $redis_conf_file

	echo "# Set replication user" | tee -a $redis_conf_file
	echo "masteruser replicator" | tee -a $redis_conf_file
	echo "masterauth replicator123" | tee -a $redis_conf_file

	echo "# Create user for Sentinel -> Redis communication" | tee -a $redis_conf_file
	echo "user sentinel_to_redis on >sentinelredis123 allchannels +multi +slaveof +ping +exec +subscribe +config|rewrite +role +publish +info +client|setname +client|kill +script|kill" | tee -a $redis_conf_file

	echo "# Load modules RediSearch and RediJSON" | tee -a $redis_conf_file
	echo "loadmodule /opt/redis-stack/lib/redisearch.so" | tee -a $redis_conf_file
	echo "loadmodule /opt/redis-stack/lib/rejson.so" | tee -a $redis_conf_file

	sentinel_conf_file="../config/sentinel$i.conf"

	rm -f $sentinel_conf_file

	echo "# Allow remote connections" | tee $sentinel_conf_file
	echo "protected-mode no" | tee -a $sentinel_conf_file

	sentinel_port=$((26378 + $i))
	echo "port $sentinel_port" | tee -a $sentinel_conf_file

	echo "# Set Redis master instance, name, port and quorum" | tee -a $sentinel_conf_file
	echo "sentinel monitor mymaster 192.168.55.10 6379 2" | tee -a $sentinel_conf_file

	echo "# Set log file location, same name as for Redis instances" | tee -a $sentinel_conf_file
	echo "logfile /var/log/redis" | tee -a $sentinel_conf_file

	echo "# Disable default user" | tee -a $sentinel_conf_file
	echo "user default off" | tee -a $sentinel_conf_file

	echo "# Create admin user" | tee -a $sentinel_conf_file
	echo "user admin on >admin123 ~* &* +@all" | tee -a $sentinel_conf_file

	echo "# Create user for Client -> Sentinel communication" | tee -a $sentinel_conf_file
	echo "user client_to_sentinel on >clientsentinel123 -@all +auth +client|getname +client|id +client|setname +command +hello +ping +role +sentinel|get-master-addr-by-name +sentinel|master +sentinel|myid +sentinel|replicas +sentinel|sentinels" | tee -a $sentinel_conf_file

	echo "# Create user for Sentinel -> Sentinel communication" | tee -a $sentinel_conf_file
	echo "user sentinel_to_sentinel on >sentinelsentinel123 allchannels +@all" | tee -a $sentinel_conf_file

	echo "# Set authentication for Sentinel -> Sentinel communication" | tee -a $sentinel_conf_file
	echo "sentinel sentinel-user sentinel_to_sentinel" | tee -a $sentinel_conf_file
	echo "sentinel sentinel-pass sentinelsentinel123" | tee -a $sentinel_conf_file

	echo "# Set authentication for Sentinel -> Redis communication" | tee -a $sentinel_conf_file
	echo "sentinel auth-user mymaster sentinel_to_redis" | tee -a $sentinel_conf_file
	echo "sentinel auth-pass mymaster sentinelredis123" | tee -a $sentinel_conf_file
done
