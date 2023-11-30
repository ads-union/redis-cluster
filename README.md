# redis-cluster

## install

``` shell
wget -O installer.sh https://ads-union.github.io/redis-cluster/installer.sh \
	&& sudo bash installer.sh
```

* Must use docker swarm
* Install on manager node

## Labels

* node.labels.redis = true
* node.labels.redis-no = 1 or 2 or 3
  * cluster 1 run on redis-no = 1
  * cluster 2 run on redis-no = 2
  * cluster 3 run on redis-no = 3
  * cluster 4 run on redis-no = 1
  * cluster 5 run on redis-no = 2
  * cluster 6 run on redis-no = 3

|Master|Slave|
|---|---|
|cluster 1|cluster 5|
|cluster 2|cluster 6|
|cluster 3|cluster 4|

![architecture](https://github.com/ads-union/redis-cluster/blob/main/architecture.jpg?raw=true)
