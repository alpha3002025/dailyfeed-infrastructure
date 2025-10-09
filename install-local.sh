echo "🛺🛺 install kind 😆😆 "
cd kind
source create-cluster.sh
cd ..
echo ""

echo "🛺🛺 install tasks in ./helm/** 😆😆 "
cd helm
source 1-install-essential-local.sh
cd ..
echo ""
