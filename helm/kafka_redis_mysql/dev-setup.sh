source create-namespace.sh

echo " 📦 install redis"
source install-redis.sh
echo ""


echo " 📦 install kafka"
source install-kafka.sh
echo ""


echo " ℹ️  MySQL: Using RDS (dailyfeed-dev.c7muo0wa2dr1.ap-northeast-2.rds.amazonaws.com)"
echo " 🔗 Creating ExternalName Service for MySQL RDS..."
kubectl apply -f dev-mysql-service.yaml
echo ""

echo " ℹ️  MongoDB: Using Atlas (alpha300.sz30zco.mongodb.net)"
echo " 🔗 Creating ExternalName Service for MongoDB Atlas..."
kubectl apply -f dev-mongodb-service.yaml
echo ""
