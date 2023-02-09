pipeline{
    agent {
        label 'jenkins-agent'
    }

    environment {
        PROJECT_ID                       = "a-demo-dev"
        REGION                           = "asia-south1"
        ZONE                             = "asia-south1-a"
        CLUSTER_NAME                     = "private-cluster"
        JUMPHOST_NAME                    = "private-cluster-jumphost"
        GOOGLE_APPLICATION_CREDENTIALS   = credentials("terraform-service-account-key") 
    }

    stages {
        stage('Checkout Source'){
            steps{
                git branch: 'main', url: 'https://github.com/firoagni/gke-terraform-3tier.git'
            }
        }
        stage('GCP Login'){
            steps{
                    sh "gcloud auth activate-service-account --key-file=${GOOGLE_APPLICATION_CREDENTIALS}"
                    sh "gcloud config set core/project ${env.PROJECT_ID}"
                    sh "gcloud config set compute/zone ${env.ZONE}"
                    sh "gcloud config set compute/region ${env.REGION}"
            }
        }
        stage('Spin-up Infrastructure') {
            environment{
                TFSTATE_BUCKET         = "${ADMIN_PROJECT_ID}-terraform-state"
                TFSTATE_BUCKET_PREFIX  = "${params.env}/state"
                
                //variables for Terraform
                TF_VAR_project_id      = "${PROJECT_ID}"
                TF_VAR_region          = "${REGION}"
                TF_VAR_jumphost_zone   = "${ZONE}"
                TF_VAR_cluster_name    = "${CLUSTER_NAME}"
                TF_VAR_jumphost_name   = "${JUMPHOST_NAME}" 
            }
            steps {
                container("terraform"){
                    dir("terraform") {
                        sh "terraform init -backend-config=\"bucket=${TFSTATE_BUCKET}\" -backend-config=\"prefix=${TFSTATE_BUCKET_PREFIX}\" -input=false"
                        // sh "terraform plan"
                        sh "terraform apply -input=false -auto-approve"
                   }
                }
            }
        }
        stage('Deploy Application') {
            steps {
                container("kubernetes"){
                    sh "gcloud container clusters get-credentials ${CLUSTER_NAME} --internal-ip --project ${PROJECT_ID} --region ${REGION}" 
                    sh "gcloud compute ssh ${JUMPHOST_NAME} --project ${PROJECT_ID} --zone ${ZONE} --tunnel-through-iap --  -L 8888:127.0.0.1:8888 -N -q -f"

                    sh "HTTPS_PROXY=localhost:8888  kubectl apply -f ./k8s"
                }
            }
        }
    }
}