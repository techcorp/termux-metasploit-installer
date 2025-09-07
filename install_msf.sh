#!/bin/bash

set -e

# Advanced Auto Metasploit Installer for Termux
# With Interactive Menu

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Banner
banner() {
    clear
    echo -e "${CYAN}"
    echo "=================================================="
    echo "       Metasploit Auto Installer for Termux       "
    echo "=================================================="
    echo -e "${NC}"
}

# Update & Upgrade
update_system() {
    banner
    echo -e "${YELLOW}[*] Updating Termux packages...${NC}"
    apt update && apt upgrade -y
    echo -e "${GREEN}[✓] Packages updated successfully!${NC}"
    read -p "Press Enter to continue..."
}

# Install dependencies
install_deps() {
    banner
    echo -e "${YELLOW}[*] Installing dependencies...${NC}"
    pkg install wget curl openssh git -y
    pkg install ncurses-utils -y
    echo -e "${GREEN}[✓] Dependencies installed successfully!${NC}"
    read -p "Press Enter to continue..."
}

# Install Metasploit
install_msf() {
    banner
    echo -e "${YELLOW}[*] Installing Metasploit using Gushmazuko script...${NC}"
    source <(curl -fsSL https://raw.githubusercontent.com/gushmazuko/metasploit_in_termux/master/metasploit.sh)
    echo -e "${GREEN}[✓] Metasploit installed successfully!${NC}"
    read -p "Press Enter to continue..."
}

# Run Metasploit
run_msf() {
    banner
    echo -e "${CYAN}[*] Starting Metasploit...${NC}"
    msfconsole
}

# Menu
menu() {
    while true; do
        banner
        echo -e "${YELLOW}Choose an option:${NC}"
        echo "1) Update & Upgrade System"
        echo "2) Install Dependencies"
        echo "3) Install Metasploit"
        echo "4) Run Metasploit"
        echo "5) Exit"
        echo ""
        read -p "Enter your choice [1-5]: " choice
        case $choice in
            1) update_system ;;
            2) install_deps ;;
            3) install_msf ;;
            4) run_msf ;;
            5) echo -e "${RED}Exiting...${NC}"; exit 0 ;;
            *) echo -e "${RED}Invalid choice, try again!${NC}" ;;
        esac
    done
}

# Start menu
menu
