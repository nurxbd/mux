#!/bin/bash

# Exit immediately if a command exits with a non-zero status (except where handled)
set -e

# Color variables definition
RED=$'\e[1;31m'
GREEN=$'\e[1;32m'
YELLOW=$'\e[1;33m'
BLUE=$'\e[1;34m'
RESTORE=$'\e[0m'
L_GREY=$'\e[0;37m'

echo -e "${BLUE}[*] ${YELLOW}Updating package lists...${RESTORE}"
sudo apt update

echo -e "${BLUE}[*] ${YELLOW}Checking and installing core build tools, development libraries, and compilers...${RESTORE}"
APT_PACKAGES=(
    git tar nano wget curl python3-venv build-essential pkg-config 
    libyaml-dev libssl-dev libsqlite3-dev ruby-dev ruby-msgpack 
    bundler default-jdk default-jre beef-xss metasploit-framework
)

for pkg in "${APT_PACKAGES[@]}"; do
    if dpkg -s "$pkg" >/dev/null 2>&1; then
        echo -e "${GREEN}[*] Package '$pkg' is already installed. Skipping...${RESTORE}"
    else
        echo -e "${BLUE}[*] ${YELLOW}Installing '$pkg'...${RESTORE}"
        sudo apt install -y "$pkg"
    fi
done

echo -e "${BLUE}[*] ${YELLOW}Checking Ruby gems...${RESTORE}"
if gem list eventmachine -i >/dev/null 2>&1; then
    echo -e "${GREEN}[*] Gem 'eventmachine' is already installed. Skipping...${RESTORE}"
else
    sudo gem install eventmachine
fi

if gem list test-unit-full -v "0.0.5" -i >/dev/null 2>&1; then
    echo -e "${GREEN}[*] Gem 'test-unit-full (v0.0.5)' is already installed. Skipping...${RESTORE}"
else
    sudo gem install test-unit-full -v 0.0.5
fi

echo -e "${BLUE}[*] ${YELLOW}Checking TheFatRat repository...${RESTORE}"
if [ ! -d "TheFatRat" ]; then
    sudo git clone --depth 1 https://github.com/Screetsec/TheFatRat.git
else
    echo -e "${GREEN}[*] TheFatRat directory already exists. Skipping clone...${RESTORE}"
fi

echo -e "${BLUE}[*] ${YELLOW}Checking Zphisher repository...${RESTORE}"
if [ ! -d "zphisher" ]; then
    sudo git clone --depth=1 https://github.com/htr-tech/zphisher.git
else
    echo -e "${GREEN}[*] Zphisher directory already exists. Skipping clone...${RESTORE}"
fi

echo -e "${BLUE}[*] ${YELLOW}Checking Cloudflared (ARM64)...${RESTORE}"
if command -v cloudflared >/dev/null 2>&1; then
    echo -e "${GREEN}[*] Cloudflared is already installed. Skipping...${RESTORE}"
else
    wget -O cloudflared-linux-arm64.deb 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb'
    sudo dpkg -i cloudflared-linux-arm64.deb || sudo apt --fix-broken install -y
    rm cloudflared-linux-arm64.deb
fi

echo -e "${BLUE}[*] ${YELLOW}Checking Ngrok (ARM64)...${RESTORE}"
if command -v ngrok >/dev/null 2>&1; then
    echo -e "${GREEN}[*] Ngrok is already installed. Skipping...${RESTORE}"
else
    wget https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-arm64.tgz
    tar -xvzf ngrok-v3-stable-linux-arm64.tgz
    chmod +x ngrok
    sudo mv ngrok /usr/local/bin/
    rm ngrok-v3-stable-linux-arm64.tgz
fi

echo -e "${BLUE}[*] ${YELLOW}Configuring Ngrok authtoken...${RESTORE}"
/usr/local/bin/ngrok config add-authtoken 35jM2L3Gd9o8y52MmAnb52LFDkV_Y57AcMMrrEPD2NUMbYHb || true
sudo cp /usr/local/bin/ngrok /usr/bin/ngrok || true

if ! grep -q "/usr/local/bin" ~/.zshrc 2>/dev/null; then
    echo 'export PATH=$PATH:/usr/local/bin' >> ~/.zshrc
fi

echo -e "${BLUE}[*] ${YELLOW}Checking Apktool...${RESTORE}"
if command -v apktool >/dev/null 2>&1; then
    echo -e "${GREEN}[*] Apktool is already installed. Skipping...${RESTORE}"
else
    LATEST_TAG=$(curl -s "https://api.github.com/repos/iBotPeaches/Apktool/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    if [ -z "$LATEST_TAG" ]; then
        LATEST_TAG="v3.0.3"
    fi
    sudo wget -O /usr/local/bin/apktool https://raw.githubusercontent.com/iBotPeaches/Apktool/master/scripts/linux/apktool
    sudo wget -O /usr/local/bin/apktool.jar "https://github.com/iBotPeaches/Apktool/releases/download/${LATEST_TAG}/apktool_${LATEST_TAG#v}.jar"
    sudo chmod +x /usr/local/bin/apktool
    sudo chmod +r /usr/local/bin/apktool.jar
fi

echo "[+] Step 2: Cleaning up broken PostgreSQL clusters..."
pg_lsclusters -h | awk '{print $1, $2}' | while read -r v n; do
    sudo pg_dropcluster "$v" "$n" --stop 2>/dev/null || true
done

echo "[+] Step 3: Configuring Metasploit to use a portable SQLite database..."
mkdir -p "$HOME/.msf4"
if [ ! -f "$HOME/.msf4/database.yml" ]; then
    cat <<EOF > "$HOME/.msf4/database.yml"
production:
  adapter: sqlite3
  database: $HOME/.msf4/msf3.db
  pool: 5
  timeout: 5000
EOF
else
    echo -e "${GREEN}[*] Metasploit database.yml is already configured. Skipping...${RESTORE}"
fi

echo -e "${BLUE}[+] ${YELLOW}Setup complete! You can now type 'msfconsole' to start Metasploit whenever you are ready.${RESTORE}"
echo -e "${GREEN}[*] All installations and setups completed successfully!${RESTORE}"

