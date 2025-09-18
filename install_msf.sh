#!/bin/bash
# Metasploit Auto Installer for Termux
# - Dialog menu UI
# - Auto PostgreSQL init + auto-start
# - Shallow clone (--depth=1)
# - Resume/continue logic if install interrupted
# - Auto msfdb init and DB status check
# Usage:
# chmod +x install_msf_menu_resume.sh
# ./install_msf_menu_resume.sh

set -o errexit
set -o pipefail
set -o nounset

LOGFILE="$HOME/msf_install.log"
REPO="https://github.com/rapid7/metasploit-framework.git"
DEST="$HOME/metasploit-framework"
GIT_DEPTH=1
PREFIX=${PREFIX:-/data/data/com.termux/files/usr}  # default Termux PREFIX if not set

# Ensure log file exists
mkdir -p "$(dirname "$LOGFILE")"
touch "$LOGFILE"

# Helper: write timestamped log
log() {
    echo "[$(date '+%F %T')] $*" | tee -a "$LOGFILE"
}

# Trap errors to show message and return to menu
trap 'log "Error occurred. See $LOGFILE for details."; sleep 2' ERR

# Install dialog if missing
if ! command -v dialog >/dev/null 2>&1; then
    log "Installing dialog..."
    pkg install -y dialog >>"$LOGFILE" 2>&1 || { log "Failed to install dialog"; }
fi

# Utility: show message box
msgbox() {
    dialog --title "$1" --msgbox "$2" 8 60
}

# Utility: show infobox (non-blocking short)
infobox() {
    dialog --title "$1" --infobox "$2" 5 60
}

# Ensure network available (simple)
ensure_network() {
    if ! ping -c1 github.com >/dev/null 2>&1; then
        msgbox "Network error" "Cannot reach github.com. Check your internet and retry."
        return 1
    fi
    return 0
}

# Install core dependencies (idempotent)
install_dependencies() {
    infobox "Dependencies" "Updating packages and installing dependencies..."
    log "Updating apt/pkg..."
    apt update && apt upgrade -y >>"$LOGFILE" 2>&1 || true
    pkg update -y && pkg upgrade -y >>"$LOGFILE" 2>&1 || true

    PKGS="wget curl openssh git ncurses-utils ruby make clang python python-pip libffi ncurses openssl libxml2 libxslt postgresql"
    for p in $PKGS; do
        if ! pkg list-installed "$p" >/dev/null 2>&1; then
            log "Installing package: $p"
            pkg install -y "$p" >>"$LOGFILE" 2>&1 || {
                log "Warning: failed to install $p (continuing)."
            }
        else
            log "Package $p already installed."
        fi
    done

    # Python packages
    log "Installing pip packages..."
    pip install --upgrade pip >/dev/null 2>&1 || true
    pip install requests >/dev/null 2>&1 || true
}

# Setup PostgreSQL (idempotent)
setup_postgresql() {
    infobox "PostgreSQL" "Initializing and starting PostgreSQL..."
    if [ ! -d "$PREFIX/var/lib/postgresql" ] || [ -z "$(ls -A "$PREFIX/var/lib/postgresql" 2>/dev/null || true)" ]; then
        log "Creating PostgreSQL data dir and initializing..."
        mkdir -p "$PREFIX/var/lib/postgresql"
        initdb "$PREFIX/var/lib/postgresql" >>"$LOGFILE" 2>&1 || log "initdb returned non-zero"
    else
        log "PostgreSQL data dir already exists."
    fi

    log "Starting PostgreSQL..."
    pg_ctl -D "$PREFIX/var/lib/postgresql" -l "$PREFIX/var/lib/postgresql/logfile" start >>"$LOGFILE" 2>&1 || log "pg_ctl start returned non-zero (maybe already running)"

    # Auto-start in .bashrc (idempotent)
    AUTO_CMD='pg_ctl -D $PREFIX/var/lib/postgresql -l $PREFIX/var/lib/postgresql/logfile start >/dev/null 2>&1 || true'
    if ! grep -Fq "$AUTO_CMD" "$HOME/.bashrc" 2>/dev/null; then
        log "Adding PostgreSQL auto-start to .bashrc"
        {
            echo ""
            echo "# Auto start PostgreSQL when Termux launches"
            echo "$AUTO_CMD"
        } >>"$HOME/.bashrc"
    else
        log "PostgreSQL auto-start already present in .bashrc"
    fi
}

# Resume-capable clone/pull
git_clone_or_resume() {
    ensure_network || return 1
    if [ -d "$DEST/.git" ]; then
        log "Existing git repo detected. Attempting to fetch latest and continue (resume)."
        cd "$DEST"
        # Try to fetch shallowly; if fails, try full fetch
        if git fetch --depth=$GIT_DEPTH origin +HEAD:refs/remotes/origin/HEAD >>"$LOGFILE" 2>&1; then
            log "Fetched updates (shallow). Resetting to origin/HEAD..."
            git reset --hard origin/HEAD >>"$LOGFILE" 2>&1 || log "git reset failed"
        else
            log "Shallow fetch failed. Trying full fetch..."
            git fetch --all >>"$LOGFILE" 2>&1 || log "git fetch --all failed"
            git reset --hard origin/HEAD >>"$LOGFILE" 2>&1 || log "git reset failed"
        fi
    else
        # If a partial directory exists (no .git), leave it but attempt fresh clone into same path by renaming old
        if [ -d "$DEST" ] && [ ! -d "$DEST/.git" ]; then
            log "Found partial directory without .git. Renaming to ${DEST}_partial_$(date +%s) and doing shallow clone."
            mv "$DEST" "${DEST}_partial_$(date +%s)" >>"$LOGFILE" 2>&1 || true
        fi

        cd "$(dirname "$DEST")"
        log "Performing shallow git clone..."
        # Try cloning with retries
        local tries=0
        local maxtries=4
        while [ $tries -lt $maxtries ]; do
            if git clone --depth=$GIT_DEPTH "$REPO" "$(basename "$DEST")" >>"$LOGFILE" 2>&1; then
                log "Git clone succeeded."
                break
            else
                tries=$((tries + 1))
                log "Git clone attempt $tries failed. Retrying in $((tries * 5))s..."
                sleep $((tries * 5))
            fi
        done
        if [ $tries -ge $maxtries ]; then
            log "git clone failed after $maxtries attempts. Leaving partial downloads intact; you can rerun the installer to resume."
            return 2
        fi
    fi
    return 0
}

# Install Ruby bundler and gems (resume-friendly)
install_ruby_gems() {
    cd "$DEST"
    # Disable bootsnap if present
    if [ -f config/boot.rb ]; then
        sed -i "s/require 'bootsnap\/setup'/# require 'bootsnap\/setup'/" config/boot.rb || true
    fi

    # Install bundler if missing
    if ! command -v bundle >/dev/null 2>&1; then
        log "Installing bundler gem..."
        gem install bundler >>"$LOGFILE" 2>&1 || log "gem install bundler failed"
    fi

    # Use bundler with retries and partial resume (`--retry` helps networks)
    log "Running bundle install (with retry/resume)..."
    # Use jobs and retry flags to speed up and to be resilient
    if ! bundle install --jobs=3 --retry=3 >>"$LOGFILE" 2>&1; then
        log "bundle install failed on first attempt. Trying bundle update..."
        bundle update --jobs=3 --retry=3 >>"$LOGFILE" 2>&1 || {
            log "bundle update also failed (network or gem issues). You can re-run installer to continue from here."
            return 2
        }
    fi
    return 0
}

# Create symlinks idempotent
create_symlinks() {
    mkdir -p "$PREFIX/bin"
    ln -sf "$DEST/msfconsole" "$PREFIX/bin/msfconsole"
    ln -sf "$DEST/msfvenom" "$PREFIX/bin/msfvenom"
    log "Symlinks created/updated: msfconsole, msfvenom"
}

# Initialize msf DB (if possible)
init_msfdb() {
    if command -v msfdb >/dev/null 2>&1; then
        log "Running msfdb init..."
        msfdb init >>"$LOGFILE" 2>&1 || log "msfdb init returned non-zero (continuing)."
    else
        # older/newer installs may not provide msfdb; do manual steps
        log "msfdb not found; attempting to initialize via msfconsole commands"
        if command -v msfconsole >/dev/null 2>&1; then
            # create a small one-time command to create and migrate DB via msfconsole
            msfconsole -q -x "db_status; exit" >>"$LOGFILE" 2>&1 || log "msfconsole db_status check returned non-zero"
        else
            log "msfconsole not available yet; cannot init db now."
        fi
    fi
}

# Verify DB status and show result
check_db_status() {
    if ! command -v msfconsole >/dev/null 2>&1; then
        msgbox "DB Status" "msfconsole not found. Install Metasploit first."
        return
    fi
    # Run msfconsole headless check
    local out
    out=$(msfconsole -q -x "db_status; exit" 2>/dev/null || true)
    msgbox "DB Status" "$out"
}

# Full install pipeline (resume-aware)
install_pipeline() {
    install_dependencies || { msgbox "Error" "Failed to install some dependencies. Check $LOGFILE"; return; }
    setup_postgresql || { msgbox "Error" "PostgreSQL init failed. Check $LOGFILE"; return; }

    infobox "Git" "Cloning/updating Metasploit repository (resume-supported)..."
    local gc_res
    git_clone_or_resume || { msgbox "Error" "Git network failure. Check connection and re-run installer."; return; }
    gc_res=$?
    if [ "$gc_res" = 2 ]; then
        msgbox "Partial Clone" "Git clone failed after multiple attempts. Rerun installer to resume. See $LOGFILE"
        return
    fi

    infobox "Gems" "Installing Ruby gems (resume-supported)..."
    install_ruby_gems || { msgbox "Error" "bundle install/update failed. See $LOGFILE and rerun installer to resume."; return; }

    create_symlinks || true

    infobox "DB" "Initializing Metasploit DB..."
    init_msfdb || log "msfdb init step returned non-zero"

    msgbox "Success" "Metasploit installed or updated. You can run msfconsole from Termux shell."
}

# Update pipeline (idempotent)
update_pipeline() {
    if [ ! -d "$DEST" ]; then
        msgbox "Update" "No installation found. Please install first."
        return
    fi
    ensure_network || { msgbox "Network" "No network. Cannot update."; return; }
    infobox "Updating" "Pulling latest changes..."
    cd "$DEST"
    git fetch --depth=$GIT_DEPTH origin >>"$LOGFILE" 2>&1 || git fetch --all >>"$LOGFILE" 2>&1 || { msgbox "Error" "Git fetch failed. See $LOGFILE"; return; }
    git reset --hard origin/HEAD >>"$LOGFILE" 2>&1 || git pull >>"$LOGFILE" 2>&1 || { msgbox "Error" "Git update failed. See $LOGFILE"; return; }
    install_ruby_gems || { msgbox "Error" "bundle install/update failed during update. See $LOGFILE"; return; }
    create_symlinks
    msgbox "Updated" "Metasploit updated successfully."
}

# Uninstall pipeline (idempotent)
uninstall_pipeline() {
    if [ -d "$DEST" ]; then
        rm -rf "$DEST"
        log "Removed $DEST"
    fi
    rm -f "$PREFIX/bin/msfconsole" "$PREFIX/bin/msfvenom"
    log "Removed symlinks"
    msgbox "Uninstalled" "Metasploit and symlinks removed."
}

# Run msfconsole (clears screen)
run_msf() {
    clear
    if ! command -v msfconsole >/dev/null 2>&1; then
        echo "msfconsole not found. Install Metasploit first."
        read -p "Press Enter to continue..."
        return
    fi
    echo "Launching msfconsole. Press Ctrl+C to exit."
    msfconsole
}

# Main Dialog Menu
while true; do
    CHOICE=$(dialog --clear --stdout \
        --title "Metasploit Installer (Resume-ready)" \
        --menu "Choose an action:" 18 70 8 \
        1 "Install / Continue installation" \
        2 "Run msfconsole" \
        3 "Update Metasploit (git + gems)" \
        4 "Check DB status" \
        5 "Uninstall Metasploit" \
        6 "Open install log ($LOGFILE)" \
        7 "Exit")

    case "$CHOICE" in
        1) install_pipeline ;;
        2) run_msf ;;
        3) update_pipeline ;;
        4) check_db_status ;;
        5) uninstall_pipeline ;;
        6)
            # Show log (fallback to pager if available)
            clear
            if command -v less >/dev/null 2>&1; then
                less "$LOGFILE"
            else
                cat "$LOGFILE"
            fi
            read -p "Press Enter to return to menu..."
            ;;
        7) clear; exit 0 ;;
        *) ;;
    esac
done
