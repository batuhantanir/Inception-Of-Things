#!/bin/bash

sudo apt-get update -y
sudo apt-get install -y curl

IP=$1

RC_FILE="/home/vagrant/.bashrc"
INSTALL_K3S_EXEC="--write-kubeconfig-mode=644 --disable traefik"

# Install K3s without built-in Traefik
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="$INSTALL_K3S_EXEC" sh -

# Configure kubeconfig
mkdir -p /home/vagrant/.kube
sudo cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
sudo chown vagrant:vagrant /home/vagrant/.kube/config
export KUBECONFIG=/home/vagrant/.kube/config

echo "alias k='kubectl'" >> "$RC_FILE"
echo "export KUBECONFIG=/home/vagrant/.kube/config" >> "$RC_FILE"

# Wait for K3s to be ready
sleep 20

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Wait for Helm to be ready
sleep 5

# Install Traefik CRDs first
kubectl apply -f https://raw.githubusercontent.com/traefik/traefik/v2.10/docs/content/reference/dynamic-configuration/kubernetes-crd-definition-v1.yml

# Wait for CRDs to be ready
sleep 10

# Install Traefik using Helm
helm repo add traefik https://traefik.github.io/charts
helm repo update
helm install traefik traefik/traefik -n kube-system

# Wait for Traefik to be ready
sleep 20

# Apply application configurations
kubectl apply -f /vagrant/app-one/deployment.yaml
kubectl apply -f /vagrant/app-two/deployment.yaml
kubectl apply -f /vagrant/app-three/deployment.yaml
kubectl apply -f /vagrant/network/ingress.yaml
