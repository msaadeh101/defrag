#!/bin/bash
set -eou pipefail

bashFourArrays () {
    echo "declaring an array with 'declare -A arrayName'"
    echo "This will fail, because we do not have bash 4"
    
    # simulate a try block
    {
        declare -A sounds
    } || {
        # Simulate catch block: if try fails, handle the error
        echo "Error: Associative arrays aren't supported in bash $(bash -version | awk 'NR==1 {print $4}' | cut -d'-' -f1)"
        exit 1
    }
    exit 0
}

# bashFourArrays


keys=("dog" "cow" "bird" "wolf")
values=("bark" "moo" "tweet" "howl")

# Function to get value by key
bashThreeDictionary() {
    local key="$1"
    echo "key is $key"
    echo "The value of \${keys[@]} is: '${keys[@]}'"
    echo "\${values[@]} are '${values[@]}'"
    for i in "${!keys[@]}"; do
        echo "The index of ${keys[i]} item is $i"
        if [[ "${keys[i]}" == "$key" ]]; then
            echo "A ${key[i]} will make a ${values[i]} sound."
            return
        fi
    done
    echo "Key not found"
}

bashThreeDictionary "dog"
