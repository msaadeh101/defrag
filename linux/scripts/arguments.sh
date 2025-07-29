#!/bin/bash
set -eou pipefail

# Give any arguments in script call

echo "Number of arguments: $#"

echo "All arguments as a single word: '$*'" 
echo "All arguments as separate strings: "$@"" # must be quoted

echo "First argument: $1"

# Running a command before using $_
echo "Hello, World!"
echo "Last argument of the previous command: $_"
