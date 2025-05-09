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

sudo rm -rf kubectl

sudo k3d cluster create eyasa --servers 1 --agents 1
sudo kubectl cluster-info

sudo kubectl create namespace argocd
sudo kubectl create namespace dev

# Pod durumunu kontrol etmek için fonksiyon
function wait_for_pods() {
  namespace=$1
  echo "Bekliyor: $namespace namespace'indeki tüm podlar hazır olana kadar..."
  
  while true; do
    # Namespace'deki tüm pod'ları ve durumlarını alın
    local pending_pods=$(kubectl get pods -n $namespace | grep "Pending" | wc -l)
    local creating_pods=$(kubectl get pods -n $namespace | grep "ContainerCreating" | wc -l)
    local initializing_pods=$(kubectl get pods -n $namespace | grep "Init:" | wc -l)
    
    if [ "$pending_pods" -eq 0 ] && [ "$creating_pods" -eq 0 ] && [ "$initializing_pods" -eq 0 ]; then
      # Tüm pod'ların Ready durumunda olup olmadığını kontrol et
      local not_ready=$(kubectl get pods -n $namespace -o jsonpath='{.items[?(@.status.containerStatuses[*].ready==false)].metadata.name}')
      if [ -z "$not_ready" ]; then
        echo "Tüm pod'lar $namespace namespace'inde hazır!"
        break
      fi
    fi
    
    echo "Hala bekleniyor... Pending: $pending_pods, Creating: $creating_pods, Initializing: $initializing_pods"
    sleep 10
  done
}

echo "ArgoCD kurulumu başlatılıyor..."
sudo kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
wait_for_pods "argocd"

echo "Diğer Kubernetes kaynakları uygulanıyor..."
sudo kubectl apply -n argocd -f ../confs/application.yaml
sudo kubectl apply -n dev -f ../confs/deployment.yaml
sudo kubectl apply -n dev -f ../confs/service.yaml

echo "Dev namespace'indeki podların hazır olması bekleniyor..."
wait_for_pods "dev"

echo "ArgoCd Password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)" > password.txt

echo "Port yönlendirmeleri başlatılıyor..."
sudo kubectl port-forward svc/argocd-server -n argocd --address=0.0.0.0 8080:443 &
ARGOCD_PF_PID=$!
echo "ArgoCD port-forward PID: $ARGOCD_PF_PID"

while true; do
    sudo kubectl port-forward svc/wil-playground-service -n dev --address=0.0.0.0 8888:8888
    sleep 5
done