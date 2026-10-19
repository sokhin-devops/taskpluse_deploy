// TaskPluse - CD pipeline (Jenkins job 'taskpluse-deploy', defined in
// infra/jenkins/casc.yaml). The CI jobs start it after pushing an image:
//
//   Deploy to staging -> Smoke test staging -> Approve -> Deploy to prod
//                     -> Smoke test prod
//
// Build once, deploy the same image everywhere: prod gets exactly the tag that
// passed staging. Each environment has its own kubeconfig credential, whose
// token can only manage that one namespace.
pipeline {
    agent any

    options {
        timestamps()
        // One deploy at a time - two Helm upgrades of one release would collide.
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '30'))
        timeout(time: 90, unit: 'MINUTES')
    }

    stages {
        stage('Check parameters') {
            steps {
                script {
                    if (!(params.APP in ['api', 'web'])) {
                        error "APP must be api or web, got '${params.APP}'"
                    }
                    // CI tags look like <build number>-<commit>, e.g. 6-32fa074.
                    if (!(params.TAG ==~ /[0-9]+-[0-9a-f]{7,40}/)) {
                        error "TAG must look like 6-32fa074, got '${params.TAG}'"
                    }
                    currentBuild.displayName = "#${env.BUILD_NUMBER} ${params.APP} ${params.TAG}"
                    env.DEPLOYED_BY = "jenkins taskpluse-deploy #${env.BUILD_NUMBER}"
                }
            }
        }

        stage('Deploy to staging') {
            steps {
                deployTo('staging')
            }
        }

        stage('Smoke test staging') {
            steps {
                sh 'bash scripts/smoke-test.sh https://taskpluse-staging.sokhin.site'
            }
        }

        stage('Approve production') {
            steps {
                // A person decides. No answer within an hour = no prod deploy
                // (the build ends as ABORTED; staging keeps the new version).
                timeout(time: 60, unit: 'MINUTES') {
                    input message: "Deploy ${params.APP} ${params.TAG} to production? Staging passed: https://taskpluse-staging.sokhin.site",
                          ok: 'Deploy to production'
                }
            }
        }

        stage('Deploy to prod') {
            steps {
                deployTo('prod')
            }
        }

        stage('Smoke test prod') {
            steps {
                sh 'bash scripts/smoke-test.sh https://taskpluse.sokhin.site'
            }
        }
    }

    post {
        success {
            echo "${params.APP} ${params.TAG} is live in staging and production."
        }
        always {
            cleanWs()
        }
    }
}

// The kubeconfig credential becomes a temporary file; KUBECONFIG points at it
// for this block only, and Jenkins deletes it afterwards.
def deployTo(String environment) {
    withCredentials([file(credentialsId: "kubeconfig-${environment}", variable: 'KUBECONFIG')]) {
        withEnv(["DEPLOY_ENV=${environment}"]) {
            sh 'bash scripts/helm-deploy.sh "$DEPLOY_ENV" "$APP" "$TAG"'
        }
    }
}
