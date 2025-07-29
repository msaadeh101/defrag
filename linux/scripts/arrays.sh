#!/bin/bash
set -eou pipefail

# Define an array
Fruits=('Apple' 'Banana' 'Orange')

echo "defining the array: Fruits=('Apple' 'Banana' 'Orange')"

echo "running 'echo "\${Fruits[@]}"'"
echo "${Fruits[@]}"

echo "running 'echo "\${Fruits[0]}"'"
echo "${Fruits[0]}"

echo ""

function workingWithArrays () {
    echo "Running the arrays function..."
    echo "Visit https://devhints.io/bash#arrays for more info"

    echo "Defining Fruits array: Fruits=('Apple' 'Banana' 'Banana')"
    local Fruits=('Apple' 'Banana' 'Banana')

    echo "Running echo \${Fruits[@]} gives all elements, space-separated."
    echo "${Fruits[@]}"

    echo "Running echo \${!Fruits[@]} gives the Keys of all elements, space-separated."
    echo "${!Fruits[@]}"

    echo "Running echo \${#Fruits[2]} gives string length of the 3rd element"
    echo "${#Fruits[@]}"
}

workingWithArrays