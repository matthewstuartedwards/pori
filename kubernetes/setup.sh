#!/bin/bash

PORI_REPOSITORY_ROOT=/storage/gitRepos
PORI_IPR_API_ROOT=/storage/gitRepos/pori_ipr_api_new


# If on a VM with limited storage, you might want to set where the container virtual filesystems through containerd are located.
#sudo mkdir -p /etc/containerd
#sudo containerd config default | sudo tee /etc/containerd/config.toml

############# Manually on first setup after minikube has been installed #####################
#### sudo nano /etc/containerd/config.toml
#### Modify the root path to your storage location and restart containerd with `sudo systemctl restart containerd` ###

# This is needed to prevent nginx from logging every request to the console, which causes high CPU usage and log spam in minikube.
#sudo sed -i '/^[[:space:]]*#/!{/^[[:space:]]*access_log.*stream-access\.log/s/.*/    access_log off;/}' /etc/nginx/nginx.conf
#minikube start --mount --mount-string "/app/kubernetesStorage/orientdb/:/orientdb/" --mount-string "/app/kubernetesStorage/ipr-db-bootstrap/:/docker-entrypoint-initdb.d/" --mount-string "/app/kubernetesStorage/postgresDb/:/var/lib/postgresql/data/"
#minikube start --cpus=3 --memory=5400
minikube start -p test --cpus=3 --memory=10000 --mount --mount-string "/storage/kubernetesStorage/orientdb/:/orientdb/" --mount-string "/storage/kubernetesStorage/ipr-db-bootstrap/:/docker-entrypoint-initdb.d/" --mount-string "/storage/kubernetesStorage/postgresDb:/var/lib/postgresql/data/"
minikube profile test

#minikube -p minikube docker-env | source
eval $(minikube docker-env --shell=bash) # This is needed whenever building a local docker image.  If not used, newly built containers will never be found by Kubernetes.

minikube addons enable ingress
minikube addons enable ingress-dns
minikube addons enable metrics-server
minikube addons enable volumesnapshots
minikube addons enable csi-hostpath-driver
minikube kubectl -- patch storageclass csi-hostpath-sc -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

minikube kubectl create namespace graphkb
minikube kubectl create namespace ipr
minikube kubectl create namespace security
minikube kubectl create namespace db
#minikube kubectl create namespace velero
MINIKUBE_IP=$(minikube ip)
# Stable versions of the containers
#docker build /storage/gitRepos/pori_ipr_api/ -t bcgsc/pori-ipr-api:uofc
#docker build -f /storage/gitRepos/pori/demo/Dockerfile.auth /storage/gitRepos/pori/ -t pori-keycloak
#docker build -f /storage/gitRepos/pori_graphkb_loader/Dockerfile.snakemake -t bcgsc/pori-graphkb-loader:latest /storage/gitRepos/pori_graphkb_loader/
#docker build -f /storage/gitRepos/pori_ipr_client/Dockerfile -t bcgsc/pori-ipr-client:ucalgary /storage/gitRepos/pori_ipr_client/
#docker build -f /storage/gitRepos/pori_graphkb_api/Dockerfile -t ucalgary/pori-graphkb-api:latest /storage/gitRepos/pori_graphkb_api/

# Most recent versions of the containers
#docker build /app/pori_ipr_api_new/ -t bcgsc/pori-ipr-api:uofc
#docker build -f /app/pori_new/demo/Dockerfile.auth /app/pori/ -t pori-keycloak
#docker build -f /app/pori_graphkb_loader_new/Dockerfile.snakemake -t bcgsc/pori-graphkb-loader:latest /app/pori_graphkb_loader/
#docker build -f /app/pori_ipr_client_new/Dockerfile -t bcgsc/pori-ipr-client:ucalgary /app/pori_ipr_client/
#docker build -f /app/pori_graphkb_api_new/Dockerfile -t ucalgary/pori-graphkb-api:latest /app/pori_graphkb_api/

docker build -f $PORI_REPOSITORY_ROOT/pori_ipr_api_new/Dockerfile $PORI_REPOSITORY_ROOT/pori_ipr_api_new/ -t bcgsc/pori-ipr-api:uofc
docker build -f $PORI_REPOSITORY_ROOT/pori_new/demo/Dockerfile.auth $PORI_REPOSITORY_ROOT/pori_new/ -t pori-keycloak
docker build -f $PORI_REPOSITORY_ROOT/pori_graphkb_loader_new/Dockerfile.snakemake -t bcgsc/pori-graphkb-loader:latest $PORI_REPOSITORY_ROOT/pori_graphkb_loader_new/
docker build -f $PORI_REPOSITORY_ROOT/pori_ipr_client_new/Dockerfile -t bcgsc/pori-ipr-client:ucalgary $PORI_REPOSITORY_ROOT/pori_ipr_client_new/
docker build -f $PORI_REPOSITORY_ROOT/pori_graphkb_api_new/Dockerfile -t ucalgary/pori-graphkb-api:latest $PORI_REPOSITORY_ROOT/pori_graphkb_api_new/

./addToCoreDNS.sh -q -e "$MINIKUBE_IP graphkb graphkb.default.svc.cluster.local graphkb.svc.cluster.local graphkb.cluster.local  ipr ipr.default.svc.cluster.local ipr.svc.cluster.local ipr.cluster.local  pori pori.default.svc.cluster.local pori.svc.cluster.local pori.cluster.local  keycloak keycloak.default.svc.cluster.local keycloak.svc.cluster.local keycloak.cluster.local  redis redis.default.svc.cluster.local redis.svc.cluster.local redis.cluster.local  iprdevredis iprdevredis.bcgsc.ca iprdevredis.default.svc.cluster.local iprdevredis.svc.cluster.local iprdevredis.cluster.local"

export IPR_SERVICE_PASSWORD=root
export IPR_SERVICE_USER=ipr_ro
export IPR_GRAPHKB_PASSWORD=ipr_graphkb_link
export TEMPLATE_NAME=PORI
export TEMP_DB_NAME=temp_db
#export DB_DUMP_LOCATION=/storage/kubernetesStorage/ipr-db-bootstrap/initialDatabase.dump
export DB_DUMP_LOCATION=/storage/kubernetesStorage/ipr-db-bootstrap/ipr_new_deployment.postgres.dump
export DATABASE_HOSTNAME=db.ipr.svc.cluster.local
export CURR_TEMPLATE=template

minikube kubectl -- apply -f redis -f keycloak -f graphkb -f ipr -f persistentStorage

sleep 20
minikube kubectl -- apply -f network
PODNAME=$(minikube kubectl -- get pods -n ipr --no-headers | awk '{print $1}' | grep '^db-' | head -n 1 ) 
echo copying database to continer $PODNAME
# Set up DB migrations
docker build -f $PORI_REPOSITORY_ROOT/pori/migrations_container/Dockerfile $PORI_IPR_API_ROOT -t pori-migrations:latest

sleep 60 # to wait for the database to be ready.
# Copy the database bootstrap to the container.  Name it initialDatabase.dump so that the databaseSetup.sh script doesn't have to be modified to work with different database dumps.
minikube kubectl -- cp $DB_DUMP_LOCATION -n ipr $PODNAME:/docker-entrypoint-initdb.d/initialDatabase.dump
minikube kubectl -- cp databaseSetup.sh  -n ipr $PODNAME:/docker-entrypoint-initdb.d/
minikube kubectl -- cp databaseSetupPostMigration.sh  -n ipr $PODNAME:/docker-entrypoint-initdb.d/


minikube kubectl -- exec -n ipr $PODNAME -- /docker-entrypoint-initdb.d/databaseSetup.sh
minikube kubectl -- create secret generic ipr-db-secret --from-literal=IPR_SERVICE_PASS='root'
minikube kubectl -- apply -f setupJobs/migrateDatabase.yaml
minikube kubectl -- wait --for=condition=complete job/migrate-db --timeout=300s

minikube kubectl -- exec -n ipr $PODNAME -- /docker-entrypoint-initdb.d/databaseSetupPostMigration.sh