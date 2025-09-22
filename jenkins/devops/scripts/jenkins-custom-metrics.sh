#!/bin/bash

JENKINS_URL="http://localhost:8080"
# ALWAYS BEST to use Jenkins secret manager plugin
JENKINS_TOKEN=$(aws secretsmanager get-secret-value \
   --secret-id jenkins-monitor-token \
   --query SecretString --output text)

AUTH="monitor:${JENKINS_TOKEN}"
METRICS_FILE="/var/log/jenkins-custom-metrics.log"

while true; do
    TIMESTAMP=$(date +%s)
    
    # Collect queue metrics
    QUEUE_DATA=$(curl -sf -u "$AUTH" "$JENKINS_URL/queue/api/json")
    QUEUE_LENGTH=$(echo "$QUEUE_DATA" | jq '.items | length')
    OLDEST_QUEUE_ITEM=$(echo "$QUEUE_DATA" | jq -r '.items | min_by(.inQueueSince) | .inQueueSince // 0')
    
    # Calculate queue wait time
    if [ "$OLDEST_QUEUE_ITEM" != "0" ]; then
        QUEUE_WAIT_TIME=$((($TIMESTAMP * 1000 - $OLDEST_QUEUE_ITEM) / 1000))
    else
        QUEUE_WAIT_TIME=0
    fi
    
    # Collect executor metrics
    COMPUTER_DATA=$(curl -sf -u "$AUTH" "$JENKINS_URL/computer/api/json")
    TOTAL_EXECUTORS=$(echo "$COMPUTER_DATA" | jq '[.computer[].numExecutors] | add')
    BUSY_EXECUTORS=$(echo "$COMPUTER_DATA" | jq '[.computer[].executors[] | select(.currentExecutable != null)] | length')
    OFFLINE_NODES=$(echo "$COMPUTER_DATA" | jq '[.computer[] | select(.offline == true)] | length')
    
    # Log metrics
    echo "$(date -Iseconds) queue_length=$QUEUE_LENGTH queue_wait_time=$QUEUE_WAIT_TIME total_executors=$TOTAL_EXECUTORS busy_executors=$BUSY_EXECUTORS offline_nodes=$OFFLINE_NODES" >> "$METRICS_FILE"
    
    sleep 30
done