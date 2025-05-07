#!/bin/bash

sudo apt-get update -y
sudo apt-get install -y curl

MASTER_IP=$1
NODE_IP=$2

SHARED_TOKEN_URL="/vagrant/token"
MASTER_URL="https://$MASTER_IP:6443"
INSTALL_K3S_EXEC="--node-ip=$NODE_IP"

TOKEN=$(cat "$SHARED_TOKEN_URL")
echo "token: $TOKEN"
echo "INSTALL_K3S_EXEC: $INSTALL_K3S_EXEC"
echo "MASTER_URL: $MASTER_URL"

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="$INSTALL_K3S_EXEC" K3S_URL="$MASTER_URL" K3S_TOKEN="$TOKEN" sh -

rm -f "$SHARED_TOKEN_URL"