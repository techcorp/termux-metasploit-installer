#!/bin/bash

set -e

# Colors
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
NC="\e[0m" # No color

# Title Banner
banner() {
    clear
    echo -e "${GREEN}"
    echo "=================================================="
    echo "       Metasploit Framework Installer (Termux)    "
    echo "=================================================="
    echo -e "${NC}"
}

# Function: Install Metasploit
install_msf() {
    banner
    echo -e "${YELLOW}[*] Updating Termux packages...${NC}"
    apt update && apt upgrade -y
    pkg update -y && pkg upgrade -y

    echo -e "${YELLOW}[*] Installing dependencies...${NC}"
    pkg install -y wget curl openssh git ncurses-utils ruby make clang python python-pip libffi ncurses openssl libxml2 libxslt postgresql

    echo -e "${YELLOW}[*] Installing Python modules...${NC}"
    pip install requests

    echo -e "${YELLOW}[*] Setting up PostgreSQL...${NC}"
    if [ ! -d "$PREFIX/var/lib/postgresql" ]; then
        mkdir -p "$PREFIX/var/lib/postgresql"
        initdb "$PREFIX/var/lib/postgresql"
    fi
    pg_ctl -D "$PREFIX/var/lib/postgresql" -l "$PREFIX/var/lib/postgresql/logfile" start || true

    if ! grep -q "pg_ctl -D \$PREFIX/var/lib/postgresql" "$HOME/.bashrc"; then
        echo "" >> "$HOME/.bashrc"
        echo "# Auto start PostgreSQL when Termux launches" >> "$HOME/.bashrc"
        echo "pg_ctl -D \$PREFIX/var/lib/postgresql -l \$PREFIX/var/lib/postgresql/logfile start >/dev/null 2>&1 || true" >> "$HOME/.bashrc"
    fi

    cd $HOME
    if [ -d "metasploit-framework" ]; then
        echo -e "${RED}[*] Old Metasploit installation found. Removing...${NC}"
        rm -rf metasploit-framework
    fi

    echo -e "${YELLOW}[*] Cloning Metasploit Framework...${NC}"
    git clone --depth=1 https://github.com/rapid7/metasploit-framework.git
    cd metasploit-framework

    echo -e "${YELLOW}[*] Fixing bootsnap...${NC}"
    sed -i "s/require 'bootsnap\/setup'/# require 'bootsnap\/setup'/" config/boot.rb

    echo -e "${YELLOW}[*] Installing bundler...${NC}"
    gem install bundler

    echo -e "${YELLOW}[*] Installing gems...${NC}"
    if ! bundle install; then
        bundle update
    fi

    mkdir -p $PREFIX/bin
    ln -sf $HOME/metasploit-framework/msfconsole $PREFIX/bin/msfconsole
    ln -sf $HOME/metasploit-framework/msfvenom $PREFIX/bin/msfvenom

    echo -e "${YELLOW}[*] Initializing Metasploit DB...${NC}"
    if command -v msfdb >/dev/null 2>&1; then
        msfdb init || true
    fi

    echo -e "${GREEN}✓ Metasploit installation completed!${NC}"
    read -p "Press Enter to return to menu..."
}

# Function: Run Metasploit
run_msf() {
    banner
    echo -e "${YELLOW}[*] Launching Metasploit...${NC}"
    msfconsole
}

# Function: Update Metasploit
update_msf() {
    banner
    echo -e "${YELLOW}[*] Updating Metasploit...${NC}"
    cd $HOME/metasploit-framework && git pull
    bundle install
    echo -e "${GREEN}✓ Metasploit updated!${NC}"
    read -p "Press Enter to return to menu..."
}

# Function: Uninstall Metasploit
uninstall_msf() {
    banner
    echo -e "${RED}[*] Removing Metasploit installation...${NC}"
    rm -rf $HOME/metasploit-framework
    rm -f $PREFIX/bin/msfconsole
    rm -f $PREFIX/bin/msfvenom
    echo -e "${GREEN}✓ Metasploit removed.${NC}"
    read -p "Press Enter to return to menu..."
}

# Menu Loop
while true; do
    banner
    echo -e "${YELLOW}Select an option:${NC}"
    echo "1) Install Metasploit"
    echo "2) Run Metasploit"
    echo "3) Update Metasploit"
    echo "4) Uninstall Metasploit"
    echo "5) Exit"
    echo ""
    read -p "Enter your choice [1-5]: " choice

    case $choice in
        1) install_msf ;;
        2) run_msf ;;
        3) update_msf ;;
        4) uninstall_msf ;;
        5) exit 0 ;;
        *) echo -e "${RED}[!] Invalid choice!${NC}" ;;
    esac
done
