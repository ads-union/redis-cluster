#!/bin/sh

ip=$(hostname -I | awk '{print $1}')

read -p "Root directory [/data/redis]: " dir
dir=${dir:-/data/redis}

read -p "Cluster replicas[6]: " replica
replica=${replica:-6}

read -p "Name prefix[redis-]: " prefix
prefix=${prefix:-redis-}

read -p "Master-Slave[1-5,2-6,3-4]: " SLAVES
SLAVES=${SLAVES:-1-5,2-6,3-4}

read -p "Stack name[redis]: " stackName
stackName=${stackName:-redis}

read -p "Network name[ads]: " network
network=${network:-ads}

read -p "Version[7.2.2-alpine]: " version
version=${version:-7.2.2-alpine}

read -p "Timezone[Asia/Taipei]: " timezone
timezone=${timezone:-Asia/Taipei}

read -p "CPU[2]: " cpu
cpu=${cpu:-2}

read -p "Memory[2GB]: " mem
mem=${mem:-2GB}

# files
env=.env
yaml=redis-stack.yaml
starter=startup.sh

# check docker network exists
net=`docker network inspect -f "{{.Name}}" $network`
if [ ! "$net" ]; then
        docker network create --driver overlay --attachable $network
fi

# create data folder
mkdir -p $dir
cd $dir
for i in $(seq 1 $replica); do
        mkdir -p $dir/$prefix$i

        # export nfs
        grep -v "^$dir/$prefix$i " /etc/exports > /etc/exports_temp
        mv /etc/exports_temp /etc/exports
        echo "$dir/$prefix$i $ip/24(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
done

exportfs -ra

# doanload config file
wget https://ads-union.github.io/redis.conf --quiet -O redis.conf

# write .env file
cat <<EOT > $env
Image=x21146/redis-cluster:$version
TZ=$timezone
CPU=$cpu
Mem=$mem
EOT

# write stack file
cat <<EOT > $yaml
version: '3.8'
volumes:
  redis-volume:
    name: '{{.Service.Name}}'
    driver_opts:
      type: 'nfs'
      o: 'addr=$ip,nolock,soft,rw'
      device: ':$dir/{{index .Service.Labels "service.name"}}'

configs:
  redis-config:
    file: ./redis.conf
    template_driver: golang
    name: redisi-config-v1

networks:
  ads:
    name: $network
    external: true

services:
EOT

# write service stack
for i in $(seq 1 $replica); do
    cat <<EOT >> $yaml
  cluster-$i:
    image: \${Image}
    hostname: '{{index .Service.Labels "service.name"}}'
    volumes:
      - redis-volume:/data
    configs:
      - source: redis-config
        target: /usr/local/etc/redis/redis.conf
    networks:
      - ads
    deploy:
      labels:
        service.name: $prefix$i
      replicas: 1
      restart_policy:
        condition: on-failure
      resources:
        limits:
          cpus: \${CPU}
          memory: \${Mem}
      placement:
        constraints:
          - node.labels.redis==true
          - node.labels.redis-no==$((($i - 1) % 3 + 1))
    environment:
      TZ: \${TZ}

EOT
done

# docker stack starter
cat <<EOT > $starter
#!/bin/sh

cd \$(dirname \$0)
env \$(cat $env | grep ^[A-Z] | xargs) docker stack deploy -c $yaml --with-registry-auth --resolve-image changed $stackName
EOT

chmod +x $starter

# start
eval $dir/$starter

# create cluster
docker run --rm \
        --network $network \
        -e PREFIX=$prefix \
        -e PORT=6379 \
        -e SLAVES=$SLAVES \
        x21146/redis-cluster-init:$version
