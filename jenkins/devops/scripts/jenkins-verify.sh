#!/bin/bash

JENKINS_URL="http://localhost:8080"
TIMEOUT=300  # 5 minutes

echo "Verifying Jenkins health after restart..."

# Wait for Jenkins to be responsive
start_time=$(date +%s)
while true; do
    if curl -sf "$JENKINS_URL/login" > /dev/null 2>&1; then
        echo "Jenkins is responsive"
        break
    fi
    
    current_time=$(date +%s)
    if [ $((current_time - start_time)) -gt $TIMEOUT ]; then
        echo "ERROR: Jenkins failed to become responsive within $TIMEOUT seconds"
        exit 1
    fi
    
    echo "Waiting for Jenkins to become responsive..."
    sleep 10
done

# Verify agents are connected
echo "Checking agent connectivity..."
OFFLINE_AGENTS=$(java -jar jenkins-cli.jar -s $JENKINS_URL list-nodes | grep "offline" | wc -l)
if [ $OFFLINE_AGENTS -gt 0 ]; then
    echo "WARNING: $OFFLINE_AGENTS agents are offline"
fi

# Verify no critical errors in logs
if journalctl -u jenkins --since "5 minutes ago" | grep -i "error\|exception\|failed" | grep -v "INFO"; then
    echo "WARNING: Errors detected in recent logs"
fi

echo "Health verification completed"