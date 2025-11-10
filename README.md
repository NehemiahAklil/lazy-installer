<div align="center">

# 🚀 Lazy-installer

### _Your install-o-matic solution for bleeding-edge software_

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/Bash-4EAA25?logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Linux](https://img.shields.io/badge/Linux-FCC624?logo=linux&logoColor=black)](https://www.linux.org/)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](http://makeapullrequest.com)

_Automated installation scripts for applications not available in standard package managers_

[Features](#-features) • [Quick Start](#-quick-start) • [Available Installers](#-available-installers) • [Contributing](#-contributing)

</div>

---

## 📖 Overview

Tired of manually downloading, extracting, and updating software that isn't in your package manager? **Lazy-installer** automates the entire process with smart, self-updating installation scripts.

Each script intelligently:

- 🔍 Detects current installations
- 📦 Fetches the latest versions from official sources
- ⚡ Updates only when needed
- 🎨 Integrates seamlessly with your desktop environment

## 🎯 Available Installers

| Application           | Script                | Description                              |
| --------------------- | --------------------- | ---------------------------------------- |
| 🌐 **Helium Browser** | `install-helium.sh`   | Lightweight browser for floating windows |
| 🌊 **Windsurf**       | `install-windsurf.sh` | AI-powered code editor by Codeium        |

## ⚡ Quick Start

### 🎮 Interactive Menu (Recommended)

The easiest way to get started:

```bash
# Clone the repository
git clone https://github.com/yourusername/lazy-installer.git
cd lazy-installer

# Run the interactive menu
chmod +x installer-menu.sh
./installer-menu.sh
```

The menu automatically discovers all available installers and lets you choose what to install!

### 🎯 Individual Scripts

For direct installation:

```bash
# Make the script executable
chmod +x install-helium.sh

# Run the installer
./install-helium.sh
```

## ✨ Features

- 🔄 **Automatic Updates** - Scripts check for latest versions and update intelligently
- 🎯 **Clean Installation** - Properly installs applications to `/opt/` directory
- 🖥️ **Desktop Integration** - Creates desktop entries and menu shortcuts automatically
- 📊 **Version Management** - Tracks installed versions and compares with available updates
- 🧹 **Safe Cleanup** - Automatically cleans up temporary files after installation
- 🎨 **Interactive Menu** - Beautiful CLI menu to choose which app to install
- 🔍 **Auto-Discovery** - Menu automatically finds all available install scripts

## 📋 Requirements

- 🌐 `curl` or `wget` for downloading files
- 🔐 `sudo` privileges for system-wide installation
- 🛠️ Standard Unix utilities (`mktemp`, `grep`, `sed`, etc.)

## 🔧 How It Works

Each installer script follows a smart workflow:

1. 🔍 **Checks** if the application is already installed
2. 📡 **Fetches** the latest version information from official sources
3. ⚖️ **Compares** versions to determine if an update is needed
4. 📥 **Downloads** and extracts the application to `/opt/`
5. 🔗 **Creates** symbolic links and desktop entries
6. 🧹 **Cleans** up temporary files

## 🎨 Adding New Installers

Want to add support for a new application? It's easy!

1. 📝 Create a new script: `install-<appname>.sh`
2. 🏷️ Include a `PKGNAME="<app-name>"` variable at the top
3. 🎯 Follow the existing script structure for consistency
4. ✨ The menu script will automatically discover and include it!

**Example:**

```bash
#!/bin/bash
set -e

PKGNAME="my-awesome-app"
# ... rest of your installation logic
```

## 🔒 Security

- ✅ All scripts use `set -e` to exit on any error
- 🔐 Temporary files are created in secure locations
- 🌐 Downloads are verified from official sources only
- 🛡️ Scripts require explicit sudo permissions

## 🤝 Contributing

Contributions are welcome! Feel free to:

- 🐛 Report bugs
- 💡 Suggest new features
- 🔧 Submit pull requests for new installers
- 📖 Improve documentation

**Please ensure:**

- ✅ Scripts follow the existing naming conventions
- ✅ Include proper error handling
- ✅ Add the `PKGNAME` variable for menu discovery
- ✅ Test installations thoroughly

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

<div align="center">

**Made with ❤️ for the Linux community by Nehemiah Aklil**

⭐ Star this repo if you find it useful!

</div>
