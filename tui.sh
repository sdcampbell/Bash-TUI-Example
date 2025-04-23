#!/usr/bin/env bash
#
# Interactive command runner using fzf (cross-platform for Linux and macOS)
# Allows users to search through available commands and execute them
# Supports command placeholders that can be filled in before execution

# Detect operating system
OS="$(uname -s)"
case "$OS" in
  Linux*)     OS_TYPE="Linux" ;;
  Darwin*)    OS_TYPE="macOS" ;;
  *)          OS_TYPE="Other" ;;
esac

# Check if fzf is installed
if ! command -v fzf &> /dev/null; then
    echo "Error: This script requires fzf to be installed."
    if [ "$OS_TYPE" = "macOS" ]; then
        echo "Please install it with Homebrew: brew install fzf"
    elif [ "$OS_TYPE" = "Linux" ]; then
        echo "Please install it with your package manager:"
        echo "  Ubuntu/Debian: sudo apt install fzf"
        echo "  Fedora: sudo dnf install fzf"
        echo "  Arch: sudo pacman -S fzf"
    fi
    echo "Or visit https://github.com/junegunn/fzf for instructions."
    exit 1
fi

# Create a robust clipboard function that works cross-platform
clipboard_copy() {
    local text="$1"
    
    # Define cross-platform clipboard function
    if [ "$OS_TYPE" = "macOS" ]; then
        echo -n "$text" | pbcopy
        return $?
    elif [ "$OS_TYPE" = "Linux" ]; then
        if command -v xclip &> /dev/null; then
            echo -n "$text" | xclip -selection clipboard
            return $?
        elif command -v wl-copy &> /dev/null; then
            echo -n "$text" | wl-copy
            return $?
        else
            echo "Clipboard error: Please install xclip or wl-copy" >&2
            return 1
        fi
    else
        echo "Clipboard not supported on this OS" >&2
        return 1
    fi
}

# Create a clipboard test function
clipboard_available() {
    if [ "$OS_TYPE" = "macOS" ]; then
        command -v pbcopy &> /dev/null
        return $?
    elif [ "$OS_TYPE" = "Linux" ]; then
        command -v xclip &> /dev/null || command -v wl-copy &> /dev/null
        return $?
    else
        return 1
    fi
}

# File opener command (cross-platform)
if [ "$OS_TYPE" = "macOS" ]; then
    OPEN_CMD="open"
elif [ "$OS_TYPE" = "Linux" ]; then
    OPEN_CMD="xdg-open"
else
    OPEN_CMD="echo 'Opening files not supported on this OS:'"
fi

# Define colors for better readability
export BLUE='\033[0;34m'
export GREEN='\033[0;32m'
export YELLOW='\033[0;33m'
export RED='\033[0;31m'
export NC='\033[0m' # No Color

# Create a temporary file to store command history
HISTORY_FILE="$HOME/.command_runner_history"
touch "$HISTORY_FILE"

# Define common commands with descriptions
# Format: "description :: command"
# Use {PLACEHOLDER} syntax for variables that need to be filled in

# Cross-platform commands
common_commands=(
    "List all files with details :: ls -la"
    "List all files in specified directory :: ls -la {DIRECTORY}"
    "Find files with specific extension :: find . -name \"*.{EXTENSION}\""
    "Search for text pattern recursively :: grep -r \"{PATTERN}\" {DIRECTORY:-.}"
    "Show disk usage :: df -h"
    "Find specific process :: ps aux | grep {PROCESS_NAME}"
    "Monitor system processes :: top"
    "Show size of files and directories :: du -sh *"
    "Show size of files in specified directory :: du -sh {DIRECTORY}/*"
    "Download file from URL to specific location :: curl -o {OUTPUT_FILE} {URL}"
    "Get content from URL :: curl {URL}"
    "Extract tar.gz archive :: tar -xvzf {ARCHIVE_FILE}"
    "Create directory with parents :: mkdir -p {DIRECTORY}"
    "Copy directory recursively :: cp -r {SOURCE} {DESTINATION}"
    "Copy file to remote host :: scp {LOCAL_FILE} {USER}@{HOST}:{REMOTE_PATH}"
    "Connect to remote host :: ssh {USER}@{HOST}"
    "Clone git repository :: git clone {REPOSITORY_URL} {DIRECTORY:-.}"
    "Create and switch to new branch :: git checkout -b {BRANCH_NAME}"
    "Open file with default application :: $OPEN_CMD {FILE}"
)

# macOS specific commands
macos_commands=(
    "Install package with Homebrew :: brew install {PACKAGE_NAME}"
    "Update and upgrade Homebrew packages :: brew update && brew upgrade"
    "Open file with specific application :: open -a {APPLICATION} {FILE}"
    "List disk partitions :: diskutil list"
    "List all network services :: networksetup -listallnetworkservices"
    "Prevent Mac from sleeping for time period :: caffeinate -t {SECONDS}"
    "Take screenshot after delay :: screencapture -T {SECONDS} {FILE_PATH}"
)

# Linux specific commands
linux_commands=(
    "Update package lists :: sudo apt update"
    "Install package with apt :: sudo apt install {PACKAGE_NAME}"
    "Upgrade all packages :: sudo apt upgrade"
    "System information :: lsb_release -a"
    "Install package with dnf :: sudo dnf install {PACKAGE_NAME}"
    "Show systemd service status :: systemctl status {SERVICE_NAME}"
    "Install package with pacman :: sudo pacman -S {PACKAGE_NAME}"
    "Take screenshot :: import -window root {FILE_PATH}"
    "List block devices :: lsblk"
    "Mount a device :: sudo mount /dev/{DEVICE} {MOUNT_POINT}"
    "Network interfaces :: ip addr"
)

# Build the commands array based on OS type
commands=("${common_commands[@]}")

if [ "$OS_TYPE" = "macOS" ]; then
    commands+=("${macos_commands[@]}")
elif [ "$OS_TYPE" = "Linux" ]; then
    commands+=("${linux_commands[@]}")
fi

# Add commands from history (if any)
if [ -f "$HISTORY_FILE" ]; then
    while IFS= read -r line; do
        if ! printf '%s\n' "${commands[@]}" | grep -q "$line"; then
            commands+=("Custom command from history :: $line")
        fi
    done < "$HISTORY_FILE"
fi

# Completely reworked placeholder processing function
process_placeholders() {
    local cmd="$1"
    local processed_cmd="$cmd"
    
    # Create a temporary file for command processing
    local temp_file=$(mktemp)
    echo "$cmd" > "$temp_file"
    
    # Find all placeholders using grep
    local placeholders=$(grep -o '{[A-Z_]*\(:[^}]*\)*}' "$temp_file" || echo "")
    
    if [ -n "$placeholders" ]; then
        # Create temporary list of unique placeholders
        local unique_placeholders=$(echo "$placeholders" | sort -u)
        
        # Process each placeholder interactively
        for placeholder in $unique_placeholders; do
            # Extract name and default value
            local name=$(echo "$placeholder" | sed -E 's/\{([A-Z_]*)(:[^}]*)?\}/\1/')
            local default=$(echo "$placeholder" | sed -E 's/\{[A-Z_]*:([^}]*)\}/\1/' | grep -v "^{" || echo "")
            
            # Use direct terminal input/output to ensure visibility
            if [ -n "$default" ]; then
                # With default value
                printf "Enter value for %s [default: %s]:\n" "$name" "$default" >/dev/tty
                printf "%s > " "$name" >/dev/tty
                
                # Read input directly from terminal
                local input=""
                read -e input </dev/tty
                
                # Use default if nothing entered
                if [ -z "$input" ]; then
                    input="$default"
                fi
            else
                # No default value
                printf "Enter value for %s:\n" "$name" >/dev/tty
                printf "%s > " "$name" >/dev/tty
                
                # Read input directly from terminal
                local input=""
                read -e input </dev/tty
                
                # Require a value
                if [ -z "$input" ]; then
                    printf "Error: A value is required for %s.\n" "$name" >/dev/tty
                    rm "$temp_file"
                    return 1
                fi
            fi
            
            # Escape the input for sed
            input_escaped=$(echo "$input" | sed -e 's/[\/&]/\\&/g')
            placeholder_escaped=$(echo "$placeholder" | sed -e 's/[\/&]/\\&/g')
            
            # Update the processed command
            processed_cmd=$(echo "$processed_cmd" | sed -e "s/$placeholder_escaped/$input_escaped/g")
        done
    fi
    
    # Clean up
    rm "$temp_file"
    
    # Return the processed command
    echo "$processed_cmd"
    return 0
}

# Enhanced function to execute the selected command
execute_command() {
    local selection="$1"
    local cmd="${selection##*::}" # Extract command part after ::
    
    # Trim whitespace
    cmd=$(echo "$cmd" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    
    echo ""  # Add a newline before processing
    
    # Check if the command has placeholders
    if echo "$cmd" | grep -q '{[A-Z_]*\(:[^}]*\)*}'; then
        echo "Command has placeholders that need values:"
        echo ""
    fi
    
    # Process placeholders if any
    processed_cmd=$(process_placeholders "$cmd")
    result=$?
    
    # If processing failed (user didn't provide required value), return
    if [ $result -ne 0 ]; then
        echo "Command execution cancelled. Press Enter to continue..."
        read
        return 1
    fi
    
    echo ""
    echo "Executing: $processed_cmd"
    
    # Offer to copy the processed command to clipboard
    if clipboard_available; then
        echo -n "Press 'c' to copy this command to clipboard or any other key to continue: "
        # Use read with -s to suppress input and -n 1 to read just one character
        read -s -n 1 copy_choice
        echo ""
        if [ "$copy_choice" = "c" ] || [ "$copy_choice" = "C" ]; then
            clipboard_copy "$processed_cmd"
            echo "Command copied to clipboard."
        fi
    fi
    echo ""
    
    # Add to history if it's not already there
    if ! grep -q "^Custom command from history :: $cmd$" "$HISTORY_FILE"; then
        echo "Custom command from history :: $cmd" >> "$HISTORY_FILE"
    fi
    
    # Execute the command in a way that ensures proper terminal handling 
    # and prevents any lingering input from affecting execution
    # Create a temporary script file
    tmp_script=$(mktemp)
    
    # Write the command to the temporary script
    echo "#!/usr/bin/env bash" > "$tmp_script"
    echo "$processed_cmd" >> "$tmp_script"
    
    # Make it executable
    chmod +x "$tmp_script"
    
    # Execute the temporary script
    "$tmp_script"
    local exec_result=$?
    
    # Remove the temporary script
    rm "$tmp_script"
    
    echo ""
    if [ $exec_result -ne 0 ]; then
        echo "Command finished with exit code $exec_result."
    else
        echo "Command completed successfully."
    fi
    
    echo "Press Enter to continue..."
    read
}

# Main function to show the fzf interface
show_fzf_interface() {
    printf "\033[0;34mInteractive Command Runner\033[0m\n"
    printf "\033[0;33mStart typing to search, use arrow keys to navigate, Enter to execute\033[0m\n"
    printf "\033[0;33mCommands with {PLACEHOLDERS} will prompt for values before execution\033[0m\n\n"
    
    # Show fzf with preview window showing command details
    selected=$(printf '%s\n' "${commands[@]}" | 
        fzf --height 40% --border --ansi --reverse --preview '
            desc=$(echo {} | cut -d ":" -f1)
            cmd=$(echo {} | sed "s/.*:://; s/^ *//")
            placeholders=$(echo "$cmd" | grep -o "{[A-Z_]*\(:[^}]*\)*}" || echo "None")
            
            echo "Description: $(printf "\033[0;33m%s\033[0m" "$desc")"
            echo ""
            echo "Command: $(printf "\033[0;32m%s\033[0m" "$cmd")"
            echo ""
            echo "Placeholders: "
            if [ "$placeholders" = "None" ]; then
                echo "None"
            else
                echo "$placeholders" | while read p; do
                    echo "  $(printf "\033[0;34m%s\033[0m" "$p")"
                done
            fi
        ' \
            --preview-window=right:50% \
            --bind "ctrl-y:execute(
                cmd=\$(echo {1} | sed 's/.*:://; s/^ *//');
                echo -n \$cmd > /tmp/fzf_cmd.txt;
                bash -c 'source \"$0\"; OS_TYPE=\"$OS_TYPE\"; clipboard_copy \"\$(cat /tmp/fzf_cmd.txt)\"; rm /tmp/fzf_cmd.txt;
                echo \"Command copied to clipboard: \$(cat /tmp/fzf_cmd.txt)\" >&2; 
                sleep 1' \"$0\"
            )+abort" \
            --header "ESC to exit, CTRL-Y to copy command to clipboard")
    
    if [ -n "$selected" ]; then
        execute_command "$selected"
        return 0
    else
        printf "\n${YELLOW}No command selected. Exiting...${NC}\n"
        return 1
    fi
}

# Allow custom command input
custom_command() {
    # Simple prompt for command input
    printf "Command > "
    read -e cmd
    
    if [ -n "$cmd" ]; then
        execute_command "Custom command :: $cmd"
        return 0
    else
        printf "\nNo command entered. Returning to menu...\n"
        return 1
    fi
}

# Function to edit command templates
edit_templates() {
    local temp_file=$(mktemp)
    
    # Write current commands to temp file
    for cmd in "${commands[@]}"; do
        echo "$cmd" >> "$temp_file"
    done
    
    # Open in default editor (or use nano if EDITOR not set)
    ${EDITOR:-nano} "$temp_file"
    
    # Read back modified commands
    commands=()
    while IFS= read -r line; do
        # Skip empty lines
        [ -n "$line" ] && commands+=("$line")
    done < "$temp_file"
    
    # Clean up
    rm "$temp_file"
    
    printf "\nCommand templates updated. Press Enter to continue...\n"
    read
}

# Main menu
while true; do
    clear
    printf "\033[0;34m=== Command Runner Menu (%s) ===\033[0m\n" "$OS_TYPE"
    printf "1. \033[0;32mSearch and run commands\033[0m\n"
    printf "2. \033[0;32mEnter custom command\033[0m\n"
    printf "3. \033[0;32mEdit command templates\033[0m\n"
    printf "4. \033[0;32mExit\033[0m\n"
    
    read -p "Choose an option (1-4): " choice
    
    case $choice in
        1)
            clear
            show_fzf_interface
            ;;
        2)
            clear
            custom_command
            ;;
        3)
            clear
            edit_templates
            ;;
        4)
            printf "\033[0;33mExiting Command Runner. Goodbye!\033[0m\n"
            exit 0
            ;;
        *)
            printf "\033[0;33mInvalid option. Please try again.\033[0m\n"
            sleep 1
            ;;
    esac
done