# Metasploit Installer for Termux

A simple script to install and run the **Metasploit Framework** on Termux without any manual setup.
This script automatically installs all dependencies, Ruby, Bundler, and required gems, then sets up Metasploit.

---

## ⚡ Features

* One-click installation
* Auto-fix for `bootsnap` issue
* Installs all required gems automatically
* Creates direct commands: `msfconsole` and `msfvenom`

---

## 🚀 Installation Guide

Open Termux and run the following commands:

```bash
pkg update -y && pkg upgrade -y
pkg install -y curl git

# Download installer script
curl -LO https://raw.githubusercontent.com/techcorp/termux-metasploit-installer/main/install_msf.sh

# Give execute permission
chmod +x install_msf.sh

# Run installer
./install_msf.sh
```

---

## ▶️ Run Metasploit

After successful installation, you can start Metasploit with:

```bash
msfconsole
```

And use `msfvenom` directly:

```bash
msfvenom -h
```

---

## ❗ Troubleshooting

* If you get package not found errors, run:

  ```bash
  termux-change-repo
  ```

  and select **Grimler’s main repo**.

* If gems fail to install, re-run the script:

  ```bash
  bash install_msf.sh
  ```

---

## 👨‍💻 Author

Created by **Muhammad Anas** – Ethical Hacker & Cybersecurity Expert
