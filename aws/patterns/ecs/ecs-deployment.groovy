def deployToECS(environment, imageTag) {
    script {
        // Update ECS service with new task definition
        def taskDefinitionArn = sh(
            script: """
                aws ecs register-task-definition \
                    --cli-input-json file://task-definition-${environment}.json \
                    --region ${AWS_DEFAULT_REGION} \
                    --query 'taskDefinition.taskDefinitionArn' \
                    --output text
            """,
            returnStdout: true
        ).trim()

        echo "Registered task definition: ${taskDefinitionArn}"

        // Update ECS service
        sh """
            aws ecs update-service \
                --cluster microservice-cluster-${environment} \
                --service microservice-app \
                --task-definition ${taskDefinitionArn} \
                --region ${AWS_DEFAULT_REGION}
        """

        // Wait for deployment to complete
        sh """
            aws ecs wait services-stable \
                --cluster microservice-cluster-${environment} \
                --services microservice-app \
                --region ${AWS_DEFAULT_REGION}
        """

        // Verify deployment
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

        echo "Running tasks: ${runningTasks}"
        
        if (runningTasks.isEmpty()) {
            error("No running tasks found after deployment")
        }
    }
}