
source create-namespace.sh

echo " 🔐 docker pro credential setup"
source setup-dockerhub-auth.sh
echo ""


echo " 📦 install redis"
source install-redis.sh
echo ""


echo " 📦 install kafka"
source install-kafka.sh
echo ""


echo " 📦 install mysql"
source install-mysql.sh
echo ""


echo " 📦 install mongodb"
#source install-mongodb.sh
kubectl apply -f local-mongodb-deployment.yaml
echo ""
echo ""
