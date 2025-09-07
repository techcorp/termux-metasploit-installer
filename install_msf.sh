# Metasploit Framework Installer for Termux
# This script installs the latest Metasploit Framework in Termux

echo "=================================================="
echo "Metasploit Framework Installer for Termux"
echo "=================================================="

# Update and upgrade packages
echo "[*] Updating Termux packages..."
pkg update -y
pkg upgrade -y

# Install dependencies
echo "[*] Installing required dependencies..."
PACKAGES="git curl wget make clang python python-pip libffi ruby ncurses openssl libxml2 libxslt"

for package in $PACKAGES; do
    echo "[*] Installing $package..."
    if ! pkg install -y "$package"; then
        echo "[!] Failed to install $package. Please run 'termux-change-repo' to change repositories."
        exit 1
    fi
done

# Install additional Python packages that might be needed
echo "[*] Installing Python packages..."
pip install requests

# Initialize PostgreSQL database
echo "[*] Setting up PostgreSQL..."
if [ ! -d "$PREFIX/var/lib/postgresql" ]; then
    mkdir -p "$PREFIX/var/lib/postgresql"
    initdb "$PREFIX/var/lib/postgresql"
fi

# Start PostgreSQL service
echo "[*] Starting PostgreSQL service..."
pg_ctl -D "$PREFIX/var/lib/postgresql" -l "$PREFIX/var/lib/postgresql/logfile" start || true

# Clone Metasploit Framework
echo "[*] Cloning Metasploit Framework..."
cd "$HOME"
if [ -d "metasploit-framework" ]; then
    echo "[*] Metasploit directory exists, removing old installation..."
    rm -rf metasploit-framework
fi

git clone https://github.com/rapid7/metasploit-framework.git
cd metasploit-framework

# Disable bootsnap to avoid compatibility issues
echo "[*] Disabling bootsnap..."
sed -i "s/require 'bootsnap\/setup'/# require 'bootsnap\/setup'/" config/boot.rb

# Install bundler
echo "[*] Installing bundler..."
gem install bundler

# Install gems
echo "[*] Installing gems (this may take several minutes)..."
if ! bundle install; then
    echo "[*] Bundle install failed, trying bundle update..."
    bundle update
fi

# Create symlinks for easy access
echo "[*] Creating symlinks..."
mkdir -p "$HOME/.local/bin"
ln -sf "$HOME/metasploit-framework/msfconsole" "$HOME/.local/bin/msfconsole"
ln -sf "$HOME/metasploit-framework/msfvenom" "$HOME/.local/bin/msfvenom"

# Add to PATH if not already there
if ! grep -q "$HOME/.local/bin" "$HOME/.bashrc"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    echo "[*] Added $HOME/.local/bin to PATH in .bashrc"
fi

# Source bashrc to update current session
export PATH="$HOME/.local/bin:$PATH"

echo "=================================================="
echo "✓ Metasploit Framework installation completed!"
echo "=================================================="
echo ""
echo "To start using Metasploit:"
echo "1. Restart Termux or run: source ~/.bashrc"
echo "2. Run: msfconsole"
echo ""
echo "Available commands:"
echo "  - msfconsole (main console)"
echo "  - msfvenom (payload generator)"
echo ""
echo "Installation directory: $HOME/metasploit-framework"
echo ""
echo "Note: First run may take longer as it initializes the database."
echo "=================================================="
