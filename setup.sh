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

info()    { printf "${BLUE}[INFO]${NC} %s\n" "$1"; }
success() { printf "${GREEN}[SUCCESS]${NC} %s\n" "$1"; }
warning() { printf "${YELLOW}[WARNING]${NC} %s\n" "$1"; }
error()   { printf "${RED}[ERROR]${NC} %s\n" "$1"; }

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
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold"

apt-get autoclean -y || warning "apt autoclean skipped."
apt-get clean -y || warning "apt clean skipped."

info "Installing essential packages..."
pkg install -y \
    curl wget git proot tar xz-utils \
    coreutils termux-tools zip unzip \
    openssl findutils grep sed gawk \
    file nano procps

success "Termux packages installed."

# ==========================================================
# STORAGE PERMISSION CHECK
# ==========================================================
if [ ! -d "$HOME/storage/shared" ]; then
    info "Requesting Android storage permission. Please tap 'Allow'..."
    termux-setup-storage || warning "Storage permission command returned an error."
    sleep 4
fi

# ==========================================================
# BACKUP EXISTING CONFIGURATIONS
# ==========================================================
info "Checking for existing configuration files to backup..."

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$HOME/termux_backups/backup_$TIMESTAMP"

if [ -f "$HOME/.bashrc" ] || [ -f "$HOME/.termux/font.ttf" ] || [ -f "$HOME/.termux/colors.properties" ]; then
    mkdir -p "$BACKUP_DIR"

    if [ -f "$HOME/.bashrc" ]; then
        cp "$HOME/.bashrc" "$BACKUP_DIR/.bashrc.bak"
        info "Backed up existing .bashrc to $BACKUP_DIR/.bashrc.bak"
    fi

    if [ -f "$HOME/.termux/font.ttf" ]; then
        cp "$HOME/.termux/font.ttf" "$BACKUP_DIR/font.ttf.bak"
        info "Backed up existing font.ttf"
    fi

    if [ -f "$HOME/.termux/colors.properties" ]; then
        cp "$HOME/.termux/colors.properties" "$BACKUP_DIR/colors.properties.bak"
        info "Backed up existing colors.properties"
    fi

    success "Backup completed successfully."
else
    info "No existing files to back up. Proceeding fresh."
fi

# ==========================================================
# CLONE & APPLY TERMUX CONFIGS
# ==========================================================
info "Cloning Termux-Setup repository..."

cd "$HOME"
if [ -d "mux" ]; then
    warning "'mux' directory already exists. Removing it..."
    rm -rf mux
fi

git clone --depth 1 https://github.com/nurxbd/mux.git
cd mux

mkdir -p "$HOME/.termux"

if [ -f "font.ttf" ]; then
    cp font.ttf "$HOME/.termux/"
else
    warning "font.ttf not found."
fi

if [ -f "colors.properties" ]; then
    cp colors.properties "$HOME/.termux/"
else
    warning "colors.properties not found."
fi

if [ -f "bash" ]; then
    cp bash "$HOME/.bashrc"
else
    warning "bash configuration file not found."
fi

command -v termux-reload-settings >/dev/null 2>&1 && termux-reload-settings || true

# ==========================================================
# PRE-INSTALLATION ROOTFS PREPARATION
# ==========================================================
ROOTFS_NAME="kali-nethunter-rootfs-minimal-arm64.tar.xz"
SDCARD_ROOTFS="/sdcard/mux/$ROOTFS_NAME"
HOME_ROOTFS="$HOME/$ROOTFS_NAME"

info "Checking RootFS image status..."

if [ -f "$HOME_ROOTFS" ]; then
    success "RootFS already exists in home directory ($HOME_ROOTFS). Skipping copy."
else
    info "Copying pre-downloaded NetHunter RootFS image from storage..."
    if [ -f "$SDCARD_ROOTFS" ]; then
        cp -f "$SDCARD_ROOTFS" "$HOME/"
        success "RootFS successfully staged into home directory ($HOME/)."
    else
        error "File not found: $SDCARD_ROOTFS"
        error "Ensure storage access is granted and the file is placed in /sdcard/mux/."
        exit 1
    fi
fi

# ==========================================================
# RUN NETHUNTER INSTALLER
# ==========================================================
cd "$HOME/mux"

if [ -f "install-nethunter.sh" ]; then
    info "Launching install-nethunter.sh from $(pwd)..."
    chmod +x install-nethunter.sh
    bash install-nethunter.sh
else
    error "install-nethunter.sh was not found inside ~/mux/."
    exit 1
fi

