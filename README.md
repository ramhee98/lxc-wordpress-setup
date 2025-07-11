# LXC WordPress Setup

A modular shell-based automation suite to deploy self-hosted WordPress sites inside LXC containers on Proxmox, with reverse proxy, HTTPS via Certbot, and dependency provisioning.

---

## 📦 Features

- Create and configure unprivileged LXC containers
- Install OS packages and PHP extensions
- Deploy WordPress via `wp-cli`
- Configure Nginx reverse proxy with automatic Let's Encrypt SSL
- Fully automated or interactive execution modes

---

## ⚙️ Prerequisites

- Proxmox VE host with:
  - LXC templates downloaded
  - Linux bridge (`vmbr0` or equivalent)
- SSH key-based access to reverse proxy VM
- Nginx and Certbot installed on reverse proxy
- `pct`, `openssl`, and `wp-cli` available on host

---

## 🚀 Quick Start

### 1. Apply Config Templates

```bash
bash apply-templates.sh
```

Edit each generated `*.conf` file in `config/` as needed.

---

### 2. Provision WordPress Container

```bash
bash provision-wordpress.sh --lxc-name wp1 --ip-suffix 101 --domain wp.example.com
```

Or run without arguments to use interactive mode.

---

## 🧩 Individual Scripts

### Create LXC container

```bash
bash create-lxc.sh
```

Prompts for name and IP suffix, provisions container using `config/lxc.conf`.

---

### Install dependencies

```bash
bash install-deps.sh
```

Installs packages defined in `config/packages.conf` inside a chosen CTID.

---

### Deploy WordPress

```bash
bash wordpress.sh
```

Uses `config/wordpress.conf` and wp-cli to auto-install and configure WordPress.

---

### Configure Reverse Proxy

```bash
bash configure-rproxy.sh
```

Creates Nginx config, deploys to remote VM, and requests SSL via Certbot.

---

## 📝 Logs

- `logs/deployed-containers.csv`: CTID, lxc-name, IP, root password
- `logs/deployed-wordpress.csv`: CTID, domain, DB credentials, admin login

---

## 🔐 Security Notes

- SSH access to the reverse proxy must be key-based (no password prompts)
- Generated passwords are secure and stored in logs — protect `logs/` accordingly

---

## 📄 License

MIT License (optional — update as appropriate)