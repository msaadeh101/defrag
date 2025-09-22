#!/bin/bash

JENKINS_URL="http://localhost:8080"
# ALWAYS BEST to use Jenkins secret manager plugin
JENKINS_TOKEN=$(aws secretsmanager get-secret-value \
   --secret-id jenkins-monitor-token \
   --query SecretString --output text)

AUTH="monitor:${JENKINS_TOKEN}"

METRICS_FILE="/var/log/jenkins/build-performance.log"

# Infinite monitoring loop, runs until manually killed or system shut down
while true; do
    TIMESTAMP=$(date -Iseconds)
    
    # Get running builds, use jq for structured json data
    RUNNING_BUILDS=$(curl -sf -u "$AUTH" "$JENKINS_URL/api/json?tree=jobs[name,lastBuild[building,duration,estimatedDuration]]" | \
        jq -r '.jobs[] | select(.lastBuild.building == true) | "\(.name),\(.lastBuild.duration),\(.lastBuild.estimatedDuration)"')
    
    # If string is --non-empty
    if [ -n "$RUNNING_BUILDS" ]; then
        while IFS= read -r build; do # IFS disables word splitting, critical for CSV
            JOB_NAME=$(echo "$build" | cut -d',' -f1) # split by comman and extract field number 1
            DURATION=$(echo "$build" | cut -d',' -f2)
            ESTIMATED=$(echo "$build" | cut -d',' -f3)
            
            # Check if build is taking longer than expected
            if [ "$DURATION" -gt "$((ESTIMATED * 2))" ]; then
                echo "[$TIMESTAMP] SLOW_BUILD: $JOB_NAME running ${DURATION}ms (estimated ${ESTIMATED}ms)" >> "$METRICS_FILE"
            fi
        done <<< "$RUNNING_BUILDS" # here-string feeds the multi-line string into the loop
    fi
    
    # Check for long-running builds (>2 hours)
    LONG_BUILDS=$(curl -sf -u "$AUTH" "$JENKINS_URL/api/json?tree=jobs[name,lastBuild[building,duration]]" | \
        jq -r '.jobs[] | select(.lastBuild.building == true and .lastBuild.duration > 7200000) | .name')
    
    if [ -n "$LONG_BUILDS" ]; then
        echo "[$TIMESTAMP] LONG_RUNNING_BUILDS: $LONG_BUILDS" >> "$METRICS_FILE"
    fi
    
    sleep 300  # Check every 5 minutes
done