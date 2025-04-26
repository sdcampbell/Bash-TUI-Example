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
HISTORY_FILE="./.command_runner_history"
touch "$HISTORY_FILE"

# Define common commands with descriptions
# Format: "description :: command"
# Use {PLACEHOLDER} syntax for variables that need to be filled in

# Cross-platform commands
common_commands=(
  "IAM configure cli user credentials :: aws configure"
  "IAM get users, groups, roles, and policies :: aws iam get-account-authorization-details --profile {PROFILE:default}"
  "IAM get current user info :: aws iam get-user --profile {PROFILE:default}"
  "IAM list users :: aws iam list-users"
  "IAM list ssh public keys :: aws iam list-ssh-public-keys --profile {PROFILE:default}"
  "IAM get ssh public key :: aws iam get-ssh-public-key --user-name {USERNAME} --ssh-public-key-id {PUBLIC_KEY_ID} --encoding SSH"
  "IAM get special permissions of user over specific services :: aws iam list-service-specific-credentials --user-name  {USERNAME} --profile {PROFILE:default}"
  "IAM get metadata of user, including permissions boundaries :: aws iam get-user --user-name {USERNAME} --profile {PROFILE:default}"
  "IAM list created access keys :: aws iam list-access-keys --profile {PROFILE:default}"
  "IAM get inline policies of the user :: aws iam list-user-policies --user-name {USERNAME} --profile {PROFILE:default}"
  "IAM get inline policy details :: aws iam get-user-policy --user-name {USERNAME} --policy-name {POLICY_NAME} --profile {PROFILE:default}"
  "IAM get policies of user (it doesn't get inline policies) :: aws iam list-attached-user-policies --user-name {USERNAME} --profile {PROFILE:default}"
  "IAM get groups :: aws iam list-groups --profile {PROFILE:default}"
  "IAM get groups of a user :: aws iam list-groups-for-user --user-name {USERNAME} --profile {PROFILE:default}"
  "IAM get inline policies :: aws iam list-group-policies --group-name {GROUP_NAME} --profile {PROFILE:default}"
  "IAM get inline policy details :: aws iam get-group-policy --group-name {GROUP_NAME} --policy-name {POLICY_NAME} --profile {PROFILE:default}"
  "IAM get attached policies :: aws iam list-attached-group-policies --group-name {GROUP_NAME} --profile {PROFILE:default}"
  "IAM list roles :: aws iam list-roles"
  "IAM get role info :: aws iam get-role --role-name {ROLE_NAME} --profile {PROFILE:default}"
  "IAM list inline policies :: aws iam list-role-policies --role-name {ROLE_NAME} --profile {PROFILE:default}"
  "IAM get inline policy details :: aws iam get-role-policy --role-name {ROLE_NAME} --policy-name {POLICY_NAME} --profile {PROFILE:default}"
  "IAM get attached policies :: aws iam list-attached-role-policies --role-name {ROLE_NAME} --profile {PROFILE:default}"
  "IAM get role instances :: aws iam list-instance-profiles-for-role --role-name {ROLE_NAME} --profile {PROFILE:default}"
  "IAM list policies :: aws iam list-policies [--only-attached] [--scope Local] --profile {PROFILE:default}"
  "IAM get list of policies that give access to the user to the service :: aws iam list-policies-granting-service-access --arn {IDENTITY} --service-namespaces {SERVICE} --profile {PROFILE:default}"
  "IAM get basic policy info :: aws iam get-policy --policy-arn {POLICY_ARN} --profile {PROFILE:default}"
  "IAM list policy versions :: aws iam list-policy-versions --policy-arn {ARN} --profile {PROFILE:default}"
  "IAM get policy version :: aws iam get-policy-version --policy-arn {POLICY_ARN} --version-id {VERSION} --profile {PROFILE:default}"
  "IAM list SAML providers :: aws iam list-saml-providers --profile {PROFILE:default}"
  "IAM get SAML provider :: aws iam get-saml-provider --saml-provider-arn {ARN} --profile {PROFILE:default}"
  "IAM list openid providers :: aws iam list-open-id-connect-providers --profile {PROFILE:default}"
  "IAM get openid provider :: aws iam get-open-id-connect-provider --open-id-connect-provider-arn {ARN} --profile {PROFILE:default}"
  "IAM get my identity :: aws sts get-caller-identity --profile {PROFILE:default}"
  "IAM get user metadata :: aws iam get-user --user-name {USERNAME} --profile {PROFILE:default}"
  "IAM get info about an access key :: aws iam get-access-key-info --access-key-id {ACCESS_KEY_ID} --profile {PROFILE:default}"
  "IAM get last time an access key was used :: aws iam get-access-key-last-used --access-key-id {ACCESS_KEY_ID} --profile {PROFILE:default}"
  "SSO check if IAM Identity Center is used :: aws sso-admin list-instances --profile {PROFILE:default}"
  "SSO get permissions sets :: aws sso-admin list-permission-sets --instance-arn {INSTANCE_ARN} --profile {PROFILE:default}"
  "SSO for each permission set, check the permission set info (managed policies + content) :: aws sso-admin describe-permission-set --instance-arn {INSTANCE_ARN} --permission-set-arn {PERMISSION_SET_ARN} --profile {PROFILE:default}"
  "SSO for each permission set, check the managed policies :: aws sso-admin list-managed-policies-in-permission-set --instance-arn {INSTANCE_ARN} --permission-set-arn {PERMISSION_SET_ARN} --profile {PROFILE:default}"
  "SSO for each permission set, get the inline policy :: aws sso-admin get-inline-policy-for-permission-set --instance-arn {INSTANCE_ARN} --permission-set-arn {PERMISSION_SET_ARN} --profile {PROFILE:default}"
  "SSO get accounts where the identities with that permission set are going to have it :: aws sso-admin list-accounts-for-provisioned-permission-set --instance-arn {INSTANCE_ARN} --permission-set-arn {PERMISSION_SET_ARN} --profile {PROFILE:default}"
  "SSO get users with permission sets :: aws identitystore list-users --identity-store-id {IDENTITY_STORE_ID} --profile {PROFILE:default}"
  "SSO for each user, get the groups :: aws identitystore list-group-memberships-for-member --identity-store-id {IDENTITY_STORE_ID} --member-id UserId={USER_ID} --profile {PROFILE:default}"
  "SSO for each user, check if has Permission Sets directly :: aws sso-admin list-permission-sets-provisioned-to-principal --instance-arn {INSTANCE_ARN} --principal-id {USER_ID} --principal-type USER --profile {PROFILE:default}"
  "SSO for each group, check if has Permission Sets :: aws sso-admin list-permission-sets-provisioned-to-principal --instance-arn {INSTANCE_ARN} --principal-id {GROUP_ID} --principal-type GROUP --profile {PROFILE:default}"
  "SSO for each user/group with a Permission Set, check in which accounts it'll be used :: aws sso-admin list-account-assignments --instance-arn {INSTANCE_ARN} --account-id {ACCOUNT_ID} --permission-set-arn {PERMISSION_SET_ARN} --profile {PROFILE:default}"
)

# Build the commands array based on OS type
commands=("${common_commands[@]}")

# Function to clean input values before processing
clean_input_value() {
    local param_name="$1"
    local param_value="$2"
    local cleaned_value="$param_value"
    
    # Handle special cases based on parameter name
    if [[ "$param_name" == "URL" ]] && [[ "$param_value" == http* ]]; then
        # Extract just the URL, stripping any odd characters that might get appended
        cleaned_value=$(echo "$param_value" | grep -o 'https\?://[^[:space:];]*' || echo "$param_value")
    fi
    
    echo "$cleaned_value"
}

# Very simple placeholder processing function
process_placeholders() {
    local cmd="$1"
    local processed_cmd="$cmd"
    
    # Identify all placeholders in the command
    local all_placeholders=$(echo "$cmd" | grep -o '{[A-Z_]*\(:[^}]*\)*}' || echo "")
    
    # Process each placeholder
    for placeholder in $all_placeholders; do
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
                return 1
            fi
        fi
        
        # Clean the input for specific parameter types (especially URLs)
        input=$(clean_input_value "$name" "$input")
        
        # Replace the placeholder with the input value in the processed command
        # We need to escape both the placeholder and the input value for sed
        placeholder_escaped=$(echo "$placeholder" | sed -e 's/[\/&.^$*[\]]/\\&/g')
        
        # For special characters, we'll use a much simpler approach
        # We create a temporary file for each replacement - slow but reliable
        local tmp_in=$(mktemp)
        local tmp_out=$(mktemp)
        
        # Write current command to file
        echo "$processed_cmd" > "$tmp_in"
        
        # Prepare input file and replacement file
        local tmp_placeholder=$(mktemp)
        local tmp_replacement=$(mktemp)
        echo "$placeholder" > "$tmp_placeholder"
        echo "$input" > "$tmp_replacement"
        
        # Use a robust replacement approach
        awk -v placeholder="$(cat $tmp_placeholder)" -v replacement="$(cat $tmp_replacement)" '{gsub(placeholder, replacement); print}' "$tmp_in" > "$tmp_out"
        
        # Get the processed result
        processed_cmd=$(cat "$tmp_out")
        
        # Clean up all temp files
        rm -f "$tmp_in" "$tmp_out" "$tmp_placeholder" "$tmp_replacement"
    done
    
    # Return the fully processed command
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
            echo "Press Enter to return to menu..."
            read
            return 0
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
    printf "\033[0;33mCommands with {PLACEHOLDERS} will prompt for values before execution\033[0m\n"
    printf "\033[0;33mParameters in [--option {PARAMETER}] are optional and can be skipped\033[0m\n\n"
    
    # Show fzf with preview window showing command details
    selected=$(printf '%s\n' "${commands[@]}" | 
        fzf --height 100% --border --ansi --reverse --preview '
            desc=$(echo {} | cut -d ":" -f1)
            cmd=$(echo {} | sed "s/.*:://; s/^ *//")
            
            # Extract regular and optional placeholders
            regular_placeholders=$(echo "$cmd" | grep -o "{[A-Z_]*\(:[^}]*\)*}" | sort | uniq)
            optional_patterns=$(echo "$cmd" | grep -o "\[\-\-[^ ]* {[A-Z_]*\(:[^}]*\)*}\]" || echo "")
            
            # Extract placeholders from optional patterns
            optional_placeholders=""
            if [ -n "$optional_patterns" ]; then
                for pattern in $optional_patterns; do
                    placeholder=$(echo "$pattern" | grep -o "{[A-Z_]*\(:[^}]*\)*}")
                    # Add extracted placeholder to optional_placeholders
                    optional_placeholders="$optional_placeholders$placeholder
"
                done
            fi
            
            # Filter out optional placeholders from regular placeholders
            required_placeholders=""
            if [ -n "$regular_placeholders" ]; then
                for p in $regular_placeholders; do
                    if ! echo "$optional_placeholders" | grep -q "$p"; then
                        required_placeholders="$required_placeholders$p
"
                    fi
                done
            fi
            
            echo "Description: $(printf "\033[0;33m%s\033[0m" "$desc")"
            echo ""
            echo "Command: $(printf "\033[0;32m%s\033[0m" "$cmd")"
            echo ""
            echo "Required Parameters: "
            if [ -z "$required_placeholders" ]; then
                echo "  None"
            else
                echo "$required_placeholders" | while read p; do
                    if [ -n "$p" ]; then
                        echo "  $(printf "\033[0;34m%s\033[0m" "$p")"
                    fi
                done
            fi
            
            echo ""
            echo "Optional Parameters: "
            if [ -n "$optional_patterns" ]; then
                echo "$optional_patterns" | while read p; do
                    if [ -n "$p" ]; then
                        echo "  $(printf "\033[0;32m%s\033[0m" "$p")"
                    fi
                done
            else
                echo "  None"
            fi
        ' \
            --preview-window=down:40% \
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
    printf "\033[0;34m=== AWS Command Runner Menu (%s) ===\033[0m\n"
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