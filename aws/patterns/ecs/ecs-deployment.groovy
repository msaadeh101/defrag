// Function that takes env/image tag to deploy
// Call deployToECS within a pipeline stage, pulling from Shared Library
def deployToECS(environment, imageTag) {
    script {
        // Shell command to register new task definition, capturing the ARN as a string
        def taskDefinitionArn = sh(
            script: """
                aws ecs register-task-definition \
                    --cli-input-json file://task-definition-${environment}.json \
                    --region ${AWS_DEFAULT_REGION} \
                    --query 'taskDefinition.taskDefinitionArn' \
                    --output text
            """,
            returnStdout: true
        ).trim() // Remove trailing whitespace/newlines

        echo "Registered task definition: ${taskDefinitionArn}" // Log output

        // Update ECS service task definition
        sh """
            aws ecs update-service \
                --cluster microservice-cluster-${environment} \
                --service microservice-app \
                --task-definition ${taskDefinitionArn} \
                --region ${AWS_DEFAULT_REGION}
        """

        // Wait for deployment to complete in ECS
        sh """
            aws ecs wait services-stable \
                --cluster microservice-cluster-${environment} \
                --services microservice-app \
                --region ${AWS_DEFAULT_REGION}
        """

        // Verify deployment by listing running tasks in ECS service, capturing output
        def runningTasks = sh(
            script: """
                aws ecs list-tasks \
                    --cluster microservice-cluster-${environment} \
                    --service-name microservice-app \
                    --desired-status RUNNING \
                    --region ${AWS_DEFAULT_REGION} \
                    --query 'taskArns' \
                    --output text
            """,
            returnStdout: true
        ).trim()

        echo "Running tasks: ${runningTasks}" // Log running tasks

        // Fail build if no running tasks found
        if (runningTasks.isEmpty()) {
            error("No running tasks found after deployment")
        }
    }
}

// pipeline {
//     agent any
//     stages {
//         stage('Deploy to ECS') {
//             steps {
//                 script {
//                     deployToECS('prod', 'my-image:1.2.3')
//                 }
//             }
//         }
//     }
// }
