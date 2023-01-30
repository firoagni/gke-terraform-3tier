#!/bin/bash

#-------------------------------------------------
#
# Provision complete enviornment using Terraform
#
#------------------------------------------------

#-----------------------------------------------------------------------------------
# TODO: Instead of hardcoding env variables, pass values by parameters in the future
#-----------------------------------------------------------------------------------

# Set the path of the file where all env specific variables are declared
# Note: Path should be relative to the Project's root directory
export env_specific_tfvars_rel_path="vars/dev.tfvars"

# Set the path of the file where variables common across envs are declared
# Note: Path should be relative to the Project's root directory
export common_tfvars_rel_path="vars/common.tfvars"

# If you are running terraform outside of Google Cloud, 
# generate service account's (SAs) JSON key 
# and set the env. variable GOOGLE_APPLICATION_CREDENTIALS to the path of the service account key. 
# Terraform will then use that key to impersonate the SA to create the required resources.
export GOOGLE_APPLICATION_CREDENTIALS="/Users/ac7493/tf-admin.json"

# Set the name of the GCS bucket to save the Terraform state
# Make sure the bucket gs://<bucket> exists and 
# the service account has write permissions to the bucket
export bucket="a-demo-admin-terraform-state"

# Set the GCS prefix inside the bucket to save the Terraform state
# Terraform state will be stored in gs://<bucket>/<prefix>/<name>.tfstate
export prefix="dev/state"

# Locate the root directory
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

# Initialize and run Terraform
(cd "${ROOT}/terraform"; terraform init -backend-config="bucket=${bucket}" -backend-config="prefix=${prefix}" -input=false)
# (cd "${ROOT}/terraform"; terraform plan -var-file="${common_tfvars_rel_path}" -var-file="${env_specific_tfvars_rel_path}")
(cd "${ROOT}/terraform"; terraform apply -var-file="${common_tfvars_rel_path}" -var-file="${env_specific_tfvars_rel_path}" -input=false -auto-approve)

# Get cluster credentials
#GET_CREDS="$(terraform output --state=terraform/terraform.tfstate get_credentials)"
#echo ${GET_CREDS}