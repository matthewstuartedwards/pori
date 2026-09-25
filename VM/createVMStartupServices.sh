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
Requires=docker.service

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

echo "Creating Minikube ingress proxy script..."

sudo tee /usr/local/bin/minikube-ingress-proxy.sh > /dev/null <<EOF
#!/bin/bash

IP=\$(runuser -u ${MINIKUBE_USER} -- /usr/bin/minikube ip)

echo "Using Minikube IP: \$IP"

exec /usr/bin/socat \
  TCP-LISTEN:80,fork,reuseaddr \
  TCP:\${IP}:80
EOF

sudo chmod 755 /usr/local/bin/minikube-ingress-proxy.sh

echo "Creating proxy systemd service..."

sudo tee /etc/systemd/system/minikube-ingress-proxy.service > /dev/null <<EOF
[Unit]
Description=Forward VM port 80 to Minikube ingress
Requires=minikube.service
After=minikube.service

[Service]
Type=simple
ExecStart=/usr/local/bin/minikube-ingress-proxy.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

echo "Reloading systemd..."

sudo systemctl daemon-reload

echo "Enabling services..."

sudo systemctl enable minikube
sudo systemctl enable minikube-ingress-proxy

echo
echo "Setup complete."
echo
echo "Start services with:"
echo "  sudo systemctl start minikube"
echo "  sudo systemctl start minikube-ingress-proxy"
echo
echo "Or reboot the VM."