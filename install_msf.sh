#!/bin/bash
# install_msf_cli.sh
# Simple colorful CLI menu for Metasploit installer (Termux)
# Resume-capable, auto-postgres, msfdb init, shallow clone
# Usage:
# chmod +x install_msf_cli.sh
# ./install_msf_cli.sh

set -o errexit
set -o nounset
set -o pipefail

# -------- CONFIG --------
LOGFILE="$HOME/msf_install.log"
REPO="https://github.com/rapid7/metasploit-framework.git"
DEST="$HOME/metasploit-framework"
GIT_DEPTH=1
PREFIX=${PREFIX:-/data/data/com.termux/files/usr}
# ------------------------

# Colors
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
MAGENTA="\e[35m"
BOLD="\e[1m"
NC="\e[0m"

# ASCII banner (you can change text)
banner() {
    clear
    echo -e "${MAGENTA}${BOLD}"
    cat <<'EOF'
 __  __      _        ____            _       _ _   
|  \/  | ___| |_ __ _/ ___| _   _ ___| |_ ___| | |  
| |\/| |/ _ \ __/ _` \___ \| | | / __| __/ _ \ | |  
| |  | |  __/ || (_| |___) | |_| \__ \ ||  __/ | |  
|_|  |_|\___|\__\__,_|____/ \__, |___/\__\___|_|_|  
                            |___/                  
EOF
    echo -e "${NC}"
    echo -e "${CYAN}Metasploit Auto Installer (Resume-ready) — Termux${NC}"
    echo -e "${YELLOW}Log: ${LOGFILE}${NC}"
    echo
}

# Logging
mkdir -p "$(dirname "$LOGFILE")"
touch "$LOGFILE"
log() {
    echo "[$(date '+%F %T')] $*" | tee -a "$LOGFILE"
}

# Network check
ensure_network() {
    if ping -c1 github.com >/dev/null 2>&1; then
        return 0
    else
        echo -e "${RED}[!] Network unreachable. Check your internet and try again.${NC}"
        return 1
    fi
}

# Dependencies
install_dependencies() {
    log "Updating packages and installing dependencies..."
    echo -e "${YELLOW}[*] Updating packages...${NC}"
    apt update && apt upgrade -y >>"$LOGFILE" 2>&1 || true
    pkg update -y && pkg upgrade -y >>"$LOGFILE" 2>&1 || true

    PKGS="wget curl openssh git ncurses-utils ruby make clang python python-pip libffi ncurses openssl libxml2 libxslt postgresql"
    for p in $PKGS; do
        if ! pkg list-installed "$p" >/dev/null 2>&1; then
            echo -e "${CYAN}[*] Installing $p...${NC}"
            log "Installing package: $p"
            pkg install -y "$p" >>"$LOGFILE" 2>&1 || log "Warning: failed to install $p"
        else
            log "Package $p already installed."
        fi
    done

    echo -e "${CYAN}[*] Installing pip packages...${NC}"
    pip install --upgrade pip >/dev/null 2>&1 || true
    pip install requests >/dev/null 2>&1 || true
    log "Dependencies installed."
}

# PostgreSQL setup
setup_postgresql() {
    echo -e "${YELLOW}[*] Setting up PostgreSQL...${NC}"
    if [ ! -d "$PREFIX/var/lib/postgresql" ] || [ -z "$(ls -A "$PREFIX/var/lib/postgresql" 2>/dev/null || true)" ]; then
        log "Initializing PostgreSQL data directory"
        mkdir -p "$PREFIX/var/lib/postgresql"
        initdb "$PREFIX/var/lib/postgresql" >>"$LOGFILE" 2>&1 || log "initdb may have warnings"
    else
        log "PostgreSQL data dir exists"
    fi

    log "Starting PostgreSQL"
    pg_ctl -D "$PREFIX/var/lib/postgresql" -l "$PREFIX/var/lib/postgresql/logfile" start >>"$LOGFILE" 2>&1 || log "pg_ctl start returned non-zero (maybe already running)"

    # Auto-start entry
    AUTO_CMD='pg_ctl -D $PREFIX/var/lib/postgresql -l $PREFIX/var/lib/postgresql/logfile start >/dev/null 2>&1 || true'
    if ! grep -Fq "$AUTO_CMD" "$HOME/.bashrc" 2>/dev/null; then
        echo "" >> "$HOME/.bashrc"
        echo "# Auto start PostgreSQL when Termux launches" >> "$HOME/.bashrc"
        echo "$AUTO_CMD" >> "$HOME/.bashrc"
        log "Added PostgreSQL auto-start to .bashrc"
    fi
    echo -e "${GREEN}✓ PostgreSQL initialized and configured${NC}"
}

# Git clone or resume
git_clone_or_resume() {
    ensure_network || return 1
    if [ -d "$DEST/.git" ]; then
        echo -e "${CYAN}[*] Existing git repo detected — fetching updates (resume).${NC}"
        log "Attempting git fetch for resume"
        cd "$DEST"
        if git fetch --depth=$GIT_DEPTH origin +HEAD:refs/remotes/origin/HEAD >>"$LOGFILE" 2>&1; then
            git reset --hard origin/HEAD >>"$LOGFILE" 2>&1 || log "git reset failed"
            echo -e "${GREEN}✓ Repository updated (resume).${NC}"
        else
            echo -e "${YELLOW}[!] Shallow fetch failed, trying full fetch...${NC}"
            log "Shallow fetch failed — trying full fetch"
            git fetch --all >>"$LOGFILE" 2>&1 || log "git fetch --all failed"
            git reset --hard origin/HEAD >>"$LOGFILE" 2>&1 || log "git reset failed"
        fi
    else
        # If partial dir exists without .git, rename it to keep artifacts
        if [ -d "$DEST" ] && [ ! -d "$DEST/.git" ]; then
            mv "$DEST" "${DEST}_partial_$(date +%s)" >>"$LOGFILE" 2>&1 || true
            log "Renamed partial dir to preserve artifacts"
        fi

        cd "$(dirname "$DEST")"
        echo -e "${CYAN}[*] Cloning repository (shallow clone)...${NC}"
        local tries=0
        local maxtries=4
        while [ $tries -lt $maxtries ]; do
            if git clone --depth=$GIT_DEPTH "$REPO" "$(basename "$DEST")" >>"$LOGFILE" 2>&1; then
                log "Git clone succeeded"
                echo -e "${GREEN}✓ Clone completed${NC}"
                break
            else
                tries=$((tries+1))
                log "git clone failed attempt $tries"
                echo -e "${YELLOW}[!] Clone failed (attempt $tries). Retrying in $((tries*5))s...${NC}"
                sleep $((tries*5))
            fi
        done
        if [ $tries -ge $maxtries ]; then
            log "git clone failed after $maxtries attempts"
            echo -e "${RED}[!] git clone failed repeatedly. Check network and rerun script to resume.${NC}"
            return 2
        fi
    fi
    return 0
}

# Install Ruby gems (resume-capable)
install_ruby_gems() {
    cd "$DEST"
    if [ -f config/boot.rb ]; then
        sed -i "s/require 'bootsnap\/setup'/# require 'bootsnap\/setup'/" config/boot.rb || true
    fi

    if ! command -v bundle >/dev/null 2>&1; then
        echo -e "${CYAN}[*] Installing bundler...${NC}"
        gem install bundler >>"$LOGFILE" 2>&1 || log "gem install bundler failed"
    fi

    echo -e "${CYAN}[*] Installing gems (bundle install)...${NC}"
    if ! bundle install --jobs=3 --retry=3 >>"$LOGFILE" 2>&1; then
        echo -e "${YELLOW}[!] bundle install failed, trying bundle update...${NC}"
        if ! bundle update --jobs=3 --retry=3 >>"$LOGFILE" 2>&1; then
            log "bundle update also failed"
            echo -e "${RED}[!] bundle install/update failed. Rerun script to resume.${NC}"
            return 2
        fi
    fi
    echo -e "${GREEN}✓ Gems installed${NC}"
    return 0
}

# Symlinks
create_symlinks() {
    mkdir -p "$PREFIX/bin"
    ln -sf "$DEST/msfconsole" "$PREFIX/bin/msfconsole"
    ln -sf "$DEST/msfvenom" "$PREFIX/bin/msfvenom"
    log "Symlinks created/updated"
}

# msfdb init
init_msfdb() {
    if command -v msfdb >/dev/null 2>&1; then
        echo -e "${CYAN}[*] Initializing Metasploit DB (msfdb init)...${NC}"
        msfdb init >>"$LOGFILE" 2>&1 || log "msfdb init returned non-zero"
        echo -e "${GREEN}✓ msfdb init attempted${NC}"
    else
        echo -e "${YELLOW}[!] msfdb not found. Attempting msfconsole db_status check.${NC}"
        if command -v msfconsole >/dev/null 2>&1; then
            msfconsole -q -x "db_status; exit" >>"$LOGFILE" 2>&1 || log "msfconsole db_status check had issues"
            echo -e "${GREEN}✓ db_status checked${NC}"
        else
            log "msfconsole not available for db init check"
        fi
    fi
}

# Check DB status (show)
check_db_status() {
    if ! command -v msfconsole >/dev/null 2>&1; then
        echo -e "${RED}[!] msfconsole not installed. Install first.${NC}"
        return
    fi
    echo -e "${CYAN}[*] Checking DB status...${NC}"
    msfconsole -q -x "db_status; exit"
}

# Full install pipeline (resume-aware)
install_pipeline() {
    install_dependencies
    setup_postgresql

    local clone_res
    git_clone_or_resume || { echo -e "${RED}[!] Git step failed. See $LOGFILE${NC}"; return; }
    clone_res=$?
    if [ "$clone_res" = 2 ]; then
        echo -e "${RED}[!] Clone failed after retries. Rerun to resume.${NC}"
        return
    fi

    install_ruby_gems || { echo -e "${RED}[!] Gems step failed. Rerun to resume.${NC}"; return; }

    create_symlinks
    init_msfdb

    echo -e "${GREEN}${BOLD}Installation finished or resumed successfully.${NC}"
}

# Update pipeline
update_pipeline() {
    if [ ! -d "$DEST" ]; then
        echo -e "${YELLOW}[!] No installation found. Install first.${NC}"
        return
    fi
    ensure_network || return
    echo -e "${CYAN}[*] Updating repository and gems...${NC}"
    cd "$DEST"
    git fetch --depth=$GIT_DEPTH origin >>"$LOGFILE" 2>&1 || git fetch --all >>"$LOGFILE" 2>&1
    git reset --hard origin/HEAD >>"$LOGFILE" 2>&1 || git pull >>"$LOGFILE" 2>&1
    install_ruby_gems || { echo -e "${RED}[!] bundle update failed. Rerun to resume.${NC}"; return; }
    create_symlinks
    echo -e "${GREEN}✓ Update complete${NC}"
}

# Uninstall
uninstall_pipeline() {
    echo -e "${YELLOW}[*] Removing installation...${NC}"
    rm -rf "$DEST"
    rm -f "$PREFIX/bin/msfconsole" "$PREFIX/bin/msfvenom"
    echo -e "${GREEN}✓ Uninstalled${NC}"
    log "Uninstalled Metasploit"
}

# Show log
view_log() {
    if command -v less >/dev/null 2>&1; then
        less "$LOGFILE"
    else
        cat "$LOGFILE"
    fi
}

# Run msfconsole
run_msfconsole() {
    if ! command -v msfconsole >/dev/null 2>&1; then
        echo -e "${RED}[!] msfconsole not found. Install first.${NC}"
        return
    fi
    echo -e "${YELLOW}Launching msfconsole. Press Ctrl+C to exit.${NC}"
    msfconsole
}

# ---------- Main CLI loop ----------
while true; do
    banner
    echo -e "${BOLD}Menu:${NC}"
    echo -e "${CYAN}1) Install / Continue installation${NC}"
    echo -e "${CYAN}2) Run msfconsole${NC}"
    echo -e "${CYAN}3) Update Metasploit${NC}"
    echo -e "${CYAN}4) Check DB status${NC}"
    echo -e "${CYAN}5) Uninstall Metasploit${NC}"
    echo -e "${CYAN}6) View install log${NC}"
    echo -e "${CYAN}7) Exit${NC}"
    echo
    read -p "$(echo -e ${YELLOW}Enter choice [1-7]:${NC} )" CHOICE
    case "$CHOICE" in
        1) install_pipeline; read -p "Press Enter to continue..." ;;
        2) run_msfconsole; read -p "Press Enter to continue..." ;;
        3) update_pipeline; read -p "Press Enter to continue..." ;;
        4) check_db_status; read -p "Press Enter to continue..." ;;
        5) uninstall_pipeline; read -p "Press Enter to continue..." ;;
        6) view_log; read -p "Press Enter to continue..." ;;
        7) echo -e "${GREEN}Goodbye.${NC}"; exit 0 ;;
        *) echo -e "${RED}[!] Invalid choice.${NC}"; sleep 1 ;;
    esac
done
