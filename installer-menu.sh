#!/bin/bash

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'  # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to extract PKGNAME from a script
get_pkgname() {
    local script_file="$1"
    local pkgname
    
    # Extract PKGNAME variable from the script
    pkgname=$(grep -E '^PKGNAME=' "$script_file" | head -1 | cut -d'=' -f2 | tr -d '"\\')
    
    if [[ -z "$pkgname" ]]; then
        # Fallback: derive from filename
        pkgname=$(basename "$script_file" .sh | sed 's/^install-//')
    fi
    
    echo "$pkgname"
}

# Function to discover all install scripts
discover_scripts() {
    local scripts=()
    local pkgnames=()
    
    # Find all install-*.sh scripts in the current directory
    for script in "$SCRIPT_DIR"/install-*.sh; do
        if [[ -f "$script" && -r "$script" ]]; then
            scripts+=("$script")
            pkgnames+=("$(get_pkgname "$script")")
        fi
    done
    
    # Return arrays as space-separated strings
    echo "${scripts[*]}"
    echo "${pkgnames[*]}"
}

# Function to display the menu
show_menu() {
    local scripts=("$@")
    
    echo -e "${CYAN}=====================================${NC}"
    echo -e "${CYAN}    Lazy Installer Menu${NC}"
    echo -e "${CYAN}=====================================${NC}"
    echo ""
    echo -e "${YELLOW}Available installers:${NC}"
    echo ""
    
    for i in "${!scripts[@]}"; do
        local script="${scripts[$i]}"
        local pkgname=$(get_pkgname "$script")
        local script_name=$(basename "$script" .sh)
        
        echo -e "${GREEN}$((i+1)).${NC} ${BLUE}$pkgname${NC} ($script_name)"
    done
    
    echo ""
    echo -e "${GREEN}0.${NC} Exit"
    echo ""
    echo -e "${YELLOW}Select an installer to run (0-${#scripts[@]}):${NC} "
}

# Function to run a script
run_script() {
    local script="$1"
    local pkgname="$2"
    
    echo ""
    echo -e "${CYAN}=====================================${NC}"
    echo -e "${CYAN}Installing $pkgname${NC}"
    echo -e "${CYAN}=====================================${NC}"
    echo ""
    
    # Check if script is executable
    if [[ ! -x "$script" ]]; then
        echo -e "${YELLOW}Making script executable...${NC}"
        chmod +x "$script"
    fi
    
    # Run the script
    if [[ -x "$script" ]]; then
        echo -e "${GREEN}Running: $script${NC}"
        echo ""
        "$script"
        echo ""
        echo -e "${GREEN}Installation completed!${NC}"
    else
        echo -e "${RED}Error: Cannot execute $script${NC}"
        return 1
    fi
}

# Function to get user selection
get_selection() {
    local max_choice="$1"
    local selection
    
    while true; do
        read -r selection
        
        # Check if input is a valid number
        if [[ "$selection" =~ ^[0-9]+$ ]]; then
            if [[ "$selection" -ge 0 && "$selection" -le "$max_choice" ]]; then
                echo "$selection"
                return 0
            fi
        fi
        
        echo -e "${RED}Invalid selection. Please enter a number between 0 and $max_choice:${NC} "
    done
}

# Main function
main() {
    echo -e "${CYAN}Lazy Installer - Interactive Menu${NC}"
    echo ""
    
    # Discover available scripts
    local script_output
    script_output=$(discover_scripts)
    
    # Parse the output (first line: scripts, second line: pkgnames)
    local scripts_string pkgnames_string
    scripts_string=$(echo "$script_output" | head -1)
    pkgnames_string=$(echo "$script_output" | tail -1)
    
    # Convert to arrays
    IFS=' ' read -ra scripts <<< "$scripts_string"
    IFS=' ' read -ra pkgnames <<< "$pkgnames_string"
    
    if [[ ${#scripts[@]} -eq 0 ]]; then
        echo -e "${RED}No install scripts found!${NC}"
        echo -e "${YELLOW}Make sure install-*.sh scripts exist in the current directory.${NC}"
        exit 1
    fi
    
    # Show menu and get selection
    clear
    show_menu "${scripts[@]}"
    
    local selection
    selection=$(get_selection "${#scripts[@]}")
    
    if [[ "$selection" -eq 0 ]]; then
        echo -e "${GREEN}Goodbye!${NC}"
        exit 0
    fi
    
    local script_index=$((selection - 1))
    local selected_script="${scripts[$script_index]}"
    local selected_pkgname="${pkgnames[$script_index]}"
    
    # Run the selected script
    if run_script "$selected_script" "$selected_pkgname"; then
        echo ""
        echo -e "${GREEN}Installation completed successfully!${NC}"
    else
        echo ""
        echo -e "${RED}Installation failed.${NC}"
        exit 1
    fi
}

# Check if running directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
