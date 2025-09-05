## remove configmap, secret
kubectl delete -f manifests/dev/dev-config-secret.yaml
## uninstall kafka, redis
helm uninstall -n infra redis
helm uninstall -n infra kafka
