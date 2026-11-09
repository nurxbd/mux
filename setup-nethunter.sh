
#!/usr/bin/env bash

set -Eeuo pipefail

# ==========================================
# KALI NETHUNTER COMPLETE SETUP
# 1. Metasploit Framework
# 2. BeEF-XSS
# 3. Ruby Dependencies
# 4. Git
# ==========================================

GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ==========================================
# Error Handling
# ==========================================

trap 'error "Failed at line $LINENO. Exit code: $?"' ERR

# ==========================================
# Root Detection
# ==========================================

if [ "$EUID" -eq 0 ]; then
    SUDO=""
else
    if ! command -v sudo >/dev/null 2>&1; then
        error "Root or sudo access required."
        exit 1
    fi

    SUDO="sudo"
fi

# ==========================================
# Kali NetHunter Home Directory
# ==========================================

KALI_HOME="/home/kali"

if [ ! -d "$KALI_HOME" ]; then
    error "Kali home directory not found: $KALI_HOME"
    exit 1
fi

info "Kali Home: $KALI_HOME"

# ==========================================
# 1. Update and Upgrade
# ==========================================

info "Updating Kali repositories..."
$SUDO apt update

info "Upgrading Kali packages..."
$SUDO apt upgrade -y

success "System update completed."

# ==========================================
# 2. Install Metasploit Framework
# ==========================================

info "Installing Metasploit Framework..."
$SUDO apt install -y metasploit-framework

success "Metasploit Framework installed."

# ==========================================
# 3. Initialize Metasploit Database
# ==========================================

info "Initializing Metasploit database..."

if $SUDO msfdb init; then
    success "Metasploit database initialized."
else
    info "Database initialization failed."
    info "PostgreSQL may not be available in Rootless NetHunter."
fi

# ==========================================
# 4. Install BeEF Dependencies
# One by One
# ==========================================

PACKAGES=(
    ruby-msgpack
    ruby-dev
    build-essential
    libsqlite3-dev
    bundler
    pkg-config
    libyaml-dev
    libssl-dev
)

for pkg in "${PACKAGES[@]}"; do

    info "Installing $pkg..."

    $SUDO apt install -y "$pkg"

    success "$pkg installed."

done

# ==========================================
# 5. Install Ruby Gems
# ==========================================

info "Installing eventmachine..."

$SUDO gem install eventmachine

success "eventmachine installed."

info "Installing test-unit-full..."

$SUDO gem install test-unit-full -v 0.0.5

success "test-unit-full installed."

# ==========================================
# 6. Install BeEF-XSS
# ==========================================

info "Installing BeEF-XSS..."

$SUDO apt install -y beef-xss

success "BeEF-XSS installed."

# ==========================================
# 7. Configure BeEF Bundler
# ==========================================

BEEF_DIR="/usr/share/beef-xss"

if [ ! -d "$BEEF_DIR" ]; then
    error "BeEF directory not found: $BEEF_DIR"
    exit 1
fi

cd "$BEEF_DIR"

info "Checking Bundler frozen configuration..."

BUNDLE_CONFIG=$(
    $SUDO bundle config list 2>/dev/null || true
)

if echo "$BUNDLE_CONFIG" | grep -Eqi 'frozen.*true|true.*frozen'; then

    info "Disabling Bundler frozen mode..."

    $SUDO bundle config unset frozen

    success "Bundler frozen mode disabled."

else

    success "Bundler frozen mode is not enabled."

fi

# ==========================================
# 8. Install BeEF Dependencies
# ==========================================

info "Installing BeEF bundle dependencies..."

$SUDO bundle install

success "BeEF dependencies installed."

# ==========================================
# 9. Install Git
# ==========================================

info "Installing Git..."

$SUDO apt install -y git

success "Git installed."

# ==========================================
# 10. Final Status
# ==========================================

cd "$KALI_HOME"

# ==========================================
# Clone TheFatRat
# ==========================================

if [ -d "$KALI_HOME/TheFatRat/.git" ]; then
    info "TheFatRat repository already exists. Skipping."
else
    info "Cloning TheFatRat repository..."

    git clone --depth 1 \
        https://github.com/Screetsec/TheFatRat.git \
        "$KALI_HOME/TheFatRat"

    success "TheFatRat repository downloaded."
fi

# ==========================================
# Clone Zphisher
# ==========================================

if [ -d "$KALI_HOME/zphisher/.git" ]; then
    info "Zphisher repository already exists. Skipping."
else
    info "Cloning Zphisher repository..."

    git clone --depth 1 \
        https://github.com/htr-tech/zphisher.git \
        "$KALI_HOME/zphisher"

    success "Zphisher repository downloaded."
fi

cd "$KALI_HOME"


echo
echo -e "${GREEN}==========================================${NC}"
success "NetHunter Setup Completed!"
echo -e "${GREEN}==========================================${NC}"
echo

