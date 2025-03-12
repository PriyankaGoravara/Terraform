pipeline {
    parameters {
        booleanParam(name: 'autoApprove', defaultValue: false, description: 'Automatically run apply after generating plan?')
    } 
    
    agent any

    stages {
        stage('Checkout') {
            steps {
                script {
                    dir("terraform") {
                        git branch: 'main', url: "https://github.com/PriyankaGoravara/Terraform.git"
                    }
                }
            }
        }

        stage('Setup Credentials') {
            steps {
                withCredentials([
                    string(credentialsId: 'AWS_ACCESS_KEY_ID', variable: 'AWS_ACCESS_KEY_ID'),
                    string(credentialsId: 'AWS_SECRET_ACCESS_KEY', variable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
                    script {
                        env.AWS_ACCESS_KEY_ID = AWS_ACCESS_KEY_ID
                        env.AWS_SECRET_ACCESS_KEY = AWS_SECRET_ACCESS_KEY
                    }
                }
            }
        }

        stage('Terraform Init & Plan') {
            steps {
                withEnv([
                    "AWS_ACCESS_KEY_ID=${env.AWS_ACCESS_KEY_ID}",
                    "AWS_SECRET_ACCESS_KEY=${env.AWS_SECRET_ACCESS_KEY}"
                ]) {
                    dir("terraform") {
                        sh 'terraform init'
                        sh 'terraform workspace select default || terraform workspace new default'
                        sh 'terraform plan -var-file=terraform.tfvars -out=tfplan'
                        sh 'terraform show -no-color tfplan > tfplan.txt'
                    }
                }
            }
        }

        /* stage('Approval') {
            when {
                not { equals expected: true, actual: params.autoApprove }
            }
            steps {
                script {
                    def plan = readFile 'terraform/tfplan.txt'
                    input message: "Do you want to apply the plan?",
                    parameters: [text(name: 'Plan', description: 'Please review the plan', defaultValue: plan)]
                }
            }
        } */

        stage('Terraform Apply') {
            steps {
                withEnv([
                    "AWS_ACCESS_KEY_ID=${env.AWS_ACCESS_KEY_ID}",
                    "AWS_SECRET_ACCESS_KEY=${env.AWS_SECRET_ACCESS_KEY}"
                ]) {
                    dir("terraform") {
                        sh 'terraform apply -input=false -auto-approve tfplan | tee apply.log'
                    }
                }
            }
            post {
                failure {
                    script {
                        echo "Terraform Apply failed! Check apply.log"
                        sh 'cat terraform/apply.log'
                    }
                }
            }
        }
    }
}
