#!/bin/bash

# Set the timeout for SSH interaction (in seconds)
set_timeout=70  # Timeout for the entire SSH session
step_timeout=4  # Timeout for individual steps

# Define paths for the output file and lock file
output_file="/home/ai/Desktop/AnsibleVS/Ansible_ubuntu/access_details.txt"
lock_file="/tmp/access_details.lock"  # Lock file to prevent race conditions

# Function to handle a single SSH interaction and output extraction
ssh_interaction() {
    local iteration=$1
    local temp_file="/home/ai/Desktop/AnsibleVS/Ansible_ubuntu/temp_data_$iteration.txt"

    # Log output for debugging purposes
    echo "Starting the SSH interaction (Iteration $iteration)." > "$temp_file"

    # Run SSH interaction using `expect`
    expect << EOF
        set timeout $set_timeout
        set step_timeout $step_timeout

        # Log user output directly to the temporary file
        log_file $temp_file
        log_user 1  # Enable logging to the file

        spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@lulz.segfault.net

        # Look for the password prompt
        expect "password:"
        send "segfault\r"
        puts "Step 1: Password sent"

        # Wait for the "Press any key to continue" message
        expect -timeout $set_timeout "Press any key to continue"
        send "\r"
        puts "Step 2: Pressed Enter to continue"

        # Wait for "y" prompt
        expect -timeout $step_timeout
        send "y\r"
        puts "Step 3: Sent 'y'"

        # Capture all output until the session ends
        expect eof
        # End logging
        log_user 0
EOF

    # Notify user that the SSH interaction is done
    echo "SSH interaction completed (Iteration $iteration). Now processing the output."

    # Ensure the temp file exists before processing
    if [ -f "$temp_file" ]; then
        # Extract the SSH command that contains the SECRET
        extracted_ssh_command=$(sed 's/\x1b\[[0-9;]*m//g' "$temp_file" | grep -oP 'ssh -o "SetEnv SECRET=[^"]+" root@lulz.segfault.net')

        # Debugging output to check what was extracted
        if [[ -n "$extracted_ssh_command" ]]; then
            echo "Extracted command: $extracted_ssh_command"
        else
            echo "No command extracted from $temp_file."
        fi

        # Save the SECRET to the output file using a lock file to ensure thread safety during concurrent writes
        {
            flock -x 200
            echo "$extracted_ssh_command" >> "$output_file"
            echo "Extracted SSH command with SECRET saved to $output_file."
        } 200>"$lock_file"

        # Delete the temporary file after extraction (ensures cleanup happens per iteration)
        rm -f "$temp_file"
        echo "Temporary file deleted for iteration $iteration."
    else
        echo "Error: Temporary file for iteration $iteration not found."
    fi
}

# Prompt user for the number of iterations
echo "How many iterations would you like to run?"
read -p "Enter number of iterations: " iterations

# Ensure the input is a positive integer
if ! [[ "$iterations" =~ ^[0-9]+$ ]] || [ "$iterations" -le 0 ]; then
    echo "Invalid input. Please enter a positive number."
    exit 1
fi

# Run multiple iterations concurrently
for (( i=1; i<=iterations; i++ )); do
    echo "Running iteration $i of $iterations..."
    ssh_interaction $i &  # Run the SSH interaction in the background
    sleep 1  # Optional sleep between iterations to avoid resource overload
done

# Wait for all background jobs to finish
wait

echo "All iterations completed successfully."




