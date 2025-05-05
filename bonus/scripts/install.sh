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

k3d cluster create eyasa-bonus \
  --servers 1 \
  --agents 1 \
  --port "80:80@loadbalancer" \
  --port "443:443@loadbalancer" \
  --api-port 6443
kubectl cluster-info

kubectl create namespace argocd
kubectl create namespace dev
kubectl create namespace gitlab

# Install NGINX Ingress Controller
echo "NGINX Ingress Controller kurulumu başlatılıyor..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml
echo "NGINX Ingress Controller hazır olana kadar bekleniyor..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

sudo curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
sudo chmod +x get_helm.sh
sudo ./get_helm.sh
sudo helm repo add gitlab https://charts.gitlab.io/
sudo helm repo update

echo "GitLab kurulumu başlatılıyor..."
sudo helm upgrade --install gitlab gitlab/gitlab \
  --namespace gitlab \
  --version 8.11.1 \
  --set certmanager-issuer.email=emirys774@gmail.com \
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
kubectl apply -f ../confs/argocd-ingress.yaml

echo "Parolalar kaydediliyor..."
echo "Gitlab Password: $(kubectl get secret gitlab-gitlab-initial-root-password -n gitlab -ojsonpath='{.data.password}' | base64 -d)" > password.txt
echo "ArgoCd Password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)" >> password.txt

echo "Kurulum tamamlandı!"
echo "Erişim bilgileri:"
echo "GitLab: http://gitlab.local"
echo "ArgoCD: http://argocd.local"
echo "Parolalar password.txt dosyasında kaydedildi."

# ArgoCD'yi insecure modda çalıştır
kubectl patch deployment argocd-server -n argocd -p '{"spec": {"template": {"spec": {"containers": [{"name": "argocd-server","command": ["argocd-server","--insecure","--staticassets","/shared/app"]}]}}}}'
