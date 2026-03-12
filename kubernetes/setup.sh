#!/bin/bash
#minikube start --mount --mount-string "/app/kubernetesStorage/orientdb/:/orientdb/" --mount-string "/app/kubernetesStorage/ipr-db-bootstrap/:/docker-entrypoint-initdb.d/" --mount-string "/app/kubernetesStorage/postgresDb/:/var/lib/postgresql/data/"
#minikube start --cpus=3 --memory=5400

#minikube -p minikube docker-env | source
#eval $(minikube docker-env) # This is needed whenever building a local docker image.  If not used, newly built containers will never be found by Kubernetes.

minikube addons enable ingress
minikube addons enable ingress-dns
#minikube addons enable metrics-server
minikube addons enable volumesnapshots
minikube addons enable csi-hostpath-driver
minikube kubectl -- patch storageclass csi-hostpath-sc -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

minikube kubectl create namespace graphkb
minikube kubectl create namespace ipr
minikube kubectl create namespace security
minikube kubectl create namespace db
#minikube kubectl create namespace velero

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

docker build /storage/gitRepos/pori_ipr_api_new/ -t bcgsc/pori-ipr-api:uofc
docker build -f /storage/gitRepos/pori_new/demo/Dockerfile.auth /storage/gitRepos/pori_new/ -t pori-keycloak
docker build -f /storage/gitRepos/pori_graphkb_loader_new/Dockerfile.snakemake -t bcgsc/pori-graphkb-loader:latest /storage/gitRepos/pori_graphkb_loader/
docker build -f /storage/gitRepos/pori_ipr_client_new/Dockerfile -t bcgsc/pori-ipr-client:ucalgary /storage/gitRepos/pori_ipr_client/
docker build -f /storage/gitRepos/pori_graphkb_api_new/Dockerfile -t ucalgary/pori-graphkb-api:latest /storage/gitRepos/pori_graphkb_api/

export IPR_SERVICE_PASSWORD=root
export IPR_SERVICE_USER=ipr_ro
export IPR_GRAPHKB_PASSWORD=ipr_graphkb_link
export TEMPLATE_NAME=PORI
export TEMP_DB_NAME=temp_db
#export DB_DUMP_LOCATION=/app/pori_ipr_api/database_for_new_deployment/ipr_new_deployment.postgres.dump
export DB_DUMP_LOCATION=/storage/pori_ipr_api_new/database_for_new_deployment/ipr_new_deployment.postgres.dump
export DATABASE_HOSTNAME=db.ipr.svc.cluster.local
export CURR_TEMPLATE=template

minikube kubectl -- apply -f redis -f keycloak -f graphkb -f ipr -f persistentStorage

sleep 20
minikube kubectl -- apply -f network
PODNAME=$(minikube kubectl -- get pods -n ipr --no-headers | awk '{print $1}' | grep '^db-' | head -n 1 ) 
echo copying database to continer $PODNAME
sleep 120
# Copy the database bootstrap to the container.
minikube kubectl -- cp /storage/kubernetesStorage/ipr-db-bootstrap_new/ipr_new_deployment.postgres.dump -n ipr $PODNAME:/docker-entrypoint-initdb.d/
minikube kubectl -- cp /storage/kubernetesStorage/ipr-db-bootstrap_new/databaseSetup.sh  -n ipr $PODNAME:/docker-entrypoint-initdb.d/

minikube kubectl -- exec -n ipr $PODNAME -- /docker-entrypoint-initdb.d/databaseSetup.sh
