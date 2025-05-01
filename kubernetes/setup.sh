#!/bin/bash
#eval $(minikube docker-env) # This is needed whenever building a local docker image.  If not used, newly built containers will never be found by Kubernetes.
#minikube start --mount --mount-string "/storage/kubernetesStorage/orientdb/:/orientdb/" --mount-string "/storage/kubernetesStorage/ipr-db-bootstrap/:/docker-entrypoint-initdb.d/" --mount-string "/storage/kubernetesStorage/postgresDb/:/var/lib/postgresql/data/"
minikube start

minikube addons enable ingress
minikube addons enable volumesnapshots
minikube addons enable csi-hostpath-driver
kubectl patch storageclass csi-hostpath-sc -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

kubectl create namespace graphkb
kubectl create namespace ipr
kubectl create namespace security
kubectl create namespace db

docker build /storage/gitRepos/pori_ipr_api/ -t bcgsc/pori-ipr-api:uofc
docker build -f /storage/gitRepos/pori/demo/Dockerfile.auth /storage/gitRepos/pori/ -t pori-keycloak
docker build -f /storage/gitRepos/pori_graphkb_loader/Dockerfile.snakemake -t bcgsc/pori-graphkb-loader:latest /storage/gitRepos/pori_graphkb_loader/
docker build -f /storage/gitRepos/pori_ipr_client/Dockerfile -t bcgsc/pori-ipr-client:ucalgary /storage/gitRepos/pori_ipr_client/

export IPR_SERVICE_PASSWORD=root
export IPR_SERVICE_USER=ipr_ro
export IPR_GRAPHKB_PASSWORD=ipr_graphkb_link
export TEMPLATE_NAME=PORI
export TEMP_DB_NAME=temp_db
export DB_DUMP_LOCATION=/storage/gitRepos/pori_ipr_api/database_for_new_deployment/ipr_new_deployment.postgres.dump
export DATABASE_HOSTNAME=db.ipr.svc.cluster.local
export CURR_TEMPLATE=template

kubectl apply -f redis -f keycloak -f graphkb -f ipr -f persistentStorage

sleep 20
kubectl apply -f network
PODNAME=$(kubectl get pods -n ipr --no-headers | awk '{print $1}' | grep '^db-' | head -n 1 ) 
echo copying database to continer $PODNAME
sleep 120
# Copy the database bootstrap to the container.
kubectl cp /storage/kubernetesStorage/ipr-db-bootstrap/ipr_new_deployment.postgres.dump -n ipr $PODNAME:/docker-entrypoint-initdb.d/
kubectl cp /storage/kubernetesStorage/ipr-db-bootstrap/databaseSetup.sh  -n ipr $PODNAME:/docker-entrypoint-initdb.d/

kubectl exec -n ipr $PODNAME -- /docker-entrypoint-initdb.d/databaseSetup.sh
