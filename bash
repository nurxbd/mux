# Custom ps1 prompt
PS1="\[\e[0;32m\]┌──(\[\e[1;32m\]Termu✘㉿nm\[\e[1;31m\]✘\[\e[0m\]\[\e[1;32m\]nur\[\e[0m\]\[\e[0;32m\])-[\[\e[0;33m\]\w\[\e[0;32m\]]\n\[\e[0;32m\]└─► \[\e[0m\]"

banner() {
    clear
    echo -e "\e[1;34m==================================================\e[0m"
    echo -e "\e[1;34mToday is:\e[0m \e[1;32m$(date '+%A, %B %d, %Y')\e[0m"
    echo -e "\e[1;34mTime    :\e[0m \e[1;33m$(date '+%r')\e[0m"
    echo -e "\e[1;34m==================================================\e[0m"
}

theme() {
    clear
    # --- HIGH CONTRAST COLORFUL HEADER ---
    echo -e "\e[1;32m  ____   _ ____    __ __  _ ____   _ __   _ _____  \e[0m"
    echo -e "\e[1;32m |    \\ | |    \\  /  |\\ \\\`/|    \\ | |  | | |     | \e[0m"
    echo -e "\e[1;32m |     \\| |     \\/   |/   \\|     \\| |  |_| |     \\ \e[0m"
    echo -e "\e[1;32m |__/\\____|__/\\__/|__/__/\\_|__/\\____|______|__|\\__\\ \e[0m"
    echo -e "\e[1;34m==================== \e[1;31mnm✘nur\e[1;34m ========================\e[0m"
    echo ""

    # SEQUENTIAL TYPING TEXT ANIMATION
    for text in " >> ( ͡° ͜ʖ ͡°) Welcome to me >> author : nm✘nur <<" " >> This system controled by venom ヘ(◕.◕ヘ) <<" " >> Loading dependencies for fix any broken {•_•}"; do

        # Print the line letter by letter
        for (( i=0; i<${#text}; i++ )); do
            echo -ne "\e[1;32m${text:$i:1}\e[0m"
            sleep 0.05
        done

        # Pause for 1 second at the end of the line so you can read it
        sleep 1

        # Return to the beginning of the line and clear it entirely for the next sentence
        echo -ne "\r\e[K"
    done

    # Live Countdown Timer (5 seconds)
    echo -n "System is fixing in "
    for i in {5..1}; do
        echo -n "$i...."
        sleep 1
    done
    echo ""
}

# Native Termux update function
tsu() {
    # Execute the theme animation before updating
    theme

    # 1. Update package lists
    pkg update -y && apt update -y

    # 2. Upgrade packages and handle smart dependency changes
    pkg upgrade -y && apt dist-upgrade -y

    # 3. Remove unused packages/dependencies no longer needed
    apt autoremove -y

    # 4. Clean up partial cached package files
    apt autoclean

    # 5. Clear the local repository of retrieved package files to save space
    apt clean

    # 6. Fix broken dependencies (if any exist)
    apt install -f -y

    clear
    banner
}

# Execute the banner function when the terminal opens
banner

