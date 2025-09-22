#!/bin/bash

JENKINS_PID=$(pgrep -f jenkins)
DUMPS_DIR="/var/log/jenkins/thread-dumps"
mkdir -p "$DUMPS_DIR"

function take_thread_dump() {
    local dump_name=$1
    local dump_file="$DUMPS_DIR/threaddump-$dump_name-$(date +%Y%m%d-%H%M%S).txt"
    
    echo "Taking thread dump: $dump_file"
    kill -3 $JENKINS_PID
    
    # Thread dump goes to Jenkins log, extract it
    sleep 2
    tail -n 1000 /var/log/jenkins/jenkins.log | grep -A 1000 "Full thread dump" > "$dump_file"
    
    echo "Thread dump saved: $dump_file"
}

# Take multiple thread dumps to identify stuck threads
echo "Taking thread dumps for stuck build analysis..."
take_thread_dump "first"
sleep 10
take_thread_dump "second" 
sleep 10
take_thread_dump "third"

echo "Analysis complete. Review dumps in: $DUMPS_DIR"
echo "Look for threads in BLOCKED or WAITING state across multiple dumps"