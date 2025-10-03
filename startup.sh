#!/bin/sh

conf=/data/nodes.conf
temp=/data/nodes.temp

# update node ips if node.conf exists
IFS=$'\n'
if [ -f $conf ]; then
	# reset temp file
	touch $temp
	cat /dev/null > $temp
	
	for i in `cat $conf`; do
		# find hostname in current line
		# if not found, write all line to temp file
		host=`echo $i | awk '{print $2}' | awk -F ',' '{print $2}'`
		if [ "$host" == "" ]; then
			echo $i >> $temp
			continue
		fi

		# wait for container up
		counter=0
		ip=""
		while true; do
			# get ip by docker hostname
			# if ip not found, wait 1 second and retry
			# after retry in 2 minutes, stop waiting
			ip=`nslookup -type=a $host | awk 'NR==6' | awk '{print $2}'`
	                if [ "$ip" != "" ]; then
                	        break
                	fi
			
			sleep 1s
			counter=`expr $counter + 1`
			if [ "$counter" == "120" ]; then
				echo "wait for $host over 120 seconds, skip this node."
				break
			fi
		done
		
		# ip not found, write current line to temp file
		if [ "$ip" == "" ]; then
			echo $i >> $temp
			continue
		fi
		
		# replace ip
		oldIP=`echo $i | awk '{print $2}' | awk -F ':' '{print $1}'`
		echo "$host: $oldIP  ==>  $ip"
		echo $i | sed "s/$oldIP/$ip/g" >> $temp
	done

	mv $temp $conf
fi

sysctl vm.overcommit_memory=1

# start redis server
redis-server /usr/local/etc/redis/redis.conf
