#!/bin/bash

JENKINS_URL="http://localhost:8080"
# ALWAYS BEST to use Jenkins secret manager plugin
JENKINS_TOKEN=$(aws secretsmanager get-secret-value \
   --secret-id jenkins-monitor-token \
   --query SecretString --output text)

AUTH="monitor:${JENKINS_TOKEN}"
TIMEOUT=10

function check_endpoint() {
    local endpoint=$1
    local description=$2
    
    if curl -sf --max-time $TIMEOUT -u "$AUTH" "$JENKINS_URL$endpoint" > /dev/null 2>&1; then
        echo "OK $description: OK"
        return 0
    else
        echo "FAILED $description: FAILED"
        return 1
    fi
}

echo "Jenkins Health Check Report - $(date)"
echo "======================================="

# Basic connectivity
check_endpoint "/login" "Basic connectivity"

# Authentication
check_endpoint "/whoAmI/api/json" "Authentication system"

# Build queue
QUEUE_LENGTH=$(curl -sf -u "$AUTH" "$JENKINS_URL/queue/api/json" | jq '.items | length' 2>/dev/null || echo "unknown")
echo "Build queue length: $QUEUE_LENGTH"

# Agent status
OFFLINE_AGENTS=$(curl -sf -u "$AUTH" "$JENKINS_URL/computer/api/json" | jq '[.computer[] | select(.offline == true)] | length' 2>/dev/null || echo "unknown")
echo "Offline agents: $OFFLINE_AGENTS"

# Recent build failures (last 10 builds)
RECENT_FAILURES=$(curl -sf -u "$AUTH" "$JENKINS_URL/api/json?tree=jobs[name,lastBuild[result]]" | \
    jq -r '.jobs[] | select(.lastBuild.result == "FAILURE") | .name' 2>/dev/null | wc -l)
echo "Jobs with recent failures: $RECENT_FAILURES"