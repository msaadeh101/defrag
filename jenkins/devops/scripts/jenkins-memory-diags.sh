#!/bin/bash

JENKINS_PID=$(pgrep -f jenkins)
if [ -z "$JENKINS_PID" ]; then
    echo "Jenkins process not found"
    exit 1
fi

echo "Jenkins PID: $JENKINS_PID"
echo "================================="

# Memory usage summary
echo "=== Memory Usage ==="
jstat -gc $JENKINS_PID

# Heap memory details
echo -e "\n=== Heap Memory ==="
jstat -gccapacity $JENKINS_PID

# GC performance
echo -e "\n=== GC Performance ==="
jstat -gcutil $JENKINS_PID

# Class loading statistics
echo -e "\n=== Class Loading ==="
jstat -class $JENKINS_PID

# Generate heap histogram (top 20 classes by memory usage)
echo -e "\n=== Top Memory Consumers ==="
jmap -histo $JENKINS_PID | head -20

# Heap summary
echo -e "\n=== Heap Summary ==="
jmap -heap $JENKINS_PID