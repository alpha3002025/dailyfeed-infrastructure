source create-namespace.sh
source install-redis.sh
source install-kafka.sh
source install-mysql.sh
#source install-mongodb.sh
kubectl apply -f local-mongodb-deployment.yaml