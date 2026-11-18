#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Color variables definition
red='\033[1;31m'
green='\033[1;32m'
yellow='\033[1;33m'
blue='\033[1;34m'
light_cyan='\033[1;96m'
reset='\033[0m'

echo -e "${blue}[*] ${yellow}Updating package lists and upgrading existing packages...${reset}"
sudo apt update && sudo apt upgrade -y

echo -e "${blue}[*] ${yellow}Installing core build tools, development libraries, and compilers...${reset}"
APT_PKGS=(git tar curl build-essential pkg-config libyaml-dev libssl-dev libsqlite3-dev python3-pip postgresql postgresql-contrib)
for pkg in "${APT_PKGS[@]}"; do
    if dpkg -s "$pkg" &>/dev/null; then
        echo -e "${green}  [-] ${light_cyan}$pkg is already installed. Skipping.${reset}"
    else
        echo -e "${yellow}  [-] Installing $pkg...${reset}"
        sudo apt install -y "$pkg"
    fi
done

echo -e "${blue}[*] ${yellow}Installing Ruby environment and gems dependencies...${reset}"
RUBY_PKGS=(ruby-dev ruby-msgpack bundler)
for pkg in "${RUBY_PKGS[@]}"; do
    if dpkg -s "$pkg" &>/dev/null; then
        echo -e "${green}  [-] ${light_cyan}$pkg is already installed. Skipping.${reset}"
    else
        echo -e "${yellow}  [-] Installing $pkg...${reset}"
        sudo apt install -y "$pkg"
    fi
done

echo -e "${blue}[*] ${yellow}Installing additional Ruby gems...${reset}"
if gem list -i eventmachine &>/dev/null; then
    echo -e "${green}  [-] ${light_cyan}eventmachine gem is already installed. Skipping.${reset}"
else
    sudo gem install eventmachine
fi

if gem list -i test-unit-full -v "0.0.5" &>/dev/null; then
    echo -e "${green}  [-] ${light_cyan}test-unit-full (v0.0.5) gem is already installed. Skipping.${reset}"
else
    sudo gem install test-unit-full -v 0.0.5
fi

echo -e "${blue}[*] ${yellow}Installing targetcli for storage/ISCSI management...${reset}"
if dpkg -s targetcli-fb &>/dev/null; then
    echo -e "${green}  [-] ${light_cyan}targetcli-fb is already installed. Skipping.${reset}"
else
    sudo apt install -y targetcli-fb
fi

echo -e "${blue}[*] ${yellow}Installing BeEF-XSS and configuring bundler safely...${reset}"
if dpkg -s beef-xss &>/dev/null; then
    echo -e "${green}  [-] ${light_cyan}beef-xss is already installed. Skipping package install.${reset}"
else
    sudo apt install -y beef-xss
fi

# Robustly configure BeEF bundle dependencies without frozen errors
if [ -d /usr/share/beef-xss ]; then
    echo -e "${yellow}  [-] Setting up BeEF-XSS bundle environment...${reset}"
    sudo chown -R $USER:$USER /usr/share/beef-xss 2>/dev/null || true
    cd /usr/share/beef-xss
    bundle config --delete frozen 2>/dev/null || true
    bundle config set --local deployment false 2>/dev/null || true
    bundle install --no-deployment || sudo bundle install || true
    cd - > /dev/null
fi

echo -e "${blue}[*] ${yellow}Checking Apktool installation...${reset}"
if command -v apktool &>/dev/null && [ -f /usr/bin/apktool.jar ]; then
    echo -e "${green}  [-] ${light_cyan}Apktool is already installed. Skipping.${reset}"
else
    echo -e "${yellow}  [-] Fetching and installing the latest version of Apktool...${reset}"
    LATEST_TAG=$(curl -s "https://api.github.com/repos/iBotPeaches/Apktool/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    if [ -z "$LATEST_TAG" ]; then
        LATEST_TAG="v3.0.3"
    fi
    sudo wget -O /usr/bin/apktool https://raw.githubusercontent.com/iBotPeaches/Apktool/master/scripts/linux/apktool
    sudo wget -O /usr/bin/apktool.jar "https://github.com/iBotPeaches/Apktool/releases/download/${LATEST_TAG}/apktool_${LATEST_TAG#v}.jar"
    sudo chmod +x /usr/bin/apktool
    sudo chmod +x /usr/bin/apktool.jar
fi

echo -e "${blue}[*] ${yellow}Checking Cloudflared installation...${reset}"
if command -v cloudflared &>/dev/null; then
    echo -e "${green}  [-] ${light_cyan}Cloudflared is already installed. Skipping.${reset}"
else
    echo -e "${yellow}  [-] Downloading and installing Cloudflared (ARM64)...${reset}"
    wget -O cloudflared-linux-arm64.deb 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb'
    sudo dpkg -i cloudflared-linux-arm64.deb
    sudo apt --fix-broken install -y
    rm cloudflared-linux-arm64.deb
fi

echo -e "${blue}[*] ${yellow}Checking Ngrok installation...${reset}"
if command -v ngrok &>/dev/null; then
    echo -e "${green}  [-] ${light_cyan}Ngrok is already installed. Skipping.${reset}"
else
    echo -e "${yellow}  [-] Downloading and installing Ngrok (ARM64)...${reset}"
    wget https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-arm64.tgz
    tar -xvzf ngrok-v3-stable-linux-arm64.tgz
    chmod +x ngrok
    sudo mv ngrok /usr/local/bin/
    rm ngrok-v3-stable-linux-arm64.tgz
    echo -e "${yellow}  [-] Configuring Ngrok authtoken...${reset}"
    ngrok config add-authtoken 35jM2L3Gd9o8y52MmAnb52LFDkV_Y57AcMMrrEPD2NUMbYHb
fi

if ! grep -q "/usr/local/bin" ~/.zshrc; then
    echo 'export PATH=$PATH:/usr/local/bin' >> ~/.zshrc
fi

echo -e "${blue}[*] ${yellow}Configuring and starting PostgreSQL service...${reset}"
if command -v pg_ctl &>/dev/null; then
    sudo service postgresql start || sudo pg_ctlcluster $(ls /etc/postgresql 2>/dev/null | head -n 1) main start || true
elif command -v pg_ctlcluster &>/dev/null; then
    sudo pg_ctlcluster $(ls /etc/postgresql 2>/dev/null | head -n 1) main start || true
fi

sudo su - postgres -c "psql -tc \"SELECT 1 FROM pg_roles WHERE rolname='msf'\" | grep -q 1 || psql -c \"CREATE USER msf WITH CREATEDB PASSWORD 'msf';\"" 2>/dev/null || true
sleep 3

echo -e "${blue}[*] ${yellow}Checking Metasploit Framework installation and initializing database...${reset}"
if dpkg -s metasploit-framework &>/dev/null; then
    echo -e "${green}  [-] ${light_cyan}Metasploit Framework is already installed. Re-initializing database...${reset}"
    sudo msfdb reinit || sudo msfdb init || true
else
    echo -e "${yellow}  [-] Installing Metasploit Framework and initializing its database...${reset}"
    sudo apt install -y metasploit-framework
    sudo msfdb init || true
fi

echo -e "${green}[*] All installations and setups completed successfully!${reset}"

