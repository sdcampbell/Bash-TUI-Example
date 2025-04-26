# Bash-TUI-Example
A starter package for a shell text user interface (TUI) menu. Helpful for occasions where you have a long list of complex commands or want to create a menu of commands so the user simply picks commands to run. Provides the option for the user to enter command variables before running the command, as well as custom commands.

Works on both Bash and Zsh shells on Linux and MacOS.

## Prerequisites
Requires [fzf](https://github.com/junegunn/fzf)

## Usage

### Getting Started
1. Clone this repository:
   ```bash
   git clone https://github.com/sdcampbell/Bash-TUI-Example.git
   cd Bash-TUI-Example
   ```

2. Make the script executable:
   ```bash
   chmod +x tui.sh
   ```

3. Run the script:
   ```bash
   ./tui.sh
   ```

### Navigation and Operation
- The main menu provides four options:
  1. **Search and run commands**: Browse and execute pre-defined commands
  2. **Enter custom command**: Execute a one-time custom command
  3. **Edit command templates**: Modify the list of available commands
  4. **Exit**: Quit the application

- When you select "Search and run commands":
  - Type to filter the command list
  - Use arrow keys to navigate through commands
  - Press Enter to select a command to execute
  - Press ESC to return to the main menu
  - Press CTRL+Y to copy a command to clipboard

### Working with Command Parameters
- Commands can have two types of parameters:
  - **Required parameters**: Enclosed in curly braces `{PARAMETER}`
  - **Parameters with defaults**: Specified as `{PARAMETER:default}`

- When you select a command with parameters:
  1. You'll be prompted to enter values for each parameter
  2. For required parameters, you must enter a value
  3. For parameters with defaults, pressing Enter will use the default value

### Example Commands
The script comes with several built-in command examples:
- File operations (list, find, copy, etc.)
- Network operations (download, SSH, etc.)
- Git operations
- System information commands

### AWS Commands
An AWS-specific version (`awstui.sh`) is also included with AWS CLI commands. Use it the same way:
```bash
chmod +x awstui.sh
./awstui.sh
```

### Customizing Commands
You can customize commands by:
1. Selecting "Edit command templates" from the main menu, or
2. Editing the script directly and modifying the `common_commands` array

Command format: `"Description :: actual command {PARAMETER1} {PARAMETER2:default}"`

## Demo

In this demo, I've used this project to wrap 47 AWS cli commands. This allows them to be easily organized, searched, update variables, and run or copy the resulting command to the clipboard.

[![Demo Video](https://img.youtube.com/vi/op0Pi2EgJW0/0.jpg)](https://www.youtube.com/watch?v=op0Pi2EgJW0)
