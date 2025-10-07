## remove configmap, secret
#kubectl delete -f manifests/local/local-config-secret.yaml
cd manifests/local
kubectl delete -f .
cd ../..

## uninstall kafka, redis
helm uninstall -n infra redis
helm uninstall -n infra kafka
helm uninstall -n infra mysql

## remove mysql service
kubectl delete -f kafka_redis_mysql/local-mysql-service.yaml

echo ""
echo "lsof -i :3306"
echo "lsof -i :3306 에 해당하는 process를 제거해야 합니다."
lsof -i :3306