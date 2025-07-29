#!/bin/bash
set -eou pipefail

function numericCalculation () {
    echo "Running a numeric Function..."
    local a=1
    declare -i count
    count=1

    for i in {1..3}; do
        if [[ $count -le 3 ]]; then
            ((count+=1))
            echo "Count inside the for loop is $count"
        else
            echo "Count has reached $count, that is too high"
        fi
    done

    math=$((a + count + 200))

    echo -e "After doing some math, a number is: $math\n"
}

numericCalculation

stringManipulation () {

    listWithSlashN=$(cat <<EOF
    1. Alice\n2. Bob\n3. Charlie\n4. Annie\n5. Alice\n
EOF
)

    echo ""
    echo "Unaltered list created using EOF is: "
    echo -e "$listWithSlashN"
    echo "This was echoed using -e to interpret escape sequences"
    echo ""

    list="1. Brown\n2. How\n3. Cow"

    echo "new list is: "
    echo "$list"
    echo ""

    allUpper=$(echo -e "$list" | tr '[:lower:]' '[:upper:]')

    echo "All Upper using tr '[:lower:]' '[:upper:]'"
    echo "$allUpper"
}

echo "Running string Manipulation..."

stringManipulation