#!/bin/bash

# === Resolve Script Directory ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config/packages.conf"

# === Load Config ===
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Config file not found: $CONFIG_FILE"
  exit 1
fi
source "$CONFIG_FILE"

# === Ask for CTID ===
read -p "Enter container CTID to install dependencies: " CTID

# === Validate container ===
if ! pct status "$CTID" &>/dev/null; then
  echo "Container $CTID does not exist."
  exit 1
fi

echo "Installing in CTID $CTID"

# === Update + Upgrade (if configured) ===
if [[ "$AUTO_UPDATE" == "true" ]]; then
  echo "Updating & upgrading inside container..."
  pct exec "$CTID" -- bash -c "
    apt update && DEBIAN_FRONTEND=noninteractive apt -y upgrade
  "
fi

# === Install Packages ===
echo "Installing packages: $PACKAGES"
pct exec "$CTID" -- bash -c "
  DEBIAN_FRONTEND=noninteractive apt install -y $PACKAGES
"

pct exec "$CTID" -- bash -c "
  wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg &&
  echo \"deb https://packages.sury.org/php/ \$(lsb_release -sc) main\" > /etc/apt/sources.list.d/php.list &&
  apt update
  DEBIAN_FRONTEND=noninteractive apt install -y $PHP_EXTENSIONS
"

echo "✅ Finished provisioning CTID $CTID"
