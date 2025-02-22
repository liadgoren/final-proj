pipeline {
    agent any

    environment {
        TF_VERSION = "1.6.0"
        TF_DIR = "Terraform"  
        AWS_ACCESS_KEY_ID     = credentials('AWS_ACCESS_KEY_ID')
        AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
    }

    stages {
        stage('Checkout Code') {
            steps {
                git branch: 'main', url: 'https://github.com/hengabay7/Pro-Dev.git'
            }
        }

        stage('Check Terraform Directory') {
            steps {
                script {
                    if (!fileExists(env.TF_DIR)) {
                        error "ERROR: Terraform directory ${env.TF_DIR} not found!"
                    }
                }
            }
        }

        stage('Initialize Terraform') {
             steps {
                dir("${TF_DIR}") {
                    script {
                        def isInitialized = sh(script: "test -d .terraform && echo 'true' || echo 'false'", returnStdout: true).trim()
                        if (isInitialized == 'false') {
                            sh 'terraform init'
                        } else {
                            echo "Terraform is already initialized. Skipping init."
                        }
                    }
                }
            }
        }

        stage('Plan Terraform') {
            steps {
                dir("${TF_DIR}") {
                    
                    sh 'terraform plan -out=tfplan ; pwd'
                }
            }
        }

        stage('Apply Terraform') {
            steps {
                dir("${TF_DIR}") {
                    input message: 'Apply Terraform changes?', ok: 'Apply'
                    sh 'terraform apply -auto-approve tfplan'
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                echo "Building Docker image for branch: ${env.BRANCH_NAME}"
                sh "docker build -t appflask:one ./appflask"
            }
        }

        stage('Test Application') {
            steps {                                  
                echo "Running tests using unittest framework"
                sh 'docker run -t appflask:one sh -c "python3 -m unittest discover -s . -p test_app.py"'
            }
        }                

        stage('Deploy') {
            when {
                branch 'main'
            }
            steps {
                echo "Deploying application from branch: ${env.BRANCH_NAME}"
            }
        }
    }

    post {
        success {
            echo "✅ Pipeline executed successfully!"
        }
        failure {
            echo "❌ Pipeline failed! Check logs for details."
        }
    }
}