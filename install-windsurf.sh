#!/bin/bash

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'  # No Color

# Define variables
PKGNAME="windsurf"
PKGDIR="/opt/${PKGNAME}"
TEMP_DIR=$(mktemp -d)
API_URL="https://windsurf-stable.codeium.com/api/update/linux-x64/stable/latest"
PRODUCT_JSON="${PKGDIR}/resources/app/product.json"
EXECUTABLE_PATH="/usr/bin/windsurf"
DESKTOP_FILE="/usr/share/applications/windsurf.desktop"
DESKTOP_URL="/usr/share/applications/windsurf-url-handler.desktop"
ICON_SOURCE="${PKGDIR}/resources/app/resources/linux/code.png"
ICON_TARGET="/usr/share/pixmaps/windsurf.png"

# Cleanup function
cleanup() {
    echo -e "${YELLOW}Cleaning up temporary files...${NC}"
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Compare two version strings
# Returns 0 if version1 > version2, 1 if version1 < version2, 2 if equal
compare_versions() {
    local version1=$1
    local version2=$2

    if [[ "$version1" == "$version2" ]]; then
        return 2
    fi

    local IFS=.
    local i ver1=($version1) ver2=($version2)

    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++)); do
        ver1[i]=0
    done
    for ((i=${#ver2[@]}; i<${#ver1[@]}; i++)); do
        ver2[i]=0
    done

    for ((i=0; i<${#ver1[@]}; i++)); do
        local v1="${ver1[i]}"
        local v2="${ver2[i]}"
        
        # Default to 0 if empty
        [[ -z "$v1" ]] && v1=0
        [[ -z "$v2" ]] && v2=0
        
        # Strip non-numeric characters and convert to integer
        v1=$(echo "$v1" | sed 's/[^0-9]//g')
        v2=$(echo "$v2" | sed 's/[^0-9]//g')
        [[ -z "$v1" ]] && v1=0
        [[ -z "$v2" ]] && v2=0
        
        if [[ $v1 -gt $v2 ]]; then
            return 0
        fi
        if [[ $v1 -lt $v2 ]]; then
            return 1
        fi
    done
    return 2
}


# Get current installed version
get_current_version() {
    if [[ ! -f "$PRODUCT_JSON" ]]; then
        echo "0.0.0"
        return
    fi

    local version
    version=$(grep -o '"windsurfVersion":[[:space:]]*"[^"]*"' "$PRODUCT_JSON" | cut -d'"' -f4)
    if [[ -z "$version" ]]; then
        echo "0.0.0"
        return
    fi
    echo "$version"
}

# Fetch and parse download URL and version
get_update_info() {
    if ! command -v curl &>/dev/null || ! command -v jq &>/dev/null; then
        echo -e "${RED}Error: curl and jq are required. Install them with: sudo pacman -S curl jq${NC}" >&2
        exit 1
    fi

    echo -e "${GREEN}Checking for updates...${NC}" >&2
    local json_response
    json_response=$(curl -s "$API_URL")

    local version
    version=$(echo "$json_response" | jq -r '.windsurfVersion // empty')
    if [[ -z "$version" ]]; then
        echo -e "${RED}Error: Failed to parse version from API response${NC}" >&2
        exit 1
    fi

    local download_url
    download_url=$(echo "$json_response" | jq -r '.url // empty' | tr -d '[:space:]')
    if [[ -z "$download_url" ]]; then
        echo -e "${RED}Error: Failed to parse download URL from API response${NC}" >&2
        exit 1
    fi

    echo "$version|$download_url"
}

# Download Windsurf package
download_windsurf() {
    local download_url="$1"
    if [[ -z "$download_url" ]]; then
        echo -e "${RED}Error: No download URL provided${NC}"
        exit 1
    fi

    echo -e "${GREEN}Downloading Windsurf from $download_url...${NC}"
    if ! curl -L -f "$download_url" -o "$TEMP_DIR/windsurf.tar.gz"; then
        echo -e "${RED}Error: Failed to download Windsurf package${NC}"
        exit 1
    fi
}

# Check for required dependencies
check_dependencies() {
    echo -e "${GREEN}Checking for required dependencies...${NC}"
    local dependencies=("fontconfig" "gtk3" "python3" "cairo" "nss" "gcc" "libnotify" "glibc" "bash" "curl")
    local missing_deps=()

    for dep in "${dependencies[@]}"; do
        case $dep in
            "glibc")
                if ! command -v ldd &>/dev/null; then
                    missing_deps+=("$dep")
                fi
                ;;
            "python3")
                if ! command -v python3 &>/dev/null; then
                    missing_deps+=("$dep")
                fi
                ;;
            "gcc")
                if ! command -v gcc &>/dev/null; then
                    missing_deps+=("$dep")
                fi
                ;;
            "bash")
                if ! command -v bash &>/dev/null; then
                    missing_deps+=("$dep")
                fi
                ;;
            "curl")
                if ! command -v curl &>/dev/null; then
                    missing_deps+=("$dep")
                fi
                ;;
            *)
                if ! ldconfig -p | grep -q "$dep"; then
                    missing_deps+=("$dep")
                fi
                ;;
        esac
    done

    if [ ${#missing_deps[@]} -eq 0 ]; then
        echo -e "${GREEN}All dependencies satisfied!${NC}"
    else
        echo -e "${RED}Missing dependencies:${NC}"
        for dep in "${missing_deps[@]}"; do
            echo -e "  - $dep"
        done
        echo -e "${YELLOW}Install them with: sudo pacman -S ${missing_deps[*]}${NC}"
        exit 1
    fi
}

# Install Windsurf
install_windsurf() {
    echo -e "${GREEN}Installing Windsurf to $PKGDIR...${NC}"
    sudo mkdir -p "$PKGDIR"
    sudo rm -rf "$PKGDIR"/*  # Overwrite for updates
    sudo tar -xz -C "$PKGDIR" --strip-components=1 -f "$TEMP_DIR/windsurf.tar.gz"
    sudo chmod -R 755 "$PKGDIR"
}

# Create launch script
create_launch_script() {
    echo -e "${GREEN}Creating launch script at $EXECUTABLE_PATH...${NC}"
    sudo tee "$EXECUTABLE_PATH" >/dev/null <<'EOF'
#!/bin/bash
XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-~/.config}

if [[ -f $XDG_CONFIG_HOME/windsurf-flags.conf ]]; then
    readarray -t lines <"$XDG_CONFIG_HOME/windsurf-flags.conf"
    for line in "${lines[@]}"; do
        if ! [[ "$line" =~ ^[[:space:]]*# ]]; then
           CODE_USER_FLAGS+=($line)
        fi
    done
fi

exec /opt/windsurf/bin/windsurf "$@" "${CODE_USER_FLAGS[@]}"
EOF
    sudo chmod 755 "$EXECUTABLE_PATH"
}

# Install icon
install_icon() {
    echo -e "${GREEN}Installing icon...${NC}"
    if [ -f "$ICON_SOURCE" ]; then
        sudo install -Dm644 "$ICON_SOURCE" "$ICON_TARGET"
    else
        echo -e "${YELLOW}Warning: Icon not found at $ICON_SOURCE. Skipping icon installation.${NC}"
    fi
}

# Create desktop entries
create_desktop_entries() {
    echo -e "${GREEN}Creating desktop entries...${NC}"
    sudo tee "$DESKTOP_FILE" >/dev/null <<'EOF'
[Desktop Entry]
Name=Windsurf
Comment=The Open-Source AI-native Editor
GenericName=Text Editor
Exec=/usr/bin/windsurf %F
Icon=windsurf
Type=Application
StartupNotify=false
StartupWMClass=Windsurf
Categories=Utility;Development;Editor;
MimeType=text/plain;inode/directory;
Actions=new-empty-window;
Keywords=vscode;windsurf;

[Desktop Action new-empty-window]
Name=New Empty Window
Exec=/usr/bin/windsurf --new-window %F
Icon=windsurf
EOF

    sudo tee "$DESKTOP_URL" >/dev/null <<'EOF'
[Desktop Entry]
Name=Windsurf - URL Handler
Comment=The Open-Source AI-native Editor
GenericName=Text Editor
Exec=/usr/bin/windsurf --open-url %U
Icon=windsurf
Type=Application
NoDisplay=true
StartupNotify=false
Categories=Utility;TextEditor;Development;Editor;
MimeType=x-scheme-handler/windsurf;
Keywords=vscode;windsurf;
EOF

    sudo chmod 644 "$DESKTOP_FILE" "$DESKTOP_URL"
    if command -v xdg-mime &>/dev/null; then
        xdg-mime default windsurf-url-handler.desktop x-scheme-handler/windsurf
    fi
    sudo update-desktop-database || echo -e "${YELLOW}Note: update-desktop-database not available; run manually if needed.${NC}"
}

# Set permissions for chrome-sandbox
set_permissions() {
    echo -e "${GREEN}Setting chrome-sandbox permissions...${NC}"
    if [ -f "$PKGDIR/chrome-sandbox" ]; then
        sudo chown root "$PKGDIR/chrome-sandbox"
        sudo chmod 4755 "$PKGDIR/chrome-sandbox"
    else
        echo -e "${YELLOW}Warning: chrome-sandbox not found. Skipping permission setup.${NC}"
    fi
}

# Set up shell completions
setup_completions() {
    echo -e "${GREEN}Setting up shell completions...${NC}"
    sudo mkdir -p /usr/share/zsh/site-functions /usr/share/bash-completion/completions
    if [ -f "$PKGDIR/resources/completions/zsh/_windsurf" ]; then
        sudo ln -sf "$PKGDIR/resources/completions/zsh/_windsurf" /usr/share/zsh/site-functions/_windsurf
    fi
    if [ -f "$PKGDIR/resources/completions/bash/windsurf" ]; then
        sudo ln -sf "$PKGDIR/resources/completions/bash/windsurf" /usr/share/bash-completion/completions/windsurf
    fi
}

# Main installation sequence
main() {
    echo -e "${YELLOW}*****************************************************${NC}"
    echo -e "${YELLOW}Windsurf Installation/Update Script for Arch Linux${NC}"
    echo -e "${YELLOW}*****************************************************${NC}"
    echo ""
    echo "This script will install/update Windsurf to $PKGDIR with the executable in $EXECUTABLE_PATH."
    read -rp "Press Enter to continue or Ctrl+C to abort..."

    # Get current and available versions
    local current_version
    current_version=$(get_current_version)

    local update_info
    update_info=$(get_update_info)
    local available_version="${update_info%%|*}"
    local download_url="${update_info#*|}"

    echo -e "${GREEN}Current version: $current_version${NC}"
    echo -e "${GREEN}Available version: $available_version${NC}"

    # Compare versions
    compare_versions "$available_version" "$current_version"
    local compare_result=$?

    if [[ $compare_result -eq 2 ]]; then
        echo -e "${GREEN}You are already running the latest version ($current_version)${NC}"
        exit 0
    elif [[ $compare_result -eq 1 ]]; then
        echo -e "${YELLOW}Warning: Available version ($available_version) is older than installed version ($current_version). Skipping update.${NC}"
        exit 0
    fi

    echo -e "${GREEN}Update available: $current_version → $available_version${NC}"

    check_dependencies
    download_windsurf "$download_url"
    install_windsurf
    create_launch_script
    install_icon
    create_desktop_entries
    set_permissions
    setup_completions

    echo -e "${GREEN}Windsurf successfully installed/updated to version $available_version!${NC}"
    echo ""
    echo "To run Windsurf:"
    echo "- From terminal: windsurf"
    echo "- From menu: Search for 'Windsurf'"
    echo ""
    echo "To update: Re-run this script."
    echo "To uninstall: sudo rm -rf $PKGDIR $EXECUTABLE_PATH $DESKTOP_FILE $DESKTOP_URL $ICON_TARGET /usr/share/zsh/site-functions/_windsurf /usr/share/bash-completion/completions/windsurf && sudo update-desktop-database"
}

# Run the main function
main
