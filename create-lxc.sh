#!/bin/bash

# === Resolve Script Directory ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config/lxc-default.conf"
LOG_FILE="${SCRIPT_DIR}/logs/deployed-containers.csv"

# === Load Config ===
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Config file not found: $CONFIG_FILE"
  exit 1
fi
source "$CONFIG_FILE"

# === Determine Next CTID ===
existing_ctids=$(pct list | awk 'NR>1 {print $1}' | sort -n)
CTID=$CTID_START
while echo "$existing_ctids" | grep -qw "$CTID"; do
  ((CTID++))
done

# === Get Inputs ===
read -p "Hostname: " HOSTNAME
read -p "Last octet of IP (e.g. 101): " IP_SUFFIX
IP="${SUBNET}.${IP_SUFFIX}"

# === Generate secure root password ===
ROOT_PW=$(openssl rand -base64 64 | tr -dc 'A-Za-z0-9')

echo "Creating LXC CTID $CTID ($HOSTNAME) at $IP on VLAN $VLAN..."

# === Create Container ===
pct create "$CTID" "$TEMPLATE" \
  -hostname "$HOSTNAME" \
  -net0 name=eth0,bridge=$BRIDGE,ip=${IP}/24,gw=${DNS},tag=${VLAN} \
  -storage "$STORAGE" \
  -rootfs "$STORAGE:$DISK_SIZE" \
  -cores "$CORES" \
  -memory "$MEMORY" \
  -swap "$SWAP" \
  -unprivileged 1 \
  -features nesting=1 \
  -onboot 1

# === Start + Set Root Password ===
pct start "$CTID"
sleep 3
pct exec "$CTID" -- bash -c "echo root:'$ROOT_PW' | chpasswd"

# === Log output ===
echo "$CTID,$HOSTNAME,$IP,$ROOT_PW" >> "$LOG_FILE"

# === Done ===
echo "✅ LXC $CTID ($HOSTNAME) created."
echo "   IP: $IP"
echo "   Root password: $ROOT_PW"
echo "   Console: pct console $CTID or Web UI"
echo "   Logged to: $LOG_FILE"
