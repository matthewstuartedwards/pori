#!/bin/bash

set -e

MINIKUBE_USER="pori"
MINIKUBE_HOME="/home/${MINIKUBE_USER}"

echo "Creating Minikube systemd service..."

sudo tee /etc/systemd/system/minikube.service > /dev/null <<EOF
[Unit]
Description=Minikube Kubernetes Cluster
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
User=${MINIKUBE_USER}
Environment=HOME=${MINIKUBE_HOME}
ExecStart=/usr/bin/minikube start
ExecStop=/usr/bin/minikube stop
TimeoutStartSec=900

[Install]
WantedBy=multi-user.target
EOF

echo "Reloading systemd..."

sudo systemctl daemon-reload

echo "Enabling services..."

sudo systemctl enable minikube

echo
echo "Setup complete."
echo
echo "Start services with:"
echo "  sudo systemctl start minikube"
echo "Or reboot the VM."
