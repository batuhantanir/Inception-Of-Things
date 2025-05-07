#!/bin/bash

sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install curl -y

sudo apt update -y > /dev/null 2>&1
sudo apt install ca-certificates curl -y > /dev/null 2>&1
sudo install -m 0755 -d /etc/apt/keyrings > /dev/null 2>&1
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc > /dev/null 2>&1
sudo chmod 644 /etc/apt/keyrings/docker.asc > /dev/null 2>&1

echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update -y > /dev/null 2>&1

sudo apt install docker docker-compose docker.io -y > /dev/null 2>&1

curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" > /dev/null 2>&1

sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl > /dev/null 2>&1

k3d cluster create eyasa --servers 1 --agents 1
kubectl cluster-info

kubectl create namespace argocd
kubectl create namespace dev

kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=ready pod --all -n argocd --timeout=500s

kubectl apply -n argocd -f ../confs/application.yaml
kubectl apply -n dev -f ../confs/deployment.yaml
kubectl apply -n dev -f ../confs/service.yaml

kubectl wait --for=condition=ready pod --all -n dev --timeout=500s

echo "ArgoCd Password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)" > password.txt

kubectl port-forward svc/argocd-server -n argocd --address=0.0.0.0 8080:443 &

while true; do
    kubectl port-forward svc/wil-playground-service -n dev --address=0.0.0.0 8888:8888
    sleep 5
done