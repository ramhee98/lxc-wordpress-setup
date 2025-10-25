#!/bin/bash

set -e

# === Resolve Script Directory ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
printf "Script Directory: %s\n" "$SCRIPT_DIR"
LOG_FILE="${SCRIPT_DIR}/logs/deployed-containers.csv"

# === Parse Args ===
while [[ $# -gt 0 ]]; do
  case "$1" in
    --lxc-name) LXC_NAME="$2"; shift 2 ;;
    --ip-suffix) IP_SUFFIX="$2"; shift 2 ;;
    --domain) DOMAIN="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# === Interactive Fallbacks ===
[[ -z "$LXC_NAME" ]] && read -p "Enter LXC name: " LXC_NAME
[[ -z "$IP_SUFFIX" ]] && read -p "Enter last octet of IP: " IP_SUFFIX
[[ -z "$DOMAIN" ]] && read -p "Enter domain (e.g. example.com): " DOMAIN

# === Step 1: Create LXC ===
echo "▶️  Creating container..."
bash "$SCRIPT_DIR/create-lxc.sh" <<< "$(printf '%s\n%s' "$LXC_NAME" "$IP_SUFFIX")"

# === Fetch latest CTID/IP from log ===
LINE=$(tail -n 1 "$LOG_FILE")
IFS=',' read -r CTID _ IP _ <<< "$LINE"

# === Step 2: Install Dependencies ===
echo "▶️  Installing dependencies..."
echo "$CTID" | bash "$SCRIPT_DIR/install-deps.sh"

# === Step 3: Install WordPress ===
echo "▶️  Installing WordPress..."
echo -e "$CTID\nhttps://$DOMAIN" | bash "$SCRIPT_DIR/wordpress.sh"

# === Step 4: Configure Reverse Proxy ===
echo "▶️  Configuring reverse proxy..."
echo -e "$DOMAIN\n$IP" | bash "$SCRIPT_DIR/configure-rproxy.sh"

echo "✅ Provisioning complete for $DOMAIN (CTID $CTID, IP $IP)"

echo "Don't forget to add firewall rules if necessary!"