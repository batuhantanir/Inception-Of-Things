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

#openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout gitlab.key -out gitlab.crt -subj "/CN=gitlab.local" -addext "subjectAltName = DNS:gitlab.local"
#kubectl create secret generic gitlab-custom-ca --from-file=gitlab.crt --from-file=gitlab.key -n gitlab

echo "GitLab kurulumu başlatılıyor..."
sudo helm upgrade --install gitlab gitlab/gitlab \
  --namespace gitlab \
  --version 7.5.0 \
  --set global.image.pullPolicy=IfNotPresent \
  -f ../confs/gitlab.values.yaml

echo "GitLab podlarının hazır olması bekleniyor..."
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

echo "GitLab web service deployment'inin hazır olması bekleniyor..."
kubectl wait --for=condition=available deployment/gitlab-webservice-default -n gitlab --timeout=10m

echo "ArgoCD kurulumu başlatılıyor..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
wait_for_pods "argocd"

echo "Diğer Kubernetes kaynakları uygulanıyor..."
kubectl apply -n argocd -f ../confs/application.yaml
kubectl apply -n dev -f ../confs/deployment.yaml
kubectl apply -n dev -f ../confs/service.yaml
kubectl apply -f ../confs/gitlab-ingress.yaml

echo "Parolalar kaydediliyor..."
echo "Gitlab Password: $(kubectl get secret gitlab-gitlab-initial-root-password -n gitlab -ojsonpath='{.data.password}' | base64 -d)" > password.txt
echo "ArgoCd Password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)" >> password.txt

function start_port_forwards() {
  echo "Port yönlendirmeleri başlatılıyor..."
  
  kubectl port-forward svc/gitlab-webservice-default -n gitlab 8181:8181 --address=192.168.56.110 &
  GITLAB_PF_PID=$!
  echo "GitLab port-forward PID: $GITLAB_PF_PID"
  
  kubectl port-forward svc/argocd-server -n argocd 8080:443 --address=192.168.56.110 &
  ARGOCD_PF_PID=$!
  echo "ArgoCD port-forward PID: $ARGOCD_PF_PID"
  
  echo "Port yönlendirmeleri başlatıldı."
  echo "Erişim bilgileri:"
  echo "GitLab: http://192.168.56.110:8081"
  echo "ArgoCD: https://192.168.56.110:8080"
  echo ""
  echo "Bu scripti durdurmak için Ctrl+C tuşlarına basın"
  echo "Port yönlendirme işlemlerini sonlandırmak için: kill $GITLAB_PF_PID $ARGOCD_PF_PID"
  
  wait
}

start_port_forwards
