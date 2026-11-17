#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

# ==========================================================
# Automated UPGRADE Termux & Kali NetHunter Installer
# Author       : nm✘nur
# Architecture : ARM64
# ==========================================================

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

trap 'rc=$?; error "Installation failed at line $LINENO (exit code: $rc)."; exit "$rc"' ERR

# ==========================================================
# BANNER
# ==========================================================

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

# ==========================================================
# ARCHITECTURE CHECK
# ==========================================================

if [ "$(uname -m)" != "aarch64" ]; then
    error "This installer requires ARM64 architecture."
    exit 1
fi

success "ARM64 architecture detected."

# ==========================================================
# UPDATE TERMUX
# ==========================================================

info "Updating Termux packages..."

pkg update -y
pkg upgrade -y

info "Installing required packages..."

pkg install -y git xz-utils

# ==========================================================
# STORAGE PERMISSION
# ==========================================================

info "Requesting Android storage permission..."

termux-setup-storage || true

SHARED="$HOME/storage/shared"

for _ in {1..20}; do
    [ -d "$SHARED" ] && break
    sleep 1
done

if [ ! -d "$SHARED" ]; then
    error "Android storage permission is unavailable."
    error "Run termux-setup-storage and grant permission."
    exit 1
fi

success "Storage permission verified."

# ==========================================================
# BACKUP CONFIGURATIONS
# ==========================================================

info "Checking existing Termux configurations..."

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$HOME/termux_backups/backup_$TIMESTAMP"

FILES=(
    "$HOME/.bashrc"
    "$HOME/.termux/font.ttf"
    "$HOME/.termux/colors.properties"
)

BACKUP_NEEDED=false

for FILE in "${FILES[@]}"; do
    if [ -f "$FILE" ]; then
        BACKUP_NEEDED=true
        break
    fi
done

if [ "$BACKUP_NEEDED" = true ]; then
    mkdir -p "$BACKUP_DIR"

    [ ! -f "$HOME/.bashrc" ] ||
        cp -f "$HOME/.bashrc" "$BACKUP_DIR/.bashrc.bak"

    [ ! -f "$HOME/.termux/font.ttf" ] ||
        cp -f "$HOME/.termux/font.ttf" "$BACKUP_DIR/font.ttf.bak"

    [ ! -f "$HOME/.termux/colors.properties" ] ||
        cp -f "$HOME/.termux/colors.properties" "$BACKUP_DIR/colors.properties.bak"

    success "Configuration backup completed."
fi

# ==========================================================
# CLONE TERMUX SETUP REPOSITORY
# ==========================================================

REPO_URL="https://github.com/nurxbd/mux.git"
REPO_DIR="$HOME/mux"

info "Preparing Termux Setup repository..."

if [ -d "$REPO_DIR" ]; then

    if [ ! -d "$REPO_DIR/.git" ]; then
        error "~/mux exists but is not a Git repository."
        error "Move or rename it manually before continuing."
        exit 1
    fi

    CURRENT_REMOTE=$(git -C "$REPO_DIR" remote get-url origin)

    if [ "$CURRENT_REMOTE" != "$REPO_URL" ]; then
        error "Existing repository URL does not match."
        error "Existing directory has been preserved."
        exit 1
    fi

    info "Updating existing repository..."
    git -C "$REPO_DIR" pull --ff-only

else
    info "Cloning repository..."
    git clone --depth 1 "$REPO_URL" "$REPO_DIR"
fi

# ==========================================================
# APPLY TERMUX CONFIGURATIONS
# ==========================================================

info "Applying Termux configurations..."

mkdir -p "$HOME/.termux"

if [ -f "$REPO_DIR/font.ttf" ]; then
    cp -f "$REPO_DIR/font.ttf" "$HOME/.termux/font.ttf"
else
    warning "font.ttf not found."
fi

if [ -f "$REPO_DIR/colors.properties" ]; then
    cp -f "$REPO_DIR/colors.properties" "$HOME/.termux/colors.properties"
else
    warning "colors.properties not found."
fi

if [ -f "$REPO_DIR/bash" ]; then
    cp -f "$REPO_DIR/bash" "$HOME/.bashrc"
else
    warning "bash configuration file not found."
fi

if command -v termux-reload-settings >/dev/null 2>&1; then
    termux-reload-settings || warning "Could not reload Termux settings."
fi

success "Termux configurations applied."

# ==========================================================
# ROOTFS PREPARATION
# ==========================================================

ROOTFS_NAME="kali-nethunter-rootfs-minimal-arm64.tar.xz"

SDCARD_ROOTFS="$SHARED/mux/$ROOTFS_NAME"
HOME_ROOTFS="$HOME/$ROOTFS_NAME"

info "Checking NetHunter RootFS image..."

if [ -f "$HOME_ROOTFS" ]; then

    info "RootFS already exists in Termux home."

elif [ -f "$SDCARD_ROOTFS" ]; then

    info "Copying RootFS into Termux home..."

    cp -f "$SDCARD_ROOTFS" "$HOME_ROOTFS"

    success "RootFS copied successfully."

else

    error "NetHunter RootFS image not found."
    error "Expected location: $SDCARD_ROOTFS"
    exit 1

fi

# Verify compressed archive integrity.

info "Verifying RootFS archive..."

xz -t "$HOME_ROOTFS"

success "RootFS archive integrity verified."

# ==========================================================
# RUN NETHUNTER INSTALLER
# ==========================================================

INSTALLER="$REPO_DIR/install-nethunter.sh"

if [ ! -f "$INSTALLER" ]; then
    error "install-nethunter.sh not found."
    exit 1
fi

info "Starting NetHunter installation..."

cd "$REPO_DIR"

bash "$INSTALLER"

success "NetHunter installer finished."

