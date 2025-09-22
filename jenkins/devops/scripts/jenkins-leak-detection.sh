#!/bin/bash

JENKINS_PID=$(pgrep -f jenkins)
DUMPS_DIR="/var/log/jenkins/heap-dumps"
mkdir -p "$DUMPS_DIR"

echo "Starting memory leak detection for Jenkins PID: $JENKINS_PID"

# Take initial heap dump
echo "Taking initial heap dump..."
jmap -dump:format=b,file="$DUMPS_DIR/initial-$(date +%Y%m%d-%H%M%S).hprof" $JENKINS_PID

# Wait and take second dump
echo "Waiting 30 minutes for heap activity..."
sleep 1800

echo "Taking second heap dump..."
jmap -dump:format=b,file="$DUMPS_DIR/after-30min-$(date +%Y%m%d-%H%M%S).hprof" $JENKINS_PID

echo "Heap dumps generated in: $DUMPS_DIR"
echo "Analyze with Eclipse MAT or similar tool to compare dumps"

# Quick analysis with jhat (if available)
if command -v jhat >/dev/null 2>&1; then
    echo "Starting jhat analysis server on port 7000..."
    echo "Access via http://localhost:7000/"
    jhat -port 7000 "$DUMPS_DIR"/after-30min-*.hprof
fi