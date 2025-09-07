#!/bin/bash

set -e

# Full Automatic Metasploit Framework Installer for Termux
# With PostgreSQL auto-start setup (Fixed: no ruby-dev)

echo "=================================================="
echo "   Metasploit Auto Installer for Termux"
echo "=================================================="

# Update and upgrade Termux packages
echo "[*] Updating packages..."
apt update && apt upgrade -y
pkg update -y && pkg upgrade -y

# Install required dependencies
echo "[*] Installing dependencies..."
pkg install -y wget curl openssh git ncurses-utils ruby make clang python python-pip libffi ncurses openssl libxml2 libxslt postgresql

# Install Python libraries
echo "[*] Installing Python modules..."
pip install requests

# Setup PostgreSQL database
echo "[*] Initializing PostgreSQL..."
if [ ! -d "$PREFIX/var/lib/postgresql" ]; then
    mkdir -p "$PREFIX/var/lib/postgresql"
    initdb "$PREFIX/var/lib/postgresql"
fi

# Start PostgreSQL service
echo "[*] Starting PostgreSQL service..."
pg_ctl -D "$PREFIX/var/lib/postgresql" -l "$PREFIX/var/lib/postgresql/logfile" start || true

# Auto-start PostgreSQL on Termux launch
if ! grep -q "pg_ctl -D \$PREFIX/var/lib/postgresql -l \$PREFIX/var/lib/postgresql/logfile start" "$HOME/.bashrc"; then
    echo "" >> "$HOME/.bashrc"
    echo "# Auto start PostgreSQL when Termux launches" >> "$HOME/.bashrc"
    echo "pg_ctl -D \$PREFIX/var/lib/postgresql -l \$PREFIX/var/lib/postgresql/logfile start >/dev/null 2>&1 || true" >> "$HOME/.bashrc"
    echo "[*] Added PostgreSQL auto-start to .bashrc"
fi

# Remove old installation if exists
cd $HOME
if [ -d "metasploit-framework" ]; then
    echo "[*] Removing old Metasploit installation..."
    rm -rf metasploit-framework
fi

# Clone Metasploit
echo "[*] Cloning Metasploit Framework..."
git clone https://github.com/rapid7/metasploit-framework.git
cd metasploit-framework

# Fix bootsnap issue
echo "[*] Disabling bootsnap..."
sed -i "s/require 'bootsnap\/setup'/# require 'bootsnap\/setup'/" config/boot.rb

# Install bundler
echo "[*] Installing bundler..."
gem install bundler

# Install gems
echo "[*] Installing gems (this may take a while)..."
if ! bundle install; then
    echo "[!] Bundle install failed, retrying with bundle update..."
    bundle update
fi

# Create symlinks
echo "[*] Creating symlinks..."
mkdir -p $PREFIX/bin
ln -sf $HOME/metasploit-framework/msfconsole $PREFIX/bin/msfconsole
ln -sf $HOME/metasploit-framework/msfvenom $PREFIX/bin/msfvenom

echo "=================================================="
echo "✓ Metasploit Framework installation completed!"
echo "=================================================="
echo ""
echo "To start using Metasploit:"
echo "  1. Restart Termux or run: source ~/.bashrc"
echo "  2. Run: msfconsole"
echo ""
echo "Available commands:"
echo "  - msfconsole (main console)"
echo "  - msfvenom (payload generator)"
echo ""
echo "Installation directory: $HOME/metasploit-framework"
echo ""
echo "Note: PostgreSQL will auto-start whenever you open Termux."
echo "=================================================="
