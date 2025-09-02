# Metasploit Framework Installer for Termux

This repository provides an installer script to set up **Metasploit Framework** on **Termux (Android)** without running into the common Ruby 3.4 / bootsnap errors.

The script will:
- Install all required dependencies
- Install a stable Ruby version (3.1) that works with Metasploit
- Fix the `bootsnap` issue
- Install required gems using Bundler
- Create symlinks for easy access (`msfconsole` and `msfvenom`)

---

## 📥 Installation

Clone this repository and run the script:

```bash
pkg update -y && pkg upgrade -y
pkg install git -y
git clone https://github.com/<your-username>/metasploit-termux-installer.git
cd metasploit-termux-installer
chmod +x install_msf.sh
./install_msf.sh
```

---

## ▶️ Usage

After installation, start Metasploit with:

```bash
msfconsole
```

You can also use `msfvenom` directly for payload generation.

---

## ⚡ Notes

- Keep Termux up to date before running the script.
- Any existing Ruby installation will be removed and replaced with a fresh one.
- If you face storage permission issues, run:
  ```bash
  termux-setup-storage
  ```

---

## 🔥 Credits
- [Rapid7 Metasploit Framework](https://github.com/rapid7/metasploit-framework)
- Script adapted and customized by **Muhammad Anas** for Termux users

