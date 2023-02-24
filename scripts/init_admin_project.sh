#!/bin/bash

#-------------------------------------------------
#
# Use this script to create your GCP admin project.
#
# Once created:
# The script will create a GCS bucket "gs://${projectId}-terraform-state" 
# within the admin project -- to be used for saving Terraform states.
#
# The script will create a Service Account "terraform" within the admin project -- to be used by Terraform to create resources.
# Note: this script must be run by a human with admin rigths for the project_id.
#
#------------------------------------------------

# declare and init values.
selfStr="$(basename $0)"
billingAccountId=""
projectId=""
pathToSaveSAKey=""
TF_SERVICE_ACC_NAME="terraform"

# print usage instructions
print_usage() {
  echo -e "usage: $selfStr -P <admin project id> -B <billing account id> -S <path-to-save-service-account-key> [-h]"
}

# Bash's in-built getopts function to get values from flags
while getopts P:B:S:h flag  # If a character is followed by a colon (e.g. P:), that option is expected to have an argument.
do
    case "${flag}" in
      B) billingAccountId="$OPTARG";;
      P) projectId="$OPTARG";;
      S) pathToSaveSAKey="$OPTARG";;
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
[[ -z "${billingAccountId}" ]] && printErrMsgAndExit "Billing account ID is not provided"
[[ -z "${pathToSaveSAKey}" ]] && printErrMsgAndExit "Path, where to save Service account JSON key is not provided"

printInfoMsg "Checking if the ${projectId} exists. If not, creating one ..."
gcloud projects create "${projectId}" --name="${projectId}" || printWarnMsg "projectId already exist. No changes made to ${projectId}"
printLine

printInfoMsg "Linking the Billing account id ${billingAccountId} with the project ${projectId}. This is required to use gcloud services ..."
gcloud alpha billing projects link ${projectId} --billing-account ${billingAccountId} || printErrMsgAndExit "could not able to link project ${projectId} with billing account_id ${billingAccountId}"
printLine

printInfoMsg "Switching to project ${projectId} ..."
gcloud config set project ${projectId} || printErrMsgAndExit "Unable to switch to project ${projectId}"
printLine

printInfoMsg "Creating the GCS bucket gs://${projectId}-terraform-state. This bucket would be used to store the Terraform state files ..."
export TF_BUCKET="gs://${projectId}-terraform-state"

printInfoMsg "Checking if GCS bucket <projectId>-terraform-state exists. If not, creating one ..."
gsutil ls -b ${TF_BUCKET} || gsutil mb -c STANDARD -l US ${TF_BUCKET} || printErrMsgAndExit "could not create GCS bucket ${TF_BUCKET}"

printInfoMsg "Turning on versioning on the GCS bucket ..."
gsutil versioning set on ${TF_BUCKET} || printErrMsgAndExit "could not enable versioning on ${TF_BUCKET}"
printLine

printInfoMsg "Creating a service account named \"terraform\" -- to be used by Terraform ..."
printInfoMsg "Checking if service account \"${TF_SERVICE_ACC_NAME}\" exists. If not, creating one ..."
(gcloud iam service-accounts describe "${TF_SERVICE_ACC_NAME}@${projectId}.iam.gserviceaccount.com" && printInfoMsg "Above line confirms that Service account exists ...") || (printInfoMsg "Above error confirm that SA is missing. Creating ..." && gcloud iam service-accounts create "${TF_SERVICE_ACC_NAME}" --display-name "Terraform admin account") || printErrMsgAndExit "could not create the SA ${TF_SERVICE_ACC_NAME}"
printLine

printInfoMsg "Granting the service account permission to view the Admin Project ..."
gcloud projects add-iam-policy-binding ${projectId} \
  --member serviceAccount:${TF_SERVICE_ACC_NAME}@${projectId}.iam.gserviceaccount.com \
  --role roles/viewer || printErrMsgAndExit "Failed to grant viewer role to SA ${TF_SERVICE_ACC_NAME}@${projectId}.iam.gserviceaccount.com"
printLine

printInfoMsg "Granting the service account permission to manage Cloud Storage"
gcloud projects add-iam-policy-binding ${projectId} \
  --member serviceAccount:${TF_SERVICE_ACC_NAME}@${projectId}.iam.gserviceaccount.com \
  --role roles/storage.admin || printErrMsgAndExit "Failed to grant Storage Admin role to SA ${TF_SERVICE_ACC_NAME}@${projectId}.iam.gserviceaccount.com"
printLine

printInfoMsg "Generating the API key and saving it to ${pathToSaveSAKey}"
gcloud iam service-accounts keys create ${pathToSaveSAKey} \
  --iam-account ${TF_SERVICE_ACC_NAME}@${projectId}.iam.gserviceaccount.com
printLine

printInfoMsg "Any actions that Terraform performs require the Service API be enabled to do so. Enabling the required APIs ..."
# Even if you're creating a GKE cluster in project B,
# while the Service Account of the API is created in project A 
# the GKE API (strangly) must be enabled in project A too
```
gcloud services enable container.googleapis.com
```

# Same is true for the following APIs too:
```
gcloud services enable compute.googleapis.com
gcloud services enable iam.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com

```
printLine

printLine
printInfoMsg "Bucket to save statefiles: ${TF_BUCKET}"
printInfoMsg "Terraform Service Account: ${TF_SERVICE_ACC_NAME}@${projectId}.iam.gserviceaccount.com"
printInfoMsg "JSON key is saved at     : ${pathToSaveSAKey}"
printLine
