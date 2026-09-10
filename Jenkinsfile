pipeline {

    agent any

    options {
        skipDefaultCheckout(true)
    }

    parameters {
        string(
            name: 'IMAGE_TAG',
            defaultValue: '13',
            description: 'Docker image tag to deploy'
        )
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Validate Parameters') {
            steps {
                script {
                    if (!params.IMAGE_TAG?.trim()) {
                        error('IMAGE_TAG cannot be empty')
                    }

                    echo "Deploying image tag: ${params.IMAGE_TAG}"
                }
            }
        }

        stage('Verify Ansible') {
            steps {
                sh '''
                    echo "=== Ansible Version ==="
                    ansible --version

                    echo "=== Ansible Playbook Version ==="
                    ansible-playbook --version

                    echo "=== Docker Collection ==="
                    ansible-galaxy collection list | grep community.docker || true
                '''
            }
        }

        stage('Test Production Connection') {
    steps {
        sshagent(['taskpluse-prod-ssh']) {
            sh '''
                echo "=== Testing Production SSH with Ansible ==="

                ansible production \
                    -i inventory/hosts.ini \
                    -m ping
            '''
        }
    }
}

        stage('Deploy Production') {
    steps {
        sshagent(['taskpluse-prod-ssh']) {
            sh '''
                echo "================================="
                echo "Deploying TaskPluse API"
                echo "Image tag: ${IMAGE_TAG}"
                echo "================================="

                ansible-playbook \
                    -i inventory/hosts.ini \
                    playbooks/deploy.yml \
                    -e "image_tag=${IMAGE_TAG}"
            '''
        }
    }
}
    }

    post {

        success {
            echo '================================='
            echo '✅ TaskPluse deployment SUCCESS'
            echo '================================='
        }

        failure {
            echo '================================='
            echo '❌ TaskPluse deployment FAILED'
            echo '================================='
        }
    }
}