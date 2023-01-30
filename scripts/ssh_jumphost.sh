#!/bin/bash

#-------------------------------------------------
#
# SSH to jumphost
#
#------------------------------------------------

#-----------------------------------------------------------------------------------
# TODO: Instead of hardcoding env variables, pass values by parameters in the future
#-----------------------------------------------------------------------------------

export project_id="a-demo-dev"
export jumphost_name="private-cluster-jumphost"
export jumphost_zone="asia-south1-a"

gcloud compute ssh $jumphost_name --project $project_id --zone $jumphost_zone --tunnel-through-iap