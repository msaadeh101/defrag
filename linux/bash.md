# Bash Basics

- **Bash**, is compatible with `sh` and the vital tool for managing linux machines. One of the main ideas of bash is that everything is a file, and that text streams are the universal interface.

- Linux attaches no special significance to filename extensions. 

- To run a script in debug `bash -x script.sh`

## Common Commands

- `w` or `who` gives all the users running on a machine.

- `rm` Make a habit of using `-i` with a any `rm` command, like `rm -i *` which will check before deleting everything in the current directory.

- `ps` To kill a process, you need the process ID which you can get with `ps`. The `kill` command kills a process based on its PID. `killall` kills a process based on the name.

- Bash I/O operators:
    - `<` for redirecting input to a source OTHER than the keyboard.
    - `>` for redirecting output to destination OTHER than the screen.
    - `>>` for doing the same, but appending rather than overwriting.
    - `|` for piping output from one command into input of another.

## Bash Cheat Sheet

- [Cheat Sheet](https://devhints.io/bash) for quoting, conditionals, variables, brace expansion, functions, loops, ranges, etc.

### Variables

```bash
# assign a variable
variable="Some string"
# Using a variable 
echo "$variable" # => Some string
echo $variable # => Some string
echo '$variable' # => $variable
# '' will NOT expand the variable

# Parameter expansion ${...}:
echo "${variable}" # => Some string
# parameter expansion gets the value of the variable

# String substitution in variables:
echo "${variable/Some/A}" # => A string
# substitute the first occurance of "Some" with "A"

# Sustring from a variable:
length=7
echo "${variable:0:length}" # => Some st (returns only first 7 characters of value)
echo "${variable: -5}" # => tring (last 5 characters)
# Note the space before the -5, space before minus is mandatory

# String Length
echo "${#variable}" # => 11

# Indirect Expansion:
other_variable="variable"
echo ${!other_variable} # => Some string
# This will expand the value of other_variable

# The default value for variable:
echo "${foo:-"DefaultValueIfFooIsMissingOrEmpty"}"
# => DefaultValueIfFooIsMissingOrEmpty
# This works for null (foo=) and empty string (foo=""); zero (foo=0) returns 0.
# Note that it only returns default value and doesn't change variable value.

# Declare an array with 6 elements:
array=(one two three four five six)
# Print first element of array:
echo "${array[0]}"  # => "one"
# Print all elements:
echo "${array[@]}" # => "one two three four five six" 
# Print the number of elements:
echo "${#array[@]}" # => "6"
# Print the number of characters in third element
echo "${#array[2]}" # => "5"
# Print 2 elements starting from fourth:
echo "${array[@]:3:2}" # => "four five"
# Print all elements each of them on new line.
for item in "${array[@]}"; do
    echo "$item"
done

# Built-in variables
# Useful built in variables
echo "Last program's return value: $?"
echo "Script's PID: $$"
echo "Number of arguments passed to script $#"
echo "All arguments passed to script: $@"
echo "Script's arguments separated into different variables: $1 $2 ..."

# Brace Expansion {...}
# used to generate arbitrary strings:
echo {1..10} # => 1 2 3 4 5 6 7 8 9 10
echo {a..z} # => a b c d e f g h i j k l m n o p q r s t u v w x y z
# This will output the range from the start value to the end value.
# Note that you can't use variables here:
from=1
to=10
echo {$from..$to} # => {$from..$to}
```

### Other Bash Basics

```bash
# pwd stands for "print working directory".
# the two below are equivalent, $PWD is the built-in
echo "I'm in $(pwd)" # execs `pwd` and interpolates output
echo "I'm in $PWD" # interpolates the variable

# clear your screen
clear

# Reading a value from input:
echo "what is your name?"
read name
# Note that we did not need to declare a new variable
echo "Hello, $name!"

# We have the usual if structure.
# Condition is true if the value of $name is not equal to the current user's login username:
if [[ "$name" != "$USER" ]]; then
    echo "not equal to username"
else
    echo "equals username"
fi

# To use && and || with if statements, you need multiple pairs of square brackets:
read age
if [[ "$name" == "Steve" ]] && [[ "$age" -eq 15 ]]; then
    echo "This will run if $name is Steve AND $age is 15."
fi

if [[ "$name" == "Daniya" ]] || [[ "$name" == "Zach" ]]; then
    echo "This will run if $name is Daniya OR $name is Zach."
fi

# Other comparison operators:
# -ne - not equal
# -lt - less than
# -gt - greater than
# -le - less than or equal to
# -ge - greater than or equal to

# There is also the `=~` operator, which tests a string against a regex pattern
email=me@example.com
if [[ "$email" =~ [a-z]+@[a-z]{2,}\.(com|net|org) ]]; then
    echo "Valid email"
fi

# There is also conditional execution
echo "Always executed" || echo "Only executed if first command fails" # => Always executed
echo "Always executed" && echo "Only executed if first command does NOT fail"
# => Always executed
# => Only executed if first command does NOT fail

# A single ampersand & after a command runs it in the background
# A background command's output is printed to terminal, but it cannot read from input
sleep 30 &
# List background jobs
jobs
# bring background job to foreground
fg
# Resume a background process after it has been puased with CTL+Z
bg
# Kill job number 2
kill %2
# %1, %2, etc. can be used for fg and bg as well

# redefine command ping as alias to send only 5 packets
alias ping='ping -c 5'
# Escape the alias and use command with name instead
\ping google.com
# Print all aliases
alias -p

# Expressions are denoted:
echo $(( 10 + 5 )) # => 15
```

### Directory and File Manipulation

```bash
# Unlike other programming languages, bash is a shell so it works in the context of cwd

ls # list all files and subdirectories in current dir
ls -l # list every file/dir on separate line
ls -t # Sorts dir contents by last modified descending
ls -$ # Recursive

# Results (stdout) of the previous command can be passed as input (stdin) to the next command
# using a pipe |. Commands chained in this way are called a "pipeline", and are run concurrently.
# The `grep` command filters the input with provided patterns.
# That's how we can list .txt files in the current directory:
ls -l | grep "\.txt"

# Use cat to print files to stdout
cat file.txt

# We can also read the file using cat:
Contents=$(cat file.txt)
# "\n" prints a new line character
# "-e" to interpret the newline escape characters as escape characters
echo -e "START OF FILE\n$Contents\nEND OF FILE"
# => START OF FILE
# => [contents of file.txt]
# => END OF FILE

# Use `cp` to copy files or directories from one place to another.
# `cp` creates NEW versions of the sources,
# so editing the copy won't affect the original (and vice versa).
# Note that it will overwrite the destination if it already exists.
cp srcFile.txt clone.txt
cp -r srcDir/ dst/ # recursively copy

# Use `mv` to move files or directories from one place to another.
# `mv` is similar to `cp`, but it deletes the source.
# `mv` is also useful for renaming files!
mv s0urc3.txt dst.txt # sorry, l33t hackers...

# Use cd to change locations
cd ~ || cd # goes to home dir
cd .. # go up one dir
cd - # go to last dir

# Use subshells to work across directories.
(echo "first im here: $PWD") && (cd someDir; echo "Then im here: $PWD")
pwd # still in first directory.

# mkdir to create new directories
mkdir mynewDir
# -p flag causes new intermediate dirs to be created
mkdir -p myNewDir/with/intermediate/directories
# if the intermediate directories didn't already exist, running the above
# command without the `-p` flag would return an error
```

### Redirection Operators

```bash
# You can redirect command input and output (stdin, stdout, and stderr)
# using "redirection operators". Unlike a pipe, which passes output to a command,
# a redirection operator has a command's input come from a file or stream, or
# sends its output to a file or stream.

# Read from stdin until ^EOF$ and overwrite hello.py with the lines
# between "EOF" (which are called a "here document"):
cat > hello.py << EOF
#!/usr/bin/env python
from __future__ import print_function
import sys
print("#stdout", file=sys.stdout)
print("#stderr", file=sys.stderr)
for line in sys.stdin:
    print(line, file=sys.stdout)
EOF
# Variables WILL BE expanded if the first "EOF" is not quoted

# Run the hello.py script with various stdin, stdout, and stderr redirections:
python hello.py < "input.in" # pass input.in as input to the script

python hello.py > "output.out" # redirect output from script to output.out
# stderr is still shown in terminal

python hello.py 2> "error.err" # redirect error output to error.err
# Normal output (stdout) is stil shown in terminal

python hello.py > "output-and-error.log" 2>&1 # redirect both stdout and stderr to same file
# redirect both output and errors to the output-and-error.log file
# &1 means file descriptor 1 (stdout), so 2>&1 redirects stderr (2) to the current
# destination of stdout (1), which has been redirected to output-and-error.log.

python hello.py > /dev/null 2>&1
# redirect all output and errors to the black hole, /dev/null i.e. no output

# To append to a file, use >>
python hello.py >> "output.out" 2>>  "error.err"

# Overwrite output.out, append to error.err, and count lines
info bash 'Basic Shell Features' 'Redirections' > output.out 2>> error.err
wc -l output.out eror.err

# Run a command and print its file descriptor
echo <(echo "#helloworld")

# overwrite output.out with "#helloworld":
cat > output.out <(echo "#helloworld")
echo "#helloworld" > output.out
echo "#helloworld" | cat > output.out
# echo prints #helloworld to stdout
# cat reads from stdin aka the piped input from echo, and prints to stdout
# > redirects stdout from cat to output.out (creates or overwrites file)
echo "#helloworld" | tee output.out >/dev/null
```

### For Loops and While Loops
```bash
# `for` loops iterate for as many arguments given:
# The contents of $Variable is printed three times.
for Variable in {1..3}
do
    echo "$Variable"
done
# => 1
# => 2
# => 3

# Or write it the traditional for loop way:
for ((a=1; a <=3; a++>))
do
    echo $a
done
# => 1
# => 2
# => 3

# They can also be used to act on files..
# This will run the command `cat` on file1 and file2
for Variable in file1 file2
do
    cat "$Variable"
done

# ..or the output from a command
# This will `cat` the output from `ls`.
for Output in $(ls)
do
    cat "$Output"
done

# Bash can also accept patterns, like this to `cat`
# all the Markdown files in current directory
for Output in ./*.markdown
do
    cat "$Output"
done

# while loop:
while [ true ]; do
    echo "loop body here..."
    break
done
# => loop body here
```

### Functions
```bash
# Defining a function
function foo ()
{
    echo "Arguments work just like script args: $@"
    echo "And: $1 $2..."
    echo "This is a function."
    returnValue=0 # variable values can be returned
    return $returnValue
}

# Call the function `foo` with two arguments, arg1 and arg2:
foo arg1 arg2
# => Arguments work just like script arguments: arg1 arg2
# => And: arg1 arg2...
# => This is a function
# Return values can be obtained with $?
resultValue=$?
# More than 9 arguments are also possible by using braces, e.g. ${10}, ${11}, ...

# or simply
bar ()
{
    echo "Another way to declare functions"
    return 0
}
# call function bar with no arguments
bar #

# Arguments:
# $# gives the number of arguments
# $* all positional args (as a single word)
# $@ All positional args (as separate strings)
# $1 first argument
# $_ last arg of previous command
```

### Other Bash Tips

```bash
# Cleanup temporary files verbosely (add '-i' for interactive)
# WARNING: `rm` commands cannot be undone
rm -v output.out error.err output-and-error.log
rm -r tempDir/ # recursively delete
# You can install the `trash-cli` Python package to have `trash`
# which puts files in the system trash and doesn't delete them directly
# see https://pypi.org/project/trash-cli/ if you want to be careful

# Commands can be substituted with other commands using $( ):
# The following displays the number of files and directories in the current directory
echo "There are $(ls | wc -l) items here."

# Bash uses a case statement that works similarly to Java and C++
case "$Variable" in
    # List patterns for the conditions you want to meet
    0) echo "There is a zero.";;
    1) echo "There is a one.";;
    *) echo "it is not null";; # match everything else
esac
# case supports pattern matching instead of 0) it can be [aA])

# `sudo` is used to perform commands as the superuser
# usually it will ask interactively the password of superuser
NAME1=$(whoami)
NAME2=$(sudo whoami)
echo "Was $NAME1, then became more powerful $NAME2"
```
### Sed / Grep / trap

```bash
# print last 10 lines of file.txt
tail -n 10 file.txt

# print first 10 lines of file.txt
head -n 10 file.txt

# print file.txt lines sorted order
sort file.txt

# report or omit repeated lines with -d it reports them
uniq -d file.txt

# prints only first column before ',' character
cut -d ',' -f 1 file.txt

# replaces every occurance of 'okay' with 'great' in file.txt (regex compatible)
sed -i 's/okay/great/g' file.txt
# -i flag means that file.txt will be changed
# -i or --in-place erase the input file (use --in-place=.backup to keep a back-up)

# print to stdout all lines of file.txt which match some regex
# The example prints lines which begin with "foo" and end in "bar"
grep "^foo.*bar$" file.txt

# pass the option "-c" to instead print the number of lines matching the regex
grep -c "^foo.*bar$" file.txt

# Other useful options are:
grep -r "^foo.*bar$" someDir/ # recursively `grep`
grep -n "^foo.*bar$" file.txt # give line numbers
grep -rI "^foo.*bar$" someDir/ # recursively `grep`, but ignore binary files

# perform the same initial search, but filter out the lines containing "baz"
grep "^foo.*bar$" file.txt | grep -v "baz

# if you literally want to search for the string,
# and not the regex, use fgrep (or grep -F)
fgrep "foobar" file.txt

# The `trap` command allows you to execute a command whenever your script
# receives a signal. Here, `trap` will execute `rm` if it receives any of the
# three listed signals.
trap "rm $TEMP_FILE; exit" SIGHUP SIGINT SIGTERM
```

### Wildcards/Regex

- Bash Wildcards: 
    - `*` as in `ls *.jpg *.jpeg || ls *.jp*g` to match 0+ characters.
    - `?` as in `ls 00?.jpg` matches a single character.
    - `[]` as in `ls *.[jp]*` which matches anything with a period followed by lowercase j OR p.
    - Filenames are case sensitive, so `ls *.[jpJP]*` could be necessary.
    - `ls [A-Z]*` lists all files in current dir that begin with an uppercase letter.
    - `ls [a-zA-Z]*` lists all files in current dir that begin with uppercase or lowercase.
