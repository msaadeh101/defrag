#!/bin/bash
set -eou pipefail

function conditionalExample() {
    # Check if argument is provided
    if [ $# -eq 0 ]; then
        echo "Error: No argument provided. Provide a string"
        echo "Checkout the conditional docs: https://devhints.io/bash#conditionals"
        exit 1
    fi

    # Assign the first argument to string variable
    string="$1"

    # String
    if [[ -z "$string" ]]; then
        echo "String is empty"
    elif [[ -n "$string" ]]; then
        echo "String is not empty"
    else
        echo "This never happens"
    fi
}

echo "running function 'conditionalExample' with argument 'michael'."
conditionalExample "michael"

echo "running function 'conditionalExample' with argument ''."
conditionalExample ""

echo "running function 'conditionalExample' with no argument"
conditionalExample