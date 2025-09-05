## configmap, secret
kubectl create ns dailyfeed
## infra
kubectl create ns infra
## install configmap, secret
kubectl apply -f manifests/local/local-config-secret.yaml
## install kafka, redis
cd kafka_redis
source setup.sh
cd ..