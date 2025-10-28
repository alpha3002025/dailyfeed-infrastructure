helm install redis oci://registry-1.docker.io/cloudpirates/redis \
    --namespace infra \
    --set auth.password=QmHCVICmJ63L6FIR \
    --set master.resources.requests.memory=2Gi \
    --set master.resources.limits.memory=4Gi \
    --set master.resources.requests.cpu=500m \
    --set master.resources.limits.cpu=1000m 
    # !!![docker hub pro]
    # --set-string 'global.imagePullSecrets[0].name=dockerhub-secret'