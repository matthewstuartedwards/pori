#!/bin/bash
#eval $(minikube docker-env) # This is needed whenever building a local docker image.  If not used, newly built containers will never be found by Kubernetes.
kubectl create namespace graphkb
kubectl create namespace ipr
kubectl create namespace security
kubectl create namespace db
#kubectl apply -f (string join ',' *.yaml)
minikube addons enable ingress

docker build /storage/gitRepos/pori_ipr_api/ -t bcgsc/pori-ipr-api:uofc
docker build -f /storage/gitRepos/pori/demo/Dockerfile.auth /storage/gitRepos/pori/ -t pori-keycloak
docker build -f /storage/gitRepos/pori_graphkb_loader/Dockerfile.snakemake -t bcgsc/pori-graphkb-loader:latest /storage/gitRepos/pori_graphkb_loader/

export IPR_SERVICE_PASSWORD=root
export IPR_SERVICE_USER=ipr_ro
export IPR_GRAPHKB_PASSWORD=ipr_graphkb_link
export TEMPLATE_NAME=PORI
export TEMP_DB_NAME=temp_db
export DB_DUMP_LOCATION=/tmp/
export DATABASE_HOSTNAME=db.ipr.svc.cluster.local
export CURR_TEMPLATE=template