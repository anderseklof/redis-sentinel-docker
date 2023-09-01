#!/bin/bash

# Go to script directory to be sure of correct working directory.
cd "$(dirname "$0")"

for i in 1 2 3; do
	redis_conf_file="../config/redis$i.conf"

	rm -f $redis_conf_file

	# Allow remote connections
	echo "protected-mode no" | tee -a $redis_conf_file

	redis_port=$((6378 + $i))
	echo "port $redis_port" | tee -a $redis_conf_file

	if [ $i -gt 1 ]; then
		# Set Redis instance as a replica
		echo "replicaof 192.168.55.10 $redis_port" | tee -a $redis_conf_file
	fi

	# Set log file location
	echo "logfile /var/log/redis" | tee -a $redis_conf_file

	# Set persistance (.aof, .rdb files) location
	echo "dir /var/lib/redis" | tee -a $redis_conf_file

	# Enable appendonly persistance
	echo "appendonly yes" | tee -a $redis_conf_file

	# Disable default user
	echo "user default off" | tee -a $redis_conf_file

	# Create admin user
	echo "user admin on >admin123 ~* &* +@all" | tee -a $redis_conf_file

	# Create replicator user for replication between Redis instances
	echo "user replicator on >replicator123 +psync +replconf +ping" | tee -a $redis_conf_file

	# Set replication user
	echo "masteruser replicator" | tee -a $redis_conf_file
	echo "masterauth replicator123" | tee -a $redis_conf_file

	# Create user for Sentinel -> Redis communication
	echo "user sentinelredis on >sentinelredis123 allchannels +multi +slaveof +ping +exec +subscribe +config|rewrite +role +publish +info +client|setname +client|kill +script|kill" | tee -a $redis_conf_file

	# Load modules RediSearch and RediJSON
	echo "loadmodule /opt/redis-stack/lib/redisearch.so" | tee -a $redis_conf_file
	echo "loadmodule /opt/redis-stack/lib/rejson.so" | tee -a $redis_conf_file

	sentinel_conf_file="../config/sentinel$i.conf"

	rm -f $sentinel_conf_file

	# Allow remote connections
	echo "protected-mode no" | tee -a $sentinel_conf_file

	sentinel_port=$((26378 + $i))
	echo "port $sentinel_port" | tee -a $sentinel_conf_file

	# Set Redis master instance, name, port and quorum
	echo "sentinel monitor mymaster 192.168.55.10 6379 2" | tee -a $sentinel_conf_file

	# Set log file location, same name as for Redis instances
	echo "logfile /var/log/redis" | tee -a $sentinel_conf_file

	# Disable default user
	echo "user default off" | tee -a $sentinel_conf_file

	# Create admin user
	echo "user admin on >admin123 ~* &* +@all" | tee -a $sentinel_conf_file

	# Create user for Client -> Sentinel communication
	echo "user clientsentinel on >clientsentinel123 -@all +auth +client|getname +client|id +client|setname +command +hello +ping +role +sentinel|get-master-addr-by-name +sentinel|master +sentinel|myid +sentinel|replicas +sentinel|sentinels" | tee -a $sentinel_conf_file

	# Create user for Sentinel -> Sentinel communication
	echo "user sentinelsentinel on >sentinelsentinel123 allchannels +@all" | tee -a $sentinel_conf_file

	# Set authentication for Sentinel -> Sentinel communication
	echo "sentinel sentinel-user sentinelsentinel" | tee -a $sentinel_conf_file
	echo "sentinel sentinel-pass sentinelsentinel123" | tee -a $sentinel_conf_file

	# Set authentication for Sentinel -> Redis communication
	echo "sentinel auth-user mymaster sentinelredis" | tee -a $sentinel_conf_file
	echo "sentinel auth-pass mymaster sentinelredis123" | tee -a $sentinel_conf_file
done
