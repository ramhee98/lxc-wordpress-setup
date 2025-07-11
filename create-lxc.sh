#!/bin/bash

# === Resolve Script Directory ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config/lxc.conf"
LOG_FILE="${SCRIPT_DIR}/logs/deployed-containers.csv"

# === Load Config ===
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Config file not found: $CONFIG_FILE"
  exit 1
fi
source "$CONFIG_FILE"

# === Validate required config values ===
REQUIRED_VARS=(SUBNET GATEWAY STORAGE TEMPLATE BRIDGE DISK_SIZE MEMORY CORES SWAP CTID_START VLAN DNS)
for VAR in "${REQUIRED_VARS[@]}"; do
  if [[ -z "${!VAR}" ]]; then
    echo "Config variable '$VAR' is missing or empty"
    exit 1
  fi
done

# === Determine Next Available CTID ===
existing_ctids=$(pct list | awk 'NR>1 {print $1}' | sort -n)
CTID=$CTID_START
while echo "$existing_ctids" | grep -qw "$CTID"; do
  ((CTID++))
done

# === Ask for Hostname + Last IP Octet ===
read -p "Hostname: " HOSTNAME
read -p "Last octet of IP (e.g. 101): " IP_SUFFIX

# === Build full IP ===
BASE_IP="${SUBNET%.*}"   # Removes trailing .0 if present
IP="${BASE_IP}.${IP_SUFFIX}"

# === Create LXC Container ===
echo "Creating LXC CTID $CTID ($HOSTNAME) at $IP on VLAN $VLAN..."

# === Create Container ===
pct create "$CTID" "$TEMPLATE" \
  -hostname "$HOSTNAME" \
  -net0 name=eth0,bridge=$BRIDGE,ip=${IP}/24,gw=${GATEWAY},tag=${VLAN} \
  -storage "$STORAGE" \
  -rootfs "$STORAGE:$DISK_SIZE" \
  -cores "$CORES" \
  -memory "$MEMORY" \
  -nameserver "$DNS" \
  -swap "$SWAP" \
  -unprivileged 1 \
  -features nesting=1 \
  -onboot 1

# === Start container and set root password ===
ROOT_PW=$(openssl rand -base64 64 | tr -dc 'A-Za-z0-9')
pct start "$CTID"
sleep 3
pct exec "$CTID" -- bash -c "echo root:$ROOT_PW | chpasswd"

# === Output result ===
echo "$CTID,$HOSTNAME,$IP,$ROOT_PW" >> "$LOG_FILE"

echo "✅ LXC $CTID created successfully"
echo "   Hostname: $HOSTNAME"
echo "   IP: $IP"
echo "   Root password: $ROOT_PW"
echo "   Logged to: $LOG_FILE"
