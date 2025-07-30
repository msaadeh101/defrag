#!/bin/bash
set -eou pipefail

demoPrintF () {

    echo "Checking if script passed 2 arguments"
    if [ $# -le 2 ] && [ $# -ne 0 ]; then
        echo -e "You have supplied $# number of arguments which is sufficient\n"
    else
        echo "Needs 2 args"
        exit 1
    fi

    printf "Your arguments are %s and %s.\n" "$1" "$2"

}

demoPrintF "$1" "$2"