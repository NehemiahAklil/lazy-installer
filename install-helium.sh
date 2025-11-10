#!/bin/bash

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'  # No Color

# Define variables
PKGNAME="helium-browser"
PKGDIR="/opt/${PKGNAME}"
TEMP_DIR=$(mktemp -d)
GITHUB_API_URL="https://api.github.com/repos/imputnet/helium-linux/releases/latest"
VERSION_FILE="${PKGDIR}/version.txt"
EXECUTABLE_PATH="/usr/bin/helium-browser"
DESKTOP_FILE="/usr/share/applications/helium-browser.desktop"
ICON_TARGET="/usr/share/pixmaps/helium-browser.png"
ICON_HICOLOR="/usr/share/icons/hicolor/256x256/apps/helium-browser.png"

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
    if [[ ! -f "$VERSION_FILE" ]]; then
        echo "0.0.0"
        return
    fi

    local version
    version=$(cat "$VERSION_FILE")
    if [[ -z "$version" ]]; then
        echo "0.0.0"
        return
    fi
    echo "$version"
}

# Fetch and parse download URL and version from GitHub
get_update_info() {
    if ! command -v curl &>/dev/null || ! command -v jq &>/dev/null; then
        echo -e "${RED}Error: curl and jq are required. Install them with: sudo pacman -S curl jq${NC}" >&2
        exit 1
    fi

    echo -e "${GREEN}Checking for updates from GitHub...${NC}" >&2
    local json_response
    json_response=$(curl -s "$GITHUB_API_URL")

    local version
    version=$(echo "$json_response" | jq -r '.tag_name // empty')
    if [[ -z "$version" ]]; then
        echo -e "${RED}Error: Failed to parse version from GitHub API${NC}" >&2
        exit 1
    fi

    local download_url
    download_url=$(echo "$json_response" | jq -r '.assets[] | select(.name | test(".*x86_64\\.AppImage$")) | .browser_download_url' | head -n1)
    if [[ -z "$download_url" ]]; then
        echo -e "${RED}Error: Failed to find x86_64 AppImage in GitHub release${NC}" >&2
        exit 1
    fi

    echo "$version|$download_url"
}

# Download Helium AppImage
download_helium() {
    local download_url="$1"
    if [[ -z "$download_url" ]]; then
        echo -e "${RED}Error: No download URL provided${NC}"
        exit 1
    fi

    echo -e "${GREEN}Downloading Helium from $download_url...${NC}"
    if ! curl -L -f "$download_url" -o "$TEMP_DIR/helium.AppImage"; then
        echo -e "${RED}Error: Failed to download Helium AppImage${NC}"
        exit 1
    fi
}

# Check for required dependencies
check_dependencies() {
    echo -e "${GREEN}Checking for required dependencies...${NC}"
    local dependencies=("fuse2" "curl" "jq")
    local missing_deps=()

    for dep in "${dependencies[@]}"; do
        case $dep in
            "fuse2")
                if ! ldconfig -p | grep -q "libfuse.so.2"; then
                    missing_deps+=("$dep")
                fi
                ;;
            "curl")
                if ! command -v curl &>/dev/null; then
                    missing_deps+=("$dep")
                fi
                ;;
            "jq")
                if ! command -v jq &>/dev/null; then
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

# Install Helium
install_helium() {
    local version="$1"
    echo -e "${GREEN}Installing Helium to $PKGDIR...${NC}"
    sudo mkdir -p "$PKGDIR"
    sudo cp "$TEMP_DIR/helium.AppImage" "$PKGDIR/helium-browser.AppImage"
    sudo chmod 755 "$PKGDIR/helium-browser.AppImage"
    echo "$version" | sudo tee "$VERSION_FILE" >/dev/null
}

# Create launch script
create_launch_script() {
    echo -e "${GREEN}Creating launch script at $EXECUTABLE_PATH...${NC}"
    sudo tee "$EXECUTABLE_PATH" >/dev/null <<'EOF'
#!/bin/bash
set -euo pipefail

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-"$HOME/.config"}"
SYS_CONF="/etc/helium-browser-flags.conf"
USR_CONF="${XDG_CONFIG_HOME}/helium-browser-flags.conf"

FLAGS=()

append_flags_file() {
    local file="$1"
    [[ -r "$file" ]] || return 0
    
    local line safe_line
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*(#|$) ]] && continue
        
        case "$line" in
            *'$('*|*'`'*)
                echo "Warning: ignoring unsafe line in $file: $line" >&2
                continue
                ;;
        esac
        
        set -f
        safe_line=${line//$/\\$}
        safe_line=${safe_line//~/\\~}
        eval "set -- $safe_line"
        set +f
        
        for token in "$@"; do
            FLAGS+=("$token")
        done
    done < "$file"
}

append_flags_file "$SYS_CONF"
append_flags_file "$USR_CONF"

if [[ -n "${HELIUM_USER_FLAGS:-}" ]]; then
    read -r -a ENV_FLAGS <<< "$HELIUM_USER_FLAGS"
    FLAGS+=("${ENV_FLAGS[@]}")
fi

exec /opt/helium-browser/helium-browser.AppImage "${FLAGS[@]}" "$@"
EOF
    sudo chmod 755 "$EXECUTABLE_PATH"
}

# Extract and install icon from AppImage
install_icon() {
    echo -e "${GREEN}Extracting and installing icon...${NC}"
    cd "$TEMP_DIR"
    "$PKGDIR/helium-browser.AppImage" --appimage-extract "*.png" 2>/dev/null || true
    "$PKGDIR/helium-browser.AppImage" --appimage-extract "usr/share/icons/hicolor/*/apps/*.png" 2>/dev/null || true
    "$PKGDIR/helium-browser.AppImage" --appimage-extract ".DirIcon" 2>/dev/null || true
    
    local icon_file=$(find squashfs-root -name "*.png" -type f 2>/dev/null | grep -E "(256x256|product_logo)" | head -n1)
    if [ -z "$icon_file" ]; then
        icon_file=$(find squashfs-root -name "*.png" -type f 2>/dev/null | head -n1)
    fi
    
    if [ -n "$icon_file" ] && [ -f "$icon_file" ]; then
        sudo install -Dm644 "$icon_file" "$ICON_TARGET"
        sudo mkdir -p "$(dirname "$ICON_HICOLOR")"
        sudo install -Dm644 "$icon_file" "$ICON_HICOLOR"
        echo -e "${GREEN}Icon installed successfully${NC}"
    else
        echo -e "${YELLOW}Warning: Could not extract icon from AppImage${NC}"
    fi
}

# Create desktop entry
create_desktop_entries() {
    echo -e "${GREEN}Creating desktop entry...${NC}"
    sudo tee "$DESKTOP_FILE" >/dev/null <<'EOF'
[Desktop Entry]
Version=1.0
Name=Helium Browser
GenericName=Web Browser
Comment=Access the Internet
Exec=helium-browser %U
StartupNotify=true
StartupWMClass=helium
Terminal=false
Icon=helium-browser
Type=Application
Categories=Network;WebBrowser;
MimeType=application/pdf;application/rdf+xml;application/rss+xml;application/xhtml+xml;application/xhtml_xml;application/xml;image/gif;image/jpeg;image/png;image/webp;text/html;text/xml;x-scheme-handler/http;x-scheme-handler/https;
Actions=new-window;new-private-window;

[Desktop Action new-window]
Name=New Window
Exec=helium-browser

[Desktop Action new-private-window]
Name=New Incognito Window
Exec=helium-browser --incognito
EOF

    sudo chmod 644 "$DESKTOP_FILE"
    sudo update-desktop-database || echo -e "${YELLOW}Note: update-desktop-database not available; run manually if needed.${NC}"
}



# Main installation sequence
main() {
    echo -e "${YELLOW}*****************************************************${NC}"
    echo -e "${YELLOW}Helium Browser Installation/Update Script for Linux${NC}"
    echo -e "${YELLOW}*****************************************************${NC}"
    echo ""
    echo "This script will install/update Helium Browser to $PKGDIR with the executable in $EXECUTABLE_PATH."
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
    download_helium "$download_url"
    install_helium "$available_version"
    create_launch_script
    install_icon
    create_desktop_entries

    echo -e "${GREEN}Helium Browser successfully installed/updated to version $available_version!${NC}"
    echo ""
    echo "To run Helium:"
    echo "- From terminal: helium-browser"
    echo "- From menu: Search for 'Helium Browser'"
    echo ""
    echo "Configuration:"
    echo "- System-wide flags: /etc/helium-browser-flags.conf"
    echo "- User flags: ~/.config/helium-browser-flags.conf"
    echo "- Environment variable: HELIUM_USER_FLAGS"
    echo ""
    echo "To update: Re-run this script."
    echo "To uninstall: sudo rm -rf $PKGDIR $EXECUTABLE_PATH $DESKTOP_FILE $ICON_TARGET $ICON_HICOLOR && sudo update-desktop-database"
}

# Run the main function
main
