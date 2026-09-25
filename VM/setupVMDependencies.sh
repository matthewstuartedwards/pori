#!/bin/bash

#Setup ssh
sudo apt update
sudo systemctl enable ssh

# COPY REQUIRED PORI REPOSITORIES TO /app
sudo mkdir /app
sudo chown pori:pori /app
sudo mkdir -p /storage/kubernetesStorage
sudo chown pori:pori /storage/kubernetesStorage

echo "Please copy the following repositories to /app:"
echo "  pori"
echo "  pori_ipr_api"
echo "  pori_graphkb_loader"
echo "  pori_ipr_client"
echo "  pori_graphkb_api"
echo "Please copy the database boostrap files to /storage/kubernetesStorage/ipr-db-bootstrap"
echo "Press any key to continue..."
read -n 1 -s

echo "Launching Minikube setup script..."

# Installing Docker
# Add Docker's official GPG key:
sudo apt update
sudo apt install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker $USER

# These two lines from the minikube website
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube_latest_amd64.deb
sudo dpkg -i minikube_latest_amd64.deb

echo "Please log out and back in, then run the pori setup.sh script"