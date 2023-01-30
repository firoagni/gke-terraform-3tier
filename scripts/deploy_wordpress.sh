#!/bin/bash

#-------------------------------------------------
#
# Deploys a fully functional wordpress application in your cluster
#
#------------------------------------------------
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd ${SCRIPT_DIR}
./connect_cluster.sh
cd ..
HTTPS_PROXY=localhost:8888  kubectl apply -f ./k8s



HTTPS_PROXY=localhost:8888 kubectl get secrets
echo
HTTPS_PROXY=localhost:8888 kubectl get pvc
echo
HTTPS_PROXY=localhost:8888 kubectl get pods
echo
HTTPS_PROXY=localhost:8888 kubectl get services wordpress
echo
echo "Use the external IP in the browser to access the Wordpress site"
