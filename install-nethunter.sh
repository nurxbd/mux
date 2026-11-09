#!/data/data/com.termux/files/usr/bin/bash -e

VERSION=20261105
BASE_URL=https://kali.download
USERNAME=kali

function unsupported_arch() {
    printf "${red}"
    echo "[*] Unsupported Architecture\n\n"
    printf "${reset}"
    exit 1
}

function ask() {
    while true; do
        if [ "${2:-}" = "Y" ]; then
            prompt="Y/n"
            default=Y
        elif [ "${2:-}" = "N" ]; then
            prompt="y/N"
            default=N
        else
            prompt="y/n"
            default=
        fi

        printf "${light_cyan}\n[?] "
        read -p "$1 [$prompt] " REPLY

        if [ -z "$REPLY" ]; then
            REPLY=$default
        fi

        printf "${reset}"

        case "$REPLY" in
            Y*|y*) return 0 ;;
            N*|n*) return 1 ;;
        esac
    done
}

function get_arch() {
    printf "${blue}[*] Checking device architecture ..."
    case $(getprop ro.product.cpu.abi) in
        arm64-v8a)
            SYS_ARCH=arm64
            ;;
        *)
            unsupported_arch
            ;;
    esac
}

function set_strings() {
    SYS_ARCH="arm64"
    wimg="minimal"

    CHROOT=kali-${SYS_ARCH}
    IMAGE_NAME=kali-nethunter-rootfs-${wimg}-${SYS_ARCH}.tar.xz
    SHA_NAME=${IMAGE_NAME}.sha512sum
}

function prepare_fs() {
    unset KEEP_CHROOT
    if [ -d "${CHROOT}" ]; then
        if ask "Existing rootfs directory found. Delete and create a new one?" "N"; then
            rm -rf "${CHROOT}"
        else
            KEEP_CHROOT=1
        fi
    fi
}

function cleanup() {
    if [ -f "${IMAGE_NAME}" ]; then
        if ask "Delete downloaded rootfs file?" "N"; then
            rm -f "${IMAGE_NAME}"
            rm -f "${SHA_NAME}"
        fi
    fi
}

function check_dependencies() {
    printf "${blue}\n[*] Checking package dependencies...${reset}\n"
    apt update -y &> /dev/null

    REQUIRED_PACKAGES=("proot" "tar" "axel" "xz-utils")

    for PACKAGE_NAME in "${REQUIRED_PACKAGES[@]}"; do
        if dpkg -s "$PACKAGE_NAME" &> /dev/null; then
            echo "  $PACKAGE_NAME is OK"
        else
            printf "  Installing ${PACKAGE_NAME}...\n"
            apt install -y "$PACKAGE_NAME" || {
                printf "${red}ERROR: Failed to install ${PACKAGE_NAME}.\nExiting.\n${reset}"
                exit 1
            }
        fi
    done

    apt upgrade -y
}

function get_url() {
    ROOTFS_URL="${BASE_URL}/${IMAGE_NAME}"
    SHA_URL="${BASE_URL}/${SHA_NAME}"
}

function get_rootfs() {
    unset KEEP_IMAGE

    if [ -f "${IMAGE_NAME}" ]; then
        if ask "Existing image file found. Delete and download a new one?" "N"; then
            rm -f "${IMAGE_NAME}"
        else
            printf "${yellow}[!] Using existing rootfs archive${reset}\n"
            KEEP_IMAGE=1
            return
        fi
    fi

    printf "${blue}[*] Downloading rootfs...${reset}\n\n"
    get_url

    axel -o "${IMAGE_NAME}" "${ROOTFS_URL}" || wget --continue "${ROOTFS_URL}"
}

function verify_sha() {
    if [ -z "${KEEP_IMAGE:-}" ]; then
        printf "\n${blue}[*] Verifying integrity of rootfs...${reset}\n\n"

        if [ -f "${SHA_NAME}" ]; then
            sha512sum -c "$SHA_NAME" 2>/dev/null || {
                printf "${red}Rootfs corrupted. Please run this installer again.${reset}\n"
                exit 1
            }
        else
            echo "[!] SHA file not found. Skipping verification..."
        fi
    fi
}

function get_sha() {
    if [ -z "${KEEP_IMAGE:-}" ]; then
        printf "\n${blue}[*] Getting SHA ... ${reset}\n\n"

        get_url

        if [ -f "${SHA_NAME}" ]; then
            rm -f "${SHA_NAME}"
        fi

        if curl --output /dev/null --silent --head --fail "${SHA_URL}"; then
            wget --continue "${SHA_URL}"
            verify_sha
        else
            echo "[!] SHA_URL does not exist. Skipping download."
        fi
    fi
}

function extract_rootfs() {
    if [ -z "${KEEP_CHROOT:-}" ]; then
        printf "\n${blue}[*] Extracting rootfs... ${reset}\n\n"
        proot --link2symlink tar -xf "$IMAGE_NAME" 2>/dev/null || :
    else
        printf "${yellow}[!] Using existing rootfs directory${reset}\n"
    fi
}

function create_launcher() {
    NH_LAUNCHER=${PREFIX}/bin/nethunter
    NH_SHORTCUT=${PREFIX}/bin/nh

    cat > "$NH_LAUNCHER" << EOF
#!/data/data/com.termux/files/usr/bin/bash -e
cd \${HOME}
unset LD_PRELOAD

if [ ! -f $CHROOT/root/.version ]; then
    touch $CHROOT/root/.version
fi

user="$USERNAME"
home="/home/\$user"
start="sudo -u kali /bin/bash"

if ! grep -q "kali" ${CHROOT}/etc/passwd 2>/dev/null || [[ "\$#" != "0" && ("\$1" == "-r" || "\$1" == "-R") ]]; then
    user="root"
    home="/\$user"
    start="/bin/bash --login"

    if [[ "\$#" != "0" && ("\$1" == "-r" || "\$1" == "-R") ]]; then
        shift
    fi
fi

cmdline="proot \\
    --link2symlink \\
    -0 \\
    -r $CHROOT \\
    -b /dev \\
    -b /proc \\
    -b /sdcard \\
    -b $CHROOT\$home:/dev/shm \\
    -w \$home \\
    /usr/bin/env -i \\
    HOME=\$home \\
    PATH=/usr/local/sbin:/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin \\
    TERM=\$TERM \\
    LANG=C.UTF-8 \\
    \$start"

cmd="\$@"

if [ "\$#" == "0" ]; then
    exec \$cmdline
else
    \$cmdline -c "\$cmd"
fi
EOF

    chmod 700 "$NH_LAUNCHER"
    ln -sf "${NH_LAUNCHER}" "${NH_SHORTCUT}"
}

function fix_profile_bash() {
    if [ -f "${CHROOT}/root/.bash_profile" ]; then
        sed -i '/if/,/fi/d' "${CHROOT}/root/.bash_profile"
    fi
}

function fix_sudo() {
    chmod +s "$CHROOT/usr/bin/sudo" 2>/dev/null || :
    chmod +s "$CHROOT/usr/bin/su" 2>/dev/null || :

    echo "kali ALL=(ALL:ALL) ALL" > "$CHROOT/etc/sudoers.d/kali" 2>/dev/null || :
    echo "Set disable_coredump false" > "$CHROOT/etc/sudo.conf" 2>/dev/null || :
}

function fix_uid() {
    USRID=$(id -u)
    GRPID=$(id -g)

    nh -r usermod -u "$USRID" kali 2>/dev/null || :
    nh -r groupmod -g "$GRPID" kali 2>/dev/null || :
}

function print_banner() {
    printf "${blue}##################################################\n"
    printf "${blue}   ____   _ ____    __ __ __ ____   _ __   _ _____ \n"
    printf "${blue}  |    \ | |    \  /  |\ \` /|    \ | |  | | |     |\n"
    printf "${blue}  |     \| |     \/   |/   \|     \| |  |_| |     \ \n"
    printf "${blue}  |__/\____|__/\__/|__/__/\_|__/\____|______|__|\__\ \n"
    printf "${blue}#################### NetHunter ####################${reset}\n\n"
}

red='\033[1;31m'
green='\033[1;32m'
yellow='\033[1;33m'
blue='\033[1;34m'
light_cyan='\033[1;96m'
reset='\033[0m'

cd "$HOME"

print_banner
get_arch
set_strings
prepare_fs
check_dependencies
get_rootfs
get_sha
extract_rootfs
create_launcher
cleanup

printf "\n${blue}[*] Configuring NetHunter for Termux ...${reset}\n"

fix_profile_bash
fix_sudo
fix_uid

printf "\n${blue}[*] Configuring telinit for Rootless NetHunter...${reset}\n"

nethunter -r bash -c '
if [ -e /usr/sbin/telinit ] && [ ! -L /usr/sbin/telinit ]; then
    mv /usr/sbin/telinit /usr/sbin/telinit.bak2
fi

if [ -L /usr/sbin/telinit ] && [ ! -e /usr/sbin/telinit ]; then
    rm -f /usr/sbin/telinit
fi

if [ ! -e /usr/sbin/telinit ]; then
    ln -s /usr/bin/true /usr/sbin/telinit
fi

printf "${green}[+] Telinit configuration completed.${reset}\n"
'

# ==================================================
# UPDATE NETHUNTER AND DOWNLOAD SETUP SCRIPT
# ==================================================

printf "\n${blue}[*] Updating NetHunter and installing packages...${reset}\n"
nethunter -r touch /root/.hushlogin
nethunter -r touch /home/kali/.hushlogin

nethunter -r apt update
nethunter -r apt full-upgrade -y
nethunter -r apt autoremove -y


# ==================================================
# MOVE CUSTOM SETUP SCRIPT INTO KALI HOME
# ==================================================

printf "\n${blue}[*] Moving custom NetHunter setup script...${reset}\n"

SOURCE_FILE="$HOME/Termux-Setup/setup-nethunter.sh"
DEST_DIR="$HOME/$CHROOT/home/kali"
DEST_FILE="$DEST_DIR/setup-nethunter.sh"

if [ -f "$SOURCE_FILE" ]; then

    mkdir -p "$DEST_DIR"

    if mv "$SOURCE_FILE" "$DEST_FILE"; then

        nethunter -r chmod 755 /home/kali/setup-nethunter.sh
        nethunter -r chown kali:kali /home/kali/setup-nethunter.sh

        printf "${green}[+] setup-nethunter.sh moved successfully.${reset}\n"
        printf "${green}[+] Executable permission configured.${reset}\n"
        printf "${green}[+] Ownership configured: kali:kali${reset}\n"

    else
        printf "${red}[!] Failed to move setup-nethunter.sh.${reset}\n"
    fi

else
    printf "${yellow}[!] Source setup-nethunter.sh not found.${reset}\n"
    printf "${yellow}[!] Expected: %s${reset}\n" "$SOURCE_FILE"
fi


# ==================================================
# INSTALLATION COMPLETE
# ==================================================

print_banner

printf "${green}[=] Kali NetHunter (ARM64 Minimal) installed successfully${reset}\n\n"

printf "${green}[+] To start Kali NetHunter, type:${reset}\n"
printf "${green}[+] nethunter             # To start NetHunter CLI${reset}\n"
printf "${green}[+] nethunter -r          # To run NetHunter as root${reset}\n"
printf "${green}[+] nh                    # Shortcut for nethunter${reset}\n\n"

