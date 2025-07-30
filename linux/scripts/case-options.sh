#!/bin/bash
set -eou pipefail

getOptions () {
    local version="1.0.0"

    while [[ $# -gt 0 ]]; do
        case $1 in
        -V | --version )
            echo "$version"
            exit
            ;;
        -s | --string )
            shift
            if [[ $# -gt 0 ]]; then
                string=$1
                echo "string passed: $string"
            else
                echo "Error: -s or --string requires an argument."
                exit 1
            fi
            ;;
        -f | --flag )
            flag=1
            echo "flag set"
            ;;
        -- )
            shift
            break
            ;;
        * )
            echo "Error: Unknown option $1"
            exit 1
            ;;
        esac
        shift
    done
}

# Call the function with the arguments
getOptions "$@"
