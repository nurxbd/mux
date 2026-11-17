#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

# ==========================================================
# Automated Termux & Kali NetHunter Rootless Installer
# Author       : nm✘nur
# Architecture : ARM64
# ==========================================================

# Text Color Codes
BLUE='\033[1;34m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Logging Functions
info() {
    printf "${BLUE}[INFO]${NC} %s\n" "$1"
}

success() {
    printf "${GREEN}[SUCCESS]${NC} %s\n" "$1"
}

warning() {
    printf "${YELLOW}[WARNING]${NC} %s\n" "$1"
}

error() {
    printf "${RED}[ERROR]${NC} %s\n" "$1"
}

clear

printf "${CYAN}"
cat <<'BANNER'
######################################################
#  ____   _ ____    __ __ __ ____   _ __   _ _____   #
# |    \ | |    \  /  |\ ` /|    \ | |  | | |     |  #
# |     \| |     \/   |/   \|     \| |  |_| |     \  #
# |__/\____|__/\__/|__/__/\_|__/\____|______|__|\__\ #
######################################################
BANNER
printf "${NC}\n"

info "Configuring Termux repository..."

if ! command -v termux-change-repo >/dev/null 2>&1; then
    pkg update -y
    pkg install -y termux-tools
fi

if command -v termux-change-repo >/dev/null 2>&1; then
    termux-change-repo || warning "Repository selection skipped or cancelled."
else
    warning "termux-change-repo is unavailable. Using current mirror."
fi

info "Updating Termux packages..."

pkg update -y
pkg upgrade -y

apt autoclean || warning "apt autoclean skipped."
apt clean || warning "apt clean skipped."

info "Installing essential packages..."

pkg install -y \
    curl wget git proot tar xz-utils \
    coreutils termux-tools

pkg install -y \
    zip unzip openssl findutils grep \
    sed gawk which file nano procps

success "Termux packages installed."

info "Requesting Android storage permission..."
termux-setup-storage || warning "Storage permission command returned an error."

# ==========================================================
# BACKUP EXISTING CONFIGURATIONS
# ==========================================================
info "Checking for existing configuration files to backup..."

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$HOME/termux_backups/backup_$TIMESTAMP"
BACKUP_NEEDED=false

if [ -f "$HOME/.bashrc" ] || [ -f "$HOME/.termux/font.ttf" ] || [ -f "$HOME/.termux/colors.properties" ]; then
    BACKUP_NEEDED=true
    mkdir -p "$BACKUP_DIR"
fi

if [ "$BACKUP_NEEDED" = true ]; then
    if [ -f "$HOME/.bashrc" ]; then
        cp "$HOME/.bashrc" "$BACKUP_DIR/.bashrc.bak"
        info "Backed up existing .bashrc to $BACKUP_DIR/.bashrc.bak"
    fi

    if [ -d "$HOME/.termux" ]; then
        [ -f "$HOME/.termux/font.ttf" ] && cp "$HOME/.termux/font.ttf" "$BACKUP_DIR/font.ttf.bak"
        [ -f "$HOME/.termux/colors.properties" ] && cp "$HOME/.termux/colors.properties" "$BACKUP_DIR/colors.properties.bak"
        info "Backed up existing Termux styling files to $BACKUP_DIR/"
    fi
    success "Backup completed successfully."
else
    info "No existing files to back up. Proceeding fresh."
fi
# ==========================================================

info "Cloning Termux-Setup repository..."

# Safely handle pre-existing directory to avoid git clone failures
if [ -d "mux" ]; then
    warning "'mux' directory already exists. Removing it..."
    rm -rf mux
fi

git clone --depth 1 https://github.com/nurxbd/mux.git
cd mux

# Ensure target configuration directories exist
mkdir -p ~/.termux

# Copy configuration files safely
[ -f "font.ttf" ] && cp font.ttf ~/.termux/ || warning "font.ttf not found."
[ -f "colors.properties" ] && cp colors.properties ~/.termux/ || warning "colors.properties not found."
[ -f "bash" ] && cp bash ~/.bashrc || warning "bash configuration file not found."

# ==========================================================
# PRE-INSTALLATION ROOTFS PREPARATION
# ==========================================================
info "Copying pre-downloaded NetHunter RootFS image..."
if [ -f "/sdcard/mux/kali-nethunter-rootfs-minimal-arm64.tar.xz" ]; then
    cp -r /sdcard/mux/kali-nethunter-rootfs-minimal-arm64.tar.xz ~/
    success "RootFS successfully staged into home directory (~/)."
else
    error "File not found: /sdcard/mux/kali-nethunter-rootfs-minimal-arm64.tar.xz"
    error "Please make sure you have allowed storage access and the file is placed correctly."
    exit 1
fi
# ==========================================================

# Run NetHunter installer
if [ -f "install-nethunter.sh" ]; then
    chmod +x install-nethunter.sh
    bash install-nethunter.sh
else
    error "install-nethunter.sh was not found inside the repository."
    exit 1
fi

