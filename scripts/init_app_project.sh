#!/bin/bash
#-------------------------------------------------
#
# Use this script initialize create the GCP project to be used to host the application.
#
# Once created, the script will provide the Terraform service account,
# necessary permissions to create\update\delete resources on our behalf
# in this project
#
# Note: this script must be run by a human with admin rigths for the project_id.
#
#------------------------------------------------

# declare and init values.
selfStr="$(basename $0)"
projectId=""
tfSAEmail=""

# print usage instructions
print_usage() {
  echo -e "usage: $selfStr -P <project id> -S <terraform service account email> [-h]"
}

# Bash's in-built getopts function to get values from flags
while getopts P:S:h flag  # If a character is followed by a colon (e.g. P:), that option is expected to have an argument.
do
    case "${flag}" in
      P) projectId="$OPTARG";;
      S) tfSAEmail="$OPTARG";;
      h) print_usage
         exit 0
        ;;
      *) print_usage
         exit 1
        ;;
    esac
done

# Function to print error message and exit
# $1 = message
printErrMsgAndExit() {
	echo -e "ERROR: $1"
  print_usage
	exit 254
}

# Function to print warning message
# $1 = message
printWarnMsg() {
  echo -e "WARN: $1"
}

# Function to print info message
# $1 = message
printInfoMsg() {
  echo -e "INFO: $1"
}

printLine(){
  echo -e "-------------------------------------"
}

# check required parameters
[[ -z "${projectId}" ]] && printErrMsgAndExit "project ID not provided"
[[ -z "${tfSAEmail}" ]] && printErrMsgAndExit "terraform service account email is not provided" #TODO Also check the email format is valid

printInfoMsg "Checking if the ${projectId} exists. If not, creating one ..."
gcloud projects create "${projectId}" --name="${projectId}" || printWarnMsg "projectId already exist. No changes made to ${projectId}"
printLine

printInfoMsg "Switching to project ${projectId} ..."
gcloud config set project ${projectId} || printErrMsgAndExit "Unable to switch to project ${projectId}"
printLine

printInfoMsg "Granting provided Terraform SA ${tfSAEmail} enough admin roles to run terraform on it"
rolesList="roles/iam.serviceAccountAdmin \
 roles/compute.networkAdmin \
 roles/iam.serviceAccountUser \
 roles/compute.admin \
 roles/container.admin \
 roles/container.clusterViewer \
 roles/iap.admin \
 roles/resourcemanager.projectIamAdmin \
 roles/serviceusage.serviceUsageAdmin \
 roles/storage.objectViewer \
 
 "
for rol in $rolesList; do
  gcloud projects add-iam-policy-binding ${projectId} --member=serviceAccount:${tfSAEmail} --role=$rol || printErrMsgAndExit "could not set $rol" 40
done