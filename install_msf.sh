#!/data/data/com.termux/files/usr/bin/bash
# Metasploit Auto Installer for Termux by Muhammad Anas

set -e

echo ">>> Updating Termux..."
pkg update -y && pkg upgrade -y

echo ">>> Installing dependencies..."
pkg install -y git curl wget make clang python python-pip \
  libffi libxml2 libxslt ncurses openssl ruby

echo ">>> Removing old metasploit if exists..."
rm -rf $HOME/metasploit-framework

echo ">>> Cloning Metasploit Framework..."
cd $HOME
git clone https://github.com/rapid7/metasploit-framework.git
cd metasploit-framework

echo ">>> Fixing bootsnap issue..."
sed -i 's/require "bootsnap\/setup"/# require "bootsnap\/setup"/' config/boot.rb || true

echo ">>> Installing bundler..."
gem install bundler --no-document || true

echo ">>> Installing required gems..."
bundle install || bundle update || true

echo ">>> Creating symlinks..."
ln -sf $HOME/metasploit-framework/msfconsole $PREFIX/bin/msfconsole
ln -sf $HOME/metasploit-framework/msfvenom $PREFIX/bin/msfvenom

echo "✅ Metasploit installed successfully!"
echo "Run Metasploit with: msfconsole"
