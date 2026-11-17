
#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

# ==========================================================
# AUTOMATED TERMUX SETUP
# Author       : nm✘nur
# Architecture : ARM64
# Repository   : https://github.com/nurxbd/mux.git
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
error()   { printf "${RED}[ERROR]${NC} %s\n" "$1" >&2; }

trap 'rc=$?; error "Failed at line $LINENO (exit code: $rc)."; exit "$rc"' ERR

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
    error "ARM64 architecture required."
    exit 1
fi

success "ARM64 architecture detected."

# ==========================================================
# UPDATE TERMUX
# ==========================================================

info "Updating Termux packages..."

pkg update -y
pkg upgrade -y

# ==========================================================
# INSTALL ESSENTIAL PACKAGES
# ==========================================================

info "Installing essential packages..."

pkg install -y \
    curl wget git proot tar xz-utils \
    coreutils termux-tools zip unzip \
    openssl nano procps

success "Essential packages installed."

# ==========================================================
# ANDROID STORAGE PERMISSION
# ==========================================================

info "Requesting Android storage permission..."

termux-setup-storage || true

SHARED="$HOME/storage/shared"

for _ in {1..20}; do
    [ -d "$SHARED" ] && break
    sleep 1
done

if [ ! -d "$SHARED" ]; then
    error "Storage permission not granted."
    error "Run termux-setup-storage manually."
    exit 1
fi

success "Storage permission granted."

# ==========================================================
# BACKUP EXISTING CONFIGURATIONS
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

else
    info "No existing configurations to back up."
fi

# ==========================================================
# CLONE OR UPDATE MUX REPOSITORY
# ==========================================================

REPO_URL="https://github.com/nurxbd/mux.git"
REPO_DIR="$HOME/mux"

info "Preparing Mux repository..."

if [ -d "$REPO_DIR" ]; then

    if [ ! -d "$REPO_DIR/.git" ]; then
        error "~/mux exists but is not a Git repository."
        error "Rename or move the directory before continuing."
        exit 1
    fi

    CURRENT_REMOTE=$(git -C "$REPO_DIR" remote get-url origin)

    if [ "$CURRENT_REMOTE" != "$REPO_URL" ]; then
        error "Existing repository URL does not match."
        exit 1
    fi

    info "Updating existing Mux repository..."

    git -C "$REPO_DIR" pull --ff-only

else

    info "Cloning Mux repository..."

    git clone --depth 1 "$REPO_URL" "$REPO_DIR"

fi

success "Mux repository ready."

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
# RUN UP-MUX SCRIPT
# ==========================================================

MUX_SCRIPT="$REPO_DIR/up-mux.sh"

if [ ! -f "$MUX_SCRIPT" ]; then
    error "up-mux.sh not found in ~/mux."
    exit 1
fi

info "Starting up-mux.sh..."

bash "$MUX_SCRIPT"

success "up-mux.sh completed successfully."

# ==========================================================
# COMPLETED
# ==========================================================

success "Termux setup completed successfully."

