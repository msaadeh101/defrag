#!/bin/bash

ENVIRONMENT=$1
APP_NAME=$2
NAMESPACE=${3:-$ENVIRONMENT}
TIMEOUT=${4:-300}
INTERVAL=${5:-5}

echo "Starting health check for $APP_NAME in $ENVIRONMENT environment..."

# Get service endpoint
SERVICE_IP=$(kubectl get service $APP_NAME -n $NAMESPACE -o jsonpath='{.spec.clusterIP}')
SERVICE_PORT=$(kubectl get service $APP_NAME -n $NAMESPACE -o jsonpath='{.spec.ports[0].port}')

if [ -z "$SERVICE_IP" ] || [ -z "$SERVICE_PORT" ]; then
    echo "ERROR: Could not retrieve service information"
    exit 1
fi

ENDPOINT="http://${SERVICE_IP}:${SERVICE_PORT}"
echo "Health check endpoint: $ENDPOINT/health"

# Wait for service to be ready
END_TIME=$((SECONDS + TIMEOUT))

while [ $SECONDS -lt $END_TIME ]; do
    if curl -sf "$ENDPOINT/health" > /dev/null 2>&1; then
        echo "Health check passed"
        
        # Additional checks
        if curl -sf "$ENDPOINT/ready" > /dev/null 2>&1; then
            echo "Readiness check passed"
        else
            echo "Warning: Readiness check failed"
        fi
        
        # Check metrics endpoint if available
        if curl -sf "$ENDPOINT/metrics" > /dev/null 2>&1; then
            echo "Metrics endpoint accessible"
        fi
        
        echo "Health check completed successfully"
        exit 0
    else
        echo "Health check failed, retrying in ${INTERVAL}s..."
        sleep $INTERVAL
    fi
done

echo "ERROR: Health check timed out after ${TIMEOUT}s"
exit 1