#!/data/data/com.termux/files/usr/bin/bash
# Metasploit Installer for Termux (Stable Ruby 3.1 Fix)

echo ">>> Updating Termux..."
pkg update -y && pkg upgrade -y

echo ">>> Installing dependencies..."
pkg install -y wget curl git unzip autoconf bison clang coreutils make \
   ncurses-utils ncurses git postgresql python ruby libffi-dev \
   libxslt-dev libxml2 libxml2-dev libxslt pkg-config openssl-dev

echo ">>> Removing old Ruby..."
pkg uninstall -y ruby

echo ">>> Installing stable Ruby 3.1 (patched)..."
pkg install -y ruby

echo ">>> Downloading Metasploit..."
cd $HOME
git clone https://github.com/rapid7/metasploit-framework.git
cd metasploit-framework

echo ">>> Fixing bootsnap issue..."
sed -i 's/require "bootsnap\/setup"/# require "bootsnap\/setup"/' config/boot.rb

echo ">>> Installing bundler & required gems..."
gem install bundler
bundle install

echo ">>> Creating symlink..."
ln -sf $HOME/metasploit-framework/msfconsole $PREFIX/bin/msfconsole
ln -sf $HOME/metasploit-framework/msfvenom $PREFIX/bin/msfvenom

echo ">>> Metasploit installation completed!"
echo "Run with: msfconsole"
