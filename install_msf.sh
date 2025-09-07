#!/data/data/com.termux/files/usr/bin/bash
# Full Auto Metasploit Installer for Termux by Muhammad Anas

set -e

echo ">>> Updating Termux..."
pkg update -y && pkg upgrade -y || true

echo ">>> Installing dependencies..."
pkg install -y git curl wget make clang python python-pip \
    autoconf bison pkg-config libffi libxml2 libxslt \
    postgresql openssl-tool ncurses tar zip unzip || true

echo ">>> Installing Ruby..."
pkg install -y ruby || true

echo ">>> Cleaning old installation..."
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

echo ">>> Verifying installation..."
if command -v msfconsole >/dev/null 2>&1; then
    echo "✅ Metasploit installed successfully!"
    echo "Run with: msfconsole"
else
    echo "❌ Installation failed. Please check Termux repos with: termux-change-repo"
fi
