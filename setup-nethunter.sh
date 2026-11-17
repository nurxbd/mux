#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Color variables definition
RED=$'\e[1;31m'
GREEN=$'\e[1;32m'
YELLOW=$'\e[1;33m'
BLUE=$'\e[1;34m'
RESTORE=$'\e[0m'
L_GREY=$'\e[0;37m'

echo -e "${BLUE}[*] ${YELLOW}Updating package lists and upgrading existing packages...${RESTORE}"
sudo apt update && sudo apt upgrade -y

echo -e "${BLUE}[*] ${YELLOW}Installing core build tools, development libraries, and compilers...${RESTORE}"
APT_PKGS=(git tar curl build-essential pkg-config libyaml-dev libssl-dev libsqlite3-dev python3-pip postgresql postgresql-contrib)
for pkg in "${APT_PKGS[@]}"; do
    if dpkg -s "$pkg" &>/dev/null; then
        echo -e "${GREEN}  [-] ${L_GREY}$pkg is already installed. Skipping.${RESTORE}"
    else
        echo -e "${YELLOW}  [-] Installing $pkg...${RESTORE}"
        sudo apt install -y "$pkg"
    fi
done

echo -e "${BLUE}[*] ${YELLOW}Installing Ruby environment and gems dependencies...${RESTORE}"
RUBY_PKGS=(ruby-dev ruby-msgpack bundler)
for pkg in "${RUBY_PKGS[@]}"; do
    if dpkg -s "$pkg" &>/dev/null; then
        echo -e "${GREEN}  [-] ${L_GREY}$pkg is already installed. Skipping.${RESTORE}"
    else
        echo -e "${YELLOW}  [-] Installing $pkg...${RESTORE}"
        sudo apt install -y "$pkg"
    fi
done

echo -e "${BLUE}[*] ${YELLOW}Installing additional Ruby gems...${RESTORE}"
if gem list -i eventmachine &>/dev/null; then
    echo -e "${GREEN}  [-] ${L_GREY}eventmachine gem is already installed. Skipping.${RESTORE}"
else
    sudo gem install eventmachine
fi

if gem list -i test-unit-full -v "0.0.5" &>/dev/null; then
    echo -e "${GREEN}  [-] ${L_GREY}test-unit-full (v0.0.5) gem is already installed. Skipping.${RESTORE}"
else
    sudo gem install test-unit-full -v 0.0.5
fi

echo -e "${BLUE}[*] ${YELLOW}Installing Python virtual environment package...${RESTORE}"
if dpkg -s python3.14-venv &>/dev/null; then
    echo -e "${GREEN}  [-] ${L_GREY}python3.14-venv is already installed. Skipping.${RESTORE}"
else
    sudo apt install -y python3.14-venv
fi

echo -e "${BLUE}[*] ${YELLOW}Installing Python packages via pip...${RESTORE}"
for pip_pkg in capstone pefile; do
    if python3 -c "import $pip_pkg" &>/dev/null; then
        echo -e "${GREEN}  [-] ${L_GREY}Python package '$pip_pkg' is already installed. Skipping.${RESTORE}"
    else
        echo -e "${YELLOW}  [-] Installing Python package '$pip_pkg'...${RESTORE}"
        sudo python3 -m pip install "$pip_pkg" --break-system-packages
    fi
done

echo -e "${BLUE}[*] ${YELLOW}Installing targetcli for storage/ISCSI management...${RESTORE}"
if dpkg -s targetcli-fb &>/dev/null; then
    echo -e "${GREEN}  [-] ${L_GREY}targetcli-fb is already installed. Skipping.${RESTORE}"
else
    sudo apt install -y targetcli-fb
fi

echo -e "${BLUE}[*] ${YELLOW}Installing BeEF-XSS and configuring bundler safely...${RESTORE}"
if dpkg -s beef-xss &>/dev/null; then
    echo -e "${GREEN}  [-] ${L_GREY}beef-xss is already installed. Skipping package install.${RESTORE}"
else
    sudo apt install -y beef-xss
fi

# Robustly configure BeEF bundle dependencies without frozen errors
if [ -d /usr/share/beef-xss ]; then
    echo -e "${YELLOW}  [-] Setting up BeEF-XSS bundle environment...${RESTORE}"
    sudo chown -R $USER:$USER /usr/share/beef-xss 2>/dev/null || true
    cd /usr/share/beef-xss
    bundle config --delete frozen 2>/dev/null || true
    bundle config set --local deployment false 2>/dev/null || true
    bundle install --no-deployment || sudo bundle install || true
    cd - > /dev/null
fi

echo -e "${BLUE}[*] ${YELLOW}Cloning TheFatRat repository...${RESTORE}"
if [ -d /opt/TheFatRat ]; then
    echo -e "${GREEN}  [-] ${L_GREY}TheFatRat is already cloned at /opt/TheFatRat. Skipping.${RESTORE}"
else
    sudo git clone --depth 1 https://github.com/Screetsec/TheFatRat.git /opt/TheFatRat
fi

echo -e "${BLUE}[*] ${YELLOW}Cloning Zphisher repository...${RESTORE}"
if [ -d /opt/zphisher ]; then
    echo -e "${GREEN}  [-] ${L_GREY}Zphisher is already cloned at /opt/zphisher. Skipping.${RESTORE}"
else
    sudo git clone --depth=1 https://github.com/htr-tech/zphisher.git /opt/zphisher
fi

echo -e "${BLUE}[*] ${YELLOW}Checking Apktool installation...${RESTORE}"
if command -v apktool &>/dev/null && [ -f /usr/bin/apktool.jar ]; then
    echo -e "${GREEN}  [-] ${L_GREY}Apktool is already installed. Skipping.${RESTORE}"
else
    echo -e "${YELLOW}  [-] Fetching and installing the latest version of Apktool...${RESTORE}"
    LATEST_TAG=$(curl -s "https://api.github.com/repos/iBotPeaches/Apktool/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    if [ -z "$LATEST_TAG" ]; then
        LATEST_TAG="v3.0.3"
    fi
    sudo wget -O /usr/bin/apktool https://raw.githubusercontent.com/iBotPeaches/Apktool/master/scripts/linux/apktool
    sudo wget -O /usr/bin/apktool.jar "https://github.com/iBotPeaches/Apktool/releases/download/${LATEST_TAG}/apktool_${LATEST_TAG#v}.jar"
    sudo chmod +x /usr/bin/apktool
    sudo chmod +x /usr/bin/apktool.jar
fi

echo -e "${BLUE}[*] ${YELLOW}Checking Cloudflared installation...${RESTORE}"
if command -v cloudflared &>/dev/null; then
    echo -e "${GREEN}  [-] ${L_GREY}Cloudflared is already installed. Skipping.${RESTORE}"
else
    echo -e "${YELLOW}  [-] Downloading and installing Cloudflared (ARM64)...${RESTORE}"
    wget -O cloudflared-linux-arm64.deb 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb'
    sudo dpkg -i cloudflared-linux-arm64.deb
    sudo apt --fix-broken install -y
    rm cloudflared-linux-arm64.deb
fi

echo -e "${BLUE}[*] ${YELLOW}Checking Ngrok installation...${RESTORE}"
if command -v ngrok &>/dev/null; then
    echo -e "${GREEN}  [-] ${L_GREY}Ngrok is already installed. Skipping.${RESTORE}"
else
    echo -e "${YELLOW}  [-] Downloading and installing Ngrok (ARM64)...${RESTORE}"
    wget https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-arm64.tgz
    tar -xvzf ngrok-v3-stable-linux-arm64.tgz
    chmod +x ngrok
    sudo mv ngrok /usr/local/bin/
    rm ngrok-v3-stable-linux-arm64.tgz
    echo -e "${YELLOW}  [-] Configuring Ngrok authtoken...${RESTORE}"
    ngrok config add-authtoken 35jM2L3Gd9o8y52MmAnb52LFDkV_Y57AcMMrrEPD2NUMbYHb
fi

if ! grep -q "/usr/local/bin" ~/.zshrc; then
    echo 'export PATH=$PATH:/usr/local/bin' >> ~/.zshrc
fi

echo -e "${BLUE}[*] ${YELLOW}Configuring and starting PostgreSQL service...${RESTORE}"
if command -v pg_ctl &>/dev/null; then
    sudo service postgresql start || sudo pg_ctlcluster $(ls /etc/postgresql 2>/dev/null | head -n 1) main start || true
elif command -v pg_ctlcluster &>/dev/null; then
    sudo pg_ctlcluster $(ls /etc/postgresql 2>/dev/null | head -n 1) main start || true
fi

sudo su - postgres -c "psql -tc \"SELECT 1 FROM pg_roles WHERE rolname='msf'\" | grep -q 1 || psql -c \"CREATE USER msf WITH CREATEDB PASSWORD 'msf';\"" 2>/dev/null || true
sleep 3

echo -e "${BLUE}[*] ${YELLOW}Checking Metasploit Framework installation and initializing database...${RESTORE}"
if dpkg -s metasploit-framework &>/dev/null; then
    echo -e "${GREEN}  [-] ${L_GREY}Metasploit Framework is already installed. Re-initializing database...${RESTORE}"
    sudo msfdb reinit || sudo msfdb init || true
else
    echo -e "${YELLOW}  [-] Installing Metasploit Framework and initializing its database...${RESTORE}"
    sudo apt install -y metasploit-framework
    sudo msfdb init || true
fi

echo -e "${GREEN}[*] All installations and setups completed successfully!${RESTORE}"

