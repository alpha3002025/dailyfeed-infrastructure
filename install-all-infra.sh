echo "📦📦📦 install kind cluster ... "
source install-kind-cluster.sh
echo ""


echo "📦📦📦 install mysql,redis,kafka,mongodb with helm ... "
cd helm
source 1-install-essential-local.sh
echo ""

