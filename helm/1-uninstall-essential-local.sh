## remove configmap, secret
kubectl delete -f manifests/local/local-config-secret.yaml
## uninstall kafka, redis
helm uninstall -n infra redis
helm uninstall -n infra kafka
helm uninstall -n infra mysql
## remove mysql service
kubectl delete -f kafka_redis_mysql/local-mysql-service.yaml