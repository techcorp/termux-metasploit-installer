#!/bin/bash

set -e

# Check if dialog is installed
if ! command -v dialog >/dev/null 2>&1; then
    pkg install -y dialog
fi

# Colors
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
NC="\e[0m" # No color

# Function: Install Metasploit
install_msf() {
    dialog --infobox "Updating Termux packages..." 4 40
    apt update && apt upgrade -y >/dev/null 2>&1
    pkg update -y && pkg upgrade -y >/dev/null 2>&1

    dialog --infobox "Installing dependencies..." 4 40
    pkg install -y wget curl openssh git ncurses-utils ruby make clang python python-pip libffi ncurses openssl libxml2 libxslt postgresql >/dev/null 2>&1

    pip install requests >/dev/null 2>&1

    if [ ! -d "$PREFIX/var/lib/postgresql" ]; then
        mkdir -p "$PREFIX/var/lib/postgresql"
        initdb "$PREFIX/var/lib/postgresql" >/dev/null 2>&1
    fi
    pg_ctl -D "$PREFIX/var/lib/postgresql" -l "$PREFIX/var/lib/postgresql/logfile" start >/dev/null 2>&1 || true

    if ! grep -q "pg_ctl -D \$PREFIX/var/lib/postgresql" "$HOME/.bashrc"; then
        echo "" >> "$HOME/.bashrc"
        echo "# Auto start PostgreSQL when Termux launches" >> "$HOME/.bashrc"
        echo "pg_ctl -D \$PREFIX/var/lib/postgresql -l \$PREFIX/var/lib/postgresql/logfile start >/dev/null 2>&1 || true" >> "$HOME/.bashrc"
    fi

    cd $HOME
    [ -d "metasploit-framework" ] && rm -rf metasploit-framework

    dialog --infobox "Cloning Metasploit Framework..." 4 40
    git clone --depth=1 https://github.com/rapid7/metasploit-framework.git >/dev/null 2>&1
    cd metasploit-framework

    sed -i "s/require 'bootsnap\/setup'/# require 'bootsnap\/setup'/" config/boot.rb

    dialog --infobox "Installing bundler and gems..." 4 40
    gem install bundler >/dev/null 2>&1
    bundle install >/dev/null 2>&1 || bundle update >/dev/null 2>&1

    mkdir -p $PREFIX/bin
    ln -sf $HOME/metasploit-framework/msfconsole $PREFIX/bin/msfconsole
    ln -sf $HOME/metasploit-framework/msfvenom $PREFIX/bin/msfvenom

    if command -v msfdb >/dev/null 2>&1; then
        msfdb init >/dev/null 2>&1 || true
    fi

    dialog --msgbox "Metasploit installation completed successfully!" 7 50
}

# Function: Run Metasploit
run_msf() {
    clear
    echo -e "${YELLOW}[*] Launching Metasploit... Press Ctrl+C to exit.${NC}"
    msfconsole
}

# Function: Update Metasploit
update_msf() {
    dialog --infobox "Updating Metasploit..." 4 40
    cd $HOME/metasploit-framework && git pull >/dev/null 2>&1
    bundle install >/dev/null 2>&1
    dialog --msgbox "Metasploit has been updated!" 6 40
}

# Function: Uninstall Metasploit
uninstall_msf() {
    rm -rf $HOME/metasploit-framework
    rm -f $PREFIX/bin/msfconsole
    rm -f $PREFIX/bin/msfvenom
    dialog --msgbox "Metasploit has been removed from your system." 6 50
}

# Menu Loop
while true; do
    CHOICE=$(dialog --clear --stdout \
        --title "Metasploit Installer - Termux" \
        --menu "Select an option:" 15 50 6 \
        1 "Install Metasploit" \
        2 "Run Metasploit" \
        3 "Update Metasploit" \
        4 "Uninstall Metasploit" \
        5 "Exit")

    case $CHOICE in
        1) install_msf ;;
        2) run_msf ;;
        3) update_msf ;;
        4) uninstall_msf ;;
        5) clear; exit 0 ;;
    esac
done
