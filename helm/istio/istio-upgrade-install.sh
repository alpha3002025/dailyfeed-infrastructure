echo "🔎 Search repo ... "
helm repo add istio https://istio-release.storage.googleapis.com/charts
echo ""

echo "📊 Search result ... "
helm repo list
echo ""


## helm repo update
echo "🛸 repo update ... "
helm repo update
echo ""


## 버전 선택
# helm search repo istio


## istio-base 설치
echo "⛴️ istio-base upgrade install"
helm upgrade --install istio-base istio/base --namespace istio-system --create-namespace --version 1.27.1 --set profile=demo
echo ""


## istiod 설치
echo "⛴️ istiod upgrade install"
helm upgrade --install istiod istio/istiod --namespace istio-system --version 1.27.1 --set profile=demo --set pilot.resources.requests.memory=512Mi --set pilot.resources.limits.memory=1Gi --set pilot.resources.requests.cpu=250m
echo ""


## istio-ingress 설치
echo "⛴️ istiod upgrade install"
helm upgrade --install istio-ingress istio/gateway --namespace istio-ingress --create-namespace --version 1.27.1
echo ""


## 결과 확인
echo "🩺 check result (istio-system)"
kubectl get pods -n istio-system
echo ""

echo "🩺 check result (istio-ingress)"
kubectl get pods -n istio-ingress
echo ""


