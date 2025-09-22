// vars/buildJavaMicroservice.groovy shared pipeline libraray
def call(Map config) {
    pipeline {
        agent {
            kubernetes {
                yamlFile 'jenkins-pod-template.yaml'
            }
        }
        
        environment {
            DOCKER_REGISTRY = config.dockerRegistry ?: "${env.AWS_ACCOUNT_ID}.dkr.ecr.${env.AWS_DEFAULT_REGION}.amazonaws.com"
            IMAGE_NAME = config.imageName ?: env.JOB_NAME.split('/')[0]
            SONAR_PROJECT_KEY = config.sonarProjectKey ?: env.JOB_NAME
        }
        
        stages {
            stage('Setup') {
                steps {
                    setupBuildEnvironment(config)
                }
            }
            
            stage('Test & Build') {
                parallel {
                    stage('Unit Tests') {
                        steps {
                            runUnitTests(config)
                        }
                    }
                    stage('Integration Tests') {
                        when {
                            anyOf {
                                branch 'main'
                                branch 'develop'
                            }
                        }
                        steps {
                            runIntegrationTests(config)
                        }
                    }
                }
            }
            
            stage('Quality Analysis') {
                steps {
                    runQualityAnalysis(config)
                }
            }
            
            stage('Package & Deploy') {
                when {
                    anyOf {
                        branch 'main'
                        branch 'develop'
                    }
                }
                steps {
                    buildAndDeploy(config)
                }
            }
        }
    }
}

def setupBuildEnvironment(config) {
    script {
        env.GIT_COMMIT_SHORT = sh(
            script: "git rev-parse --short HEAD",
            returnStdout: true
        ).trim()
        
        // Configure Maven settings
        configFileProvider([
            configFile(fileId: 'maven-settings', variable: 'MAVEN_SETTINGS')
        ]) {
            sh 'cp $MAVEN_SETTINGS ~/.m2/settings.xml'
        }
    }
}