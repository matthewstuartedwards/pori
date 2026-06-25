#!/bin/bash

export IPR_SERVICE_PASSWORD=root
export IPR_SERVICE_USER=ipr_ro
export IPR_GRAPHKB_PASSWORD=ipr_graphkb_link
export TEMPLATE_NAME=PORI
export TEMP_DB_NAME=temp_db
export DB_DUMP_LOCATION=/app/pori_ipr_api/database_for_new_deployment/initialDatabase.dump
#export DB_DUMP_LOCATION=/storage/pori_ipr_api_new/database_for_new_deployment/ipr_schema.postgres.dump

export DATABASE_HOSTNAME=db.ipr.svc.cluster.local
export CURR_TEMPLATE=template

minikube kubectl -- apply -f ipr

PODNAME=$(minikube kubectl -- get pods -n ipr --no-headers | awk '{print $1}' | grep '^db-' | head -n 1 )
echo copying database to continer $PODNAME
sleep 120
# Copy the database bootstrap to the container.
#minikube kubectl -- cp /storage/kubernetesStorage/ipr-db-bootstrap_new/ipr_new_deployment.postgres.dump -n ipr $PODNAME:/docker-entrypoint-initdb.d/
minikube kubectl -- cp /storage/kubernetesStorage/ipr-db-bootstrap_new/ipr_schema.postgres.dump -n ipr $PODNAME:/docker-entrypoint-initdb.d/
minikube kubectl -- cp /storage/kubernetesStorage/ipr-db-bootstrap_new/databaseSetup.sh  -n ipr $PODNAME:/docker-entrypoint-initdb.d/

minikube kubectl -- exec -n ipr $PODNAME -- /docker-entrypoint-initdb.d/databaseSetup.sh
