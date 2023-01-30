#!/bin/bash
#this must be run by a human with admin rigths for the project_id.

# declare and init values.
selfStr="$(basename $0)"
baseDir="$(dirname $0)"
debugTime=""
projectId=""
serviceAccount=""
billingAccountId=""

# usage func
print_usage() {
  echo -e "usage: $selfStr -P <project id> [-h]"
}

# Bash's in-built getopts function to get values from flags
while getopts P:h flag  # If a character is followed by a colon (e.g. P:), that option is expected to have an argument.
do
    case "${flag}" in
      P) projectId="$OPTARG";;
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
	echo -e "$selfStr: ERROR: $1"
  print_usage
	exit 254
}

# Function to print warning message
# $1 = message
printWarnMsg() {
  echo -e "$selfStr: WARN: $1"
}

# Function to print info message
# $1 = message
printInfoMsg() {
  echo -e "$selfStr: INFO: $1"
}

# check required parameters
[[ -z "${projectId}" ]] && printErrMsgAndExit "project ID not provided"

#check if the projectId exists. If not, create one
gcloud projects delete "${projectId}" || printErrMsgAndExit "Unable to delete ${projectId}"