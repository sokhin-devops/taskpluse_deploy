pipeline {

    agent any

    options {
        skipDefaultCheckout(true)
        timestamps()
    }

    parameters {
        string(
            name: 'IMAGE_TAG',
            defaultValue: '13',
            description: 'Docker image tag to deploy from Nexus'
        )
    }

    environment {
        DEPLOY_HOST = '64.177.41.133'
        DEPLOY_USER = 'root'
        SSH_CREDENTIAL = 'taskpluse-prod-ssh-rsa'
    }

    stages {

        stage('Checkout') {
            steps {
                echo '=== Checkout Deployment Repository ==='

                git(
                    url: 'https://github.com/sokhin-devops/taskpluse_deploy.git',
                    branch: 'main',
                    credentialsId: 'github-taskpluse'
                )
            }
        }

        stage('Validate Parameters') {
            steps {
                script {

                    if (!params.IMAGE_TAG?.trim()) {
                        error('IMAGE_TAG cannot be empty')
                    }

                    echo '================================='
                    echo 'Deployment Information'
                    echo '================================='
                    echo "Image tag: ${params.IMAGE_TAG}"
                    echo "Production host: ${env.DEPLOY_HOST}"
                    echo '================================='
                }
            }
        }

        stage('Verify Ansible') {
            steps {
                sh '''
                    echo "=== Ansible Version ==="
                    ansible --version

                    echo ""
                    echo "=== Ansible Playbook Version ==="
                    ansible-playbook --version

                    echo ""
                    echo "=== Docker Collection ==="
                    ansible-galaxy collection list | grep community.docker || true
                '''
            }
        }

        stage('Test SSH Connection') {
            steps {
                sshagent(["${SSH_CREDENTIAL}"]) {
                    sh '''
                        echo "=== Testing SSH Connection ==="

                        ssh \
                            -o StrictHostKeyChecking=no \
                            ${DEPLOY_USER}@${DEPLOY_HOST} \
                            "echo SSH_OK"

                        echo "SSH connection successful."
                    '''
                }
            }
        }

        stage('Test Ansible Connection') {
            steps {
                sshagent(["${SSH_CREDENTIAL}"]) {
                    sh '''
                        echo "=== Testing Ansible Connection ==="

                        ansible production \
                            -i inventory/hosts.ini \
                            -m ping

                        echo "Ansible connection successful."
                    '''
                }
            }
        }

        stage('Deploy Production') {
            steps {
                sshagent(["${SSH_CREDENTIAL}"]) {
                    sh '''
                        echo "================================="
                        echo "Deploying TaskPluse API"
                        echo "================================="
                        echo "Image tag: ${IMAGE_TAG}"
                        echo "Image:"
                        echo "registry.sokhin.site/docker-hosted/taskpluse-api:${IMAGE_TAG}"
                        echo "================================="

                        ansible-playbook \
                            -i inventory/hosts.ini \
                            playbooks/deploy.yml \
                            -e "image_tag=${IMAGE_TAG}"

                        echo "================================="
                        echo "Deployment command completed"
                        echo "================================="
                    '''
                }
            }
        }

        stage('Verify Production API') {
            steps {
                sshagent(["${SSH_CREDENTIAL}"]) {
                    sh '''
                        echo "=== Checking Production API ==="

                        ssh \
                            -o StrictHostKeyChecking=no \
                            ${DEPLOY_USER}@${DEPLOY_HOST} \
                            "curl -fsS http://127.0.0.1:8082/actuator/health"

                        echo ""
                        echo "Production API health check passed."
                    '''
                }
            }
        }
    }

    post {

        success {
            echo '================================='
            echo '✅ TaskPluse Deployment SUCCESS'
            echo '================================='
            echo "Image deployed: registry.sokhin.site/docker-hosted/taskpluse-api:${IMAGE_TAG}"
        }

        failure {
            echo '================================='
            echo '❌ TaskPluse Deployment FAILED'
            echo '================================='
        }

        always {
            echo '================================='
            echo 'Pipeline finished'
            echo '================================='
        }
    }
}