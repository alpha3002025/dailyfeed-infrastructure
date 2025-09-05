## remove configmap, secret
kubectl delete -f manifests/local/local-config-secret.yaml
## uninstall kafka, redis
helm uninstall -n infra redis
helm uninstall -n infra kafka
