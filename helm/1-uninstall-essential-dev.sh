## remove configmap, secret
kubectl delete -f manifests/dev/dev-config-secret.yaml
## uninstall kafka, redis
helm uninstall -n infra redis
helm uninstall -n infra kafka
## remove mysql service
kubectl delete -f kafka_redis_mysql/dev-mysql-service.yaml