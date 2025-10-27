#!/bin/bash
#minikube start --mount --mount-string "/storage/kubernetesStorage/orientdb/:/orientdb/" --mount-string "/storage/kubernetesStorage/ipr-db-bootstrap/:/docker-entrypoint-initdb.d/" --mount-string "/storage/kubernetesStorage/postgresDb/:/var/lib/postgresql/data/"
#minikube start --cpus=4 --memory=8192

#minikube -p minikube docker-env | source
#eval $(minikube docker-env) # This is needed whenever building a local docker image.  If not used, newly built containers will never be found by Kubernetes.

microk8s enable dns

minikubeIP=$(microk8s kubectl get svc -n kube-system kube-dns -o jsonpath='{.spec.clusterIP}')

# 1) Capture your CoreDNS ClusterIP
CLUSTER_DNS_IP=$(microk8s kubectl -n kube-system get svc kube-dns -o jsonpath='{.spec.clusterIP}')

# If system uses systemctl
#sudo systemctl restart snap.microk8s.daemon-kubelet.service
# If system uses snap for microk8s install
#sudo snap restart microk8s.daemon-kubelet

microk8s enable storage
microk8s enable ingress
#microk8s enable rbac
microk8s enable metrics-server
microk8s enable dashboard
microk8s enable hostpath-storage

microk8s kubectl create namespace graphkb
microk8s kubectl create namespace ipr
microk8s kubectl create namespace security
microk8s kubectl create namespace db
#microk8s kubectl create namespace velero


docker build /storage/gitRepos/pori_ipr_api/ -t bcgsc/pori-ipr-api:uofc
docker save bcgsc/pori-ipr-api:uofc | microk8s ctr image import -
docker build -f /storage/gitRepos/pori/demo/Dockerfile.auth /storage/gitRepos/pori/ -t pori-keycloak
docker save pori-keycloak | microk8s ctr image import -
docker build -f /storage/gitRepos/pori_graphkb_loader/Dockerfile.snakemake -t bcgsc/pori-graphkb-loader:latest /storage/gitRepos/pori_graphkb_loader/
docker save bcgsc/pori-graphkb-loader:latest | microk8s ctr image import -
docker build -f /storage/gitRepos/pori_ipr_client/Dockerfile -t bcgsc/pori-ipr-client:ucalgary /storage/gitRepos/pori_ipr_client/
docker save bcgsc/pori-ipr-client:ucalgary | microk8s ctr image import -
docker build -f /storage/gitRepos/pori_graphkb_api/Dockerfile -t ucalgary/pori-graphkb-api:latest /storage/gitRepos/pori_graphkb_api/
docker save ucalgary/pori-graphkb-api:latest | microk8s ctr image import -

export IPR_SERVICE_PASSWORD=root
export IPR_SERVICE_USER=ipr_ro
export IPR_GRAPHKB_PASSWORD=ipr_graphkb_link
export TEMPLATE_NAME=PORI
export TEMP_DB_NAME=temp_db
export DB_DUMP_LOCATION=/storage/gitRepos/pori_ipr_api/database_for_new_deployment/ipr_new_deployment.postgres.dump
export DATABASE_HOSTNAME=db.ipr.svc.cluster.local
export CURR_TEMPLATE=template
sleep 60
microk8s kubectl apply -f redis -f keycloak -f graphkb -f ipr -f persistentStorage

sleep 20
microk8s kubectl apply -f network
PODNAME=$(microk8s kubectl get pods -n ipr --no-headers | awk '{print $1}' | grep '^db-' | head -n 1 ) 
echo copying database to continer $PODNAME
sleep 120
# Copy the database bootstrap to the container.
microk8s kubectl cp /storage/kubernetesStorage/ipr-db-bootstrap/ipr_new_deployment.postgres.dump -n ipr $PODNAME:/docker-entrypoint-initdb.d/
microk8s kubectl cp /storage/kubernetesStorage/ipr-db-bootstrap/databaseSetup.sh  -n ipr $PODNAME:/docker-entrypoint-initdb.d/

microk8s kubectl exec -n ipr $PODNAME -- /docker-entrypoint-initdb.d/databaseSetup.sh
