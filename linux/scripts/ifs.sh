#!/bin/bash
set -euo pipefail
# -e exit immediately if any command fails
# -u treat unset variables as an error
# -o pipefail, failes the pipeline if any command fails, instead of just the last one
IFS=$'\n\t'
# The IFS variable - which stands for Internal Field Separator 
# controls what Bash calls word splitting.

IFS=$' '
items="a b c"
for x in $items; do
    echo "$x"
done
# prints the following:
# a
# b
# c

IFS=$'\n'
for y in $items; do
    echo "$y"
done
# prints the following:
# a b c

names=(
  "Aaron Maxwell"
  "Wayne Gretzky"
  "David Beckham"
  "Anderson da Silva"
)

IFS=$' '
echo "With default IFS value..."
for name in ${names[@]}; do
  echo "$name"
done

echo ""
echo "With strict-mode IFS value..."
IFS=$'\n\t'
for name in ${names[@]}; do
  echo "$name"
done