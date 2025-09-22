#!/bin/bash

JENKINS_URL="http://localhost:8080"
CLI_JAR="/var/lib/jenkins/jenkins-cli.jar"
# ALWAYS BEST to use Jenkins secret manager plugin
JENKINS_TOKEN=$(aws secretsmanager get-secret-value \
   --secret-id jenkins-monitor-token \
   --query SecretString --output text)

AUTH="monitor:${JENKINS_TOKEN}"

echo "Pre-restart checks for Jenkins..."

# Check for running builds
RUNNING_BUILDS=$(java -jar $CLI_JAR -s $JENKINS_URL -auth $AUTH list-builds | grep "RUNNING" | wc -l)
if [ $RUNNING_BUILDS -gt 0 ]; then
    echo "WARNING: $RUNNING_BUILDS builds currently running"
    java -jar $CLI_JAR -s $JENKINS_URL -auth $AUTH list-builds | grep "RUNNING"
fi

# Check queue length
QUEUE_LENGTH=$(java -jar $CLI_JAR -s $JENKINS_URL -auth $AUTH queue | wc -l)
echo "Current queue length: $QUEUE_LENGTH"

# Check agent connectivity
echo "Agent status:"
java -jar $CLI_JAR -s $JENKINS_URL -auth $AUTH list-nodes

# Backup critical files before restart
echo "Creating pre-restart backup..."
tar -czf /backup/jenkins-pre-restart-$(date +%Y%m%d-%H%M%S).tar.gz \
  /var/lib/jenkins/config.xml \
  /var/lib/jenkins/jobs/*/config.xml \
  /var/lib/jenkins/users/ \
  /var/lib/jenkins/credentials.xml