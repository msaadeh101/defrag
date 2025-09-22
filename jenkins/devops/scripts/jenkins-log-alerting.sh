#!/bin/bash

LOG_FILE="/var/log/jenkins/jenkins.log"
ALERT_FILE="/tmp/jenkins-alerts.log"
WEBHOOK_URL="https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"

# Critical error patterns
declare -A ALERT_PATTERNS=(
    ["OutOfMemoryError"]="CRITICAL"
    ["hudson.remoting.ChannelClosedException"]="HIGH"
    ["ExecutorStepExecution\$PlaceholderTask"]="MEDIUM"
    ["java.lang.OutOfMemoryError"]="CRITICAL"
    ["Connection refused"]="HIGH"
    ["Agent went offline during the build"]="HIGH"
    ["Build step.*failed with exception"]="MEDIUM"
    ["ERROR.*Authentication failed"]="HIGH"
)

function send_alert() {
    local message=$1
    local severity=$2
    local timestamp=$(date -Iseconds)
    
    # Log alert
    echo "[$timestamp] $severity: $message" >> "$ALERT_FILE"
    
    # Send to Slack (customize as needed)
    if [[ "$severity" == "CRITICAL" || "$severity" == "HIGH" ]]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"🚨 Jenkins Alert [$severity]: $message\"}" \
            "$WEBHOOK_URL"
    fi
}

# Monitor log file for alerts
tail -F "$LOG_FILE" | while read line; do
    for pattern in "${!ALERT_PATTERNS[@]}"; do
        if echo "$line" | grep -q "$pattern"; then
            send_alert "Pattern detected: $pattern - $line" "${ALERT_PATTERNS[$pattern]}"
        fi
    done
done