source create-namespace.sh

echo " 📦 install redis"
source install-redis.sh
echo ""


echo " 📦 install kafka"
source install-kafka.sh
echo ""


echo " 📦 install mysql"
source install-mysql.sh
echo ""


## atlas mongodb
# echo " 📦 install mongodb"
# #source install-mongodb.sh
# kubectl apply -f local-mongodb-deployment.yaml
# echo ""
echo ""
