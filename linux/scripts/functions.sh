#!/bin/bash
set -eou pipefail

# https://devhints.io/bash#functions

loopWithDollarStar () {
    echo "looping with \$*"
    for arg in $*; do
        echo "$arg"
    done
}

loopWithDollarAt () {
    echo ""
    echo "looping with \$@"
    # "$@" needs to be in quotes
    for arg in "$@"; do
        echo "$arg"
    done
}

loopWithDollarStar "my first" "name" 1
# looping with $*
# my
# first
# name
# 1
# my and first treated as separate entitites

loopWithDollarAt "my first" "name" 1
# looping with $@
# my first 
# name
# 1
# my first treated as one entity