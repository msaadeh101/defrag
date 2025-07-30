#!/bin/bash
set -eou pipefail

history_expansion_demo() {
    echo "Running some commands..."
    
    # First command with multiple parameters
    echo "Hello" "World" "Bash"  

    # Demonstrating !$ (last parameter of previous command)
    echo "Last parameter was(!$): !$"  

    # Demonstrating !* (all parameters of previous command)
    echo "All parameters were(!*): !*"  

    # Running another command for !-n demonstration
    echo "This is another test"  

    # Expanding the second last command (!-2)
    echo "Re-running second last command(!-2): !-2"  

    # Running another command to demonstrate !n (nth command in history)
    echo "Another example command"  

    # Expanding 3rd command in history (!3)
    echo "Re-executing command #3 from history(!3): !3"  

    # Running `ls` to demonstrate !<command>
    ls  

    # Expanding most recent ls command
    echo "Re-executing last ls command: !ls"
}

history_expansion_demo
