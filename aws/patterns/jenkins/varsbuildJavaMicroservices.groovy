// vars/buildJavaMicroservice.groovy shared pipeline libraray
def call(Map config) {
    // Defines the main function called automatically when this shared lib is called.
    // config is a Groovy Map, passed with params
    pipeline {
        agent {
            kubernetes {
                yamlFile 'jenkins-pod-template.yaml'
            }
            // Uses an external Kubernetes pod template YAML to spin up Jenkins agents,
            // decoupling pod specs from the pipeline code (better reuse and maintainability).
        }
        
        environment {
            DOCKER_REGISTRY = config.dockerRegistry ?: "${env.AWS_ACCOUNT_ID}.dkr.ecr.${env.AWS_DEFAULT_REGION}.amazonaws.com"
            IMAGE_NAME = config.imageName ?: env.JOB_NAME.split('/')[0]
            SONAR_PROJECT_KEY = config.sonarProjectKey ?: env.JOB_NAME
            // Defines environment variables with defaults if not specified in config map, using Elvis operator ?:
        }
        
        stages {
            stage('Setup') {
                steps {
                    setupBuildEnvironment(config)
                    // Calls local Groovy function to prepare workspace (Git commit hash, config files etc.)
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
        // Injects Maven settings.xml securely in pipeline from Jenkins config files,
        // avoiding hardcoding or exposing sensitive maven configurations.
    }
}