echo "🛺🛺🛺  uninstall mysql,redis,kafka,mongodb with helm ... "
cd helm
source 1-uninstall-essential-local.sh
cd ..
echo ""

## uninstall kind
echo "🛺🛺🛺  delete cluster"
cd kind
source delete-cluster.sh
cd ..
