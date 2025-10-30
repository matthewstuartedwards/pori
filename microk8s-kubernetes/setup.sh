#!/bin/bash
#minikube start --mount --mount-string "/storage/kubernetesStorage/orientdb/:/orientdb/" --mount-string "/storage/kubernetesStorage/ipr-db-bootstrap/:/docker-entrypoint-initdb.d/" --mount-string "/storage/kubernetesStorage/postgresDb/:/var/lib/postgresql/data/"
#minikube start --cpus=4 --memory=8192

#minikube -p minikube docker-env | source
#eval $(minikube docker-env) # This is needed whenever building a local docker image.  If not used, newly built containers will never be found by Kubernetes.

########### ONE TIME SETUP
# Setup the microk8s envrionment to use the /app mount instead of root volume
# sudo nano /var/snap/microk8s/current/args/containerd
#--config ${SNAP_DATA}/args/containerd.toml
#--root /app/microk8s/var/lib/containerd
#--state /app/microk8s/run/containerd
#--address ${SNAP_COMMON}/run/containerd.sock
echo "Performing SED replacement on containerd"
sudo sed -i '/--root /c\--root /app/microk8s/var/lib/containerd' /var/snap/microk8s/current/args/containerd
sudo sed -i '/--state /c\--state /app/microk8s/run/containerd' /var/snap/microk8s/current/args/containerd

echo "Checking permissions on /app/microk8s"
sudo chown -R root:root /app/microk8s
sudo chown -R 700 /app/microk8s
echo "Restarting microk8s"
microk8s stop
microk8s start
# microk8s kubectl -n kube-system edit deploy hostpath-provisioner
# edit all instances of /var/snap/microk8s to /app/microk8s
echo "Setting up microk8s plugins"
microk8s enable dns

minikubeIP=$(microk8s kubectl get svc -n kube-system kube-dns -o jsonpath='{.spec.clusterIP}')

# 1) Capture your CoreDNS ClusterIP
CLUSTER_DNS_IP=$(microk8s kubectl -n kube-system get svc kube-dns -o jsonpath='{.spec.clusterIP}')

# If system uses systemctl
#sudo systemctl restart snap.microk8s.daemon-kubelet.service
# If system uses snap for microk8s install
#sudo snap restart microk8s.daemon-kubelet

# I think this is deprecated
#microk8s enable storage
microk8s enable hostpath-storage
mkdir -p /app/microk8s/default-storage

cat <<EOF | sudo tee /tmp/custom-storageclass.yaml > /dev/null
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: custom-storageclass
provisioner: microk8s.io/hostpath
reclaimPolicy: Retain
parameters:
  pvDir: /app/microk8s/default-storage
volumeBindingMode: WaitForFirstConsumer
EOF

microk8s kubectl apply -f /tmp/custom-storageclass.yaml
microk8s kubectl patch storageclass microk8s-hostpath -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
microk8s kubectl patch storageclass custom-storageclass -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

microk8s enable ingress
#microk8s enable rbac
microk8s enable metrics-server
microk8s enable dashboard


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
