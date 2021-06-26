pipeline {
    agent any

    stages {
        stage('Terraform plan') {
            steps {
                script {
                    withCredentials([
                        string(credentialsId: 'yc_token', variable: 'yc_token'),
                        string(credentialsId: 'cloud_id', variable: 'cloud_id'),
                        string(credentialsId: 'folder_id', variable: 'folder_id'),
                        string(credentialsId: 'ssh_key_pub', variable: 'ssh_key_pub')
                        ]) {
                            sh 'terraform init -input=false'
                            sh 'terraform plan -input=false -out=tfplan -var "yc_token=${yc_token}" -var "yc_cloud_id=${cloud_id}" -var "yc_folder_id=${folder_id}" -var "ssh_key=${ssh_key_pub}"'
                        }
                }
            }
        }

        stage('Deploy yc infra') {
            steps {
                script {
                    withCredentials([
                        string(credentialsId: 'yc_token', variable: 'yc_token'),
                        string(credentialsId: 'cloud_id', variable: 'cloud_id'),
                        string(credentialsId: 'folder_id', variable: 'folder_id'),
                        string(credentialsId: 'ssh_key_pub', variable: 'ssh_key_pub')
                        ]) {
                            sh 'terraform apply -input=false tfplan'
                        }
                }
            }
        }
    }
}