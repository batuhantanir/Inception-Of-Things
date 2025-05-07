#!/bin/bash

sudo apt-get update -y
sudo apt-get install -y curl

IP=$1

RC_FILE="/home/vagrant/.bashrc"
INSTALL_K3S_EXEC="--write-kubeconfig-mode=644 --bind-address=$IP --advertise-address=$IP --node-ip=$IP"

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="$INSTALL_K3S_EXEC" sh -
sudo cp /var/lib/rancher/k3s/server/node-token /vagrant/token

echo "alias k='kubectl'" >> "$RC_FILE"
