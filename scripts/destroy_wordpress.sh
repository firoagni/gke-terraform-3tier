#!/bin/bash

#-------------------------------------------------
#
# Completely remove the wordpress application from your cluster
#
#------------------------------------------------
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd ${SCRIPT_DIR}
./connect_cluster.sh
cd ..
HTTPS_PROXY=localhost:8888  kubectl delete -f ./k8s