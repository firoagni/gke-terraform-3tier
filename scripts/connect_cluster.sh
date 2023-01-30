#!/bin/bash

#-------------------------------------------------
#
# Connect to GKE cluster via jumphost using SSH and IAP tunneling
#
#------------------------------------------------

#-----------------------------------------------------------------------------------
# TODO: Instead of hardcoding env variables, pass values by parameters in the future
#-----------------------------------------------------------------------------------

export project_id="a-demo-dev"
export jumphost_name="private-cluster-jumphost"
export jumphost_zone="asia-south1-a"
export cluster_name="private-cluster"
export cluster_region="asia-south1"

gcloud container clusters get-credentials $cluster_name --internal-ip --project $project_id --region $cluster_region 

gcloud compute ssh $jumphost_name --project $project_id --zone $jumphost_zone --tunnel-through-iap --  -L 8888:127.0.0.1:8888 -N -q -f