pipeline {

    agent any

    parameters {
        string(
            name: 'IMAGE_TAG',
            defaultValue: '11',
            description: 'Docker image tag to deploy'
        )
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Verify Ansible') {
            steps {
                sh '''
                    ansible --version
                    ansible-playbook --version
                '''
            }
        }

        stage('Test Production Connection') {
            steps {
                sh '''
                    ansible production \
                      -i inventory/hosts.ini \
                      -m ping
                '''
            }
        }

        stage('Deploy') {
            steps {
                sh '''
                    ansible-playbook \
                      -i inventory/hosts.ini \
                      playbooks/deploy.yml \
                      -e "image_tag=${IMAGE_TAG}"
                '''
            }
        }

    }

    post {

        success {
            echo '✅ TaskPulse deployment successful'
        }

        failure {
            echo '❌ TaskPulse deployment failed'
        }

    }
}