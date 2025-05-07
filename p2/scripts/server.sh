#!/bin/bash

sudo apt-get update -y
sudo apt-get install -y curl

IP=$1

RC_FILE="/home/vagrant/.bashrc"
INSTALL_K3S_EXEC="--write-kubeconfig-mode=644"

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="$INSTALL_K3S_EXEC" sh -

echo "alias k='kubectl'" >> "$RC_FILE"

sleep 20

kubectl apply -f /vagrant/app-one/deployment.yaml
kubectl apply -f /vagrant/app-two/deployment.yaml
kubectl apply -f /vagrant/app-three/deployment.yaml
kubectl apply -f /vagrant/network/ingress.yaml
