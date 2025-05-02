#!/bin/bash
#set -e

sudo apt-get update -y
sudo apt-get install curl -y

#sudo apt-get install ca-certificates curl
#sudo install -m 0755 -d /etc/apt/keyrings
#sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
#sudo chmod a+r /etc/apt/keyrings/docker.asc
#echo \
  #"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  #$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  #sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
#sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugi

k3d cluster create eyasa-bonus --servers 1 --agents 1
kubectl cluster-info

kubectl create namespace argocd
kubectl create namespace dev
kubectl create namespace gitlab

sudo curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
sudo chmod +x get_helm.sh
sudo ./get_helm.sh
sudo helm repo add gitlab https://charts.gitlab.io/
sudo helm repo update

sudo helm upgrade --install gitlab gitlab/gitlab \
  --namespace gitlab \
  -f ../confs/gitlab.values.yaml

sudo kubectl wait --for=condition=available deployments --all -n gitlab --timeout=5m
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=ready pod --all -n argocd --timeout=5m

kubectl apply -n argocd -f ../confs/application.yaml
kubectl apply -n dev -f ../confs/deployment.yaml
kubectl apply -n dev -f ../confs/service.yaml
kubectl apply -f ../confs/gitlab-ingress.yaml

echo "Gitlab Password: $(kubectl get secret gitlab-gitlab-initial-root-password -n gitlab -ojsonpath='{.data.password}' | base64 -d)" > password.txt
echo "ArgoCd Password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)" >> password.txt

kubectl port-forward svc/gitlab-webservice-default -n gitlab 8081:8080 &>/dev/null &

kubectl port-forward svc/argocd-server -n argocd 8080:443 &>/dev/null &