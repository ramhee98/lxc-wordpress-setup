#!/bin/bash

# === Load config ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config/rproxy.conf"
TEMPLATE_HTTP="${SCRIPT_DIR}/config/nginx.http.conf"
TEMPLATE_HTTPS="${SCRIPT_DIR}/config/nginx.https.conf"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Config file not found: $CONFIG_FILE"
  exit 1
fi
source "$CONFIG_FILE"

# === Prompt input ===
read -p "Enter domain (e.g. example.com): " DOMAIN
read -p "Enter upstream container IP (e.g. 192.168.100.10): " UPSTREAM

CONF_NAME="${DOMAIN}.conf"
REMOTE_PATH="${NGINX_CONF}${CONF_NAME}"
REMOTE_PATH_ENABLED="${NGINX_CONF_ENABLED}${CONF_NAME}"
TMP_HTTP="/tmp/${DOMAIN}.http.conf"
TMP_HTTPS="/tmp/${DOMAIN}.https.conf"

# === Generate local config files ===
if [[ ! -f "$TEMPLATE_HTTP" || ! -f "$TEMPLATE_HTTPS" ]]; then
  echo "Missing one or both template files."
  exit 1
fi

sed -e "s|{{DOMAIN}}|$DOMAIN|g" -e "s|{{UPSTREAM}}|$UPSTREAM|g" "$TEMPLATE_HTTP" > "$TMP_HTTP"
sed -e "s|{{DOMAIN}}|$DOMAIN|g" -e "s|{{UPSTREAM}}|$UPSTREAM|g" "$TEMPLATE_HTTPS" > "$TMP_HTTPS"

# === Step 1: Upload HTTP config and reload ===
scp -P "${RPROXY_SSH_PORT:-22}" "$TMP_HTTP" "${RPROXY_USER}@${RPROXY_HOST}:${REMOTE_PATH}" || {
  echo "Failed to upload HTTP config"
  exit 1
}

ssh -p "${RPROXY_SSH_PORT:-22}" "${RPROXY_USER}@${RPROXY_HOST}" bash <<EOF
  set -e
  sudo ln -sf "$REMOTE_PATH" "$REMOTE_PATH_ENABLED"
  sudo nginx -t && sudo systemctl reload nginx
EOF

# === Step 2: Run Certbot ===
if [[ "$CERTBOT" == "true" ]]; then
  ssh -p "${RPROXY_SSH_PORT:-22}" "${RPROXY_USER}@${RPROXY_HOST}" bash <<EOF
    set -e
    sudo certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "certbot@${DOMAIN}"
EOF
fi

# === Step 3: Upload HTTPS config and reload ===
scp -P "${RPROXY_SSH_PORT:-22}" "$TMP_HTTPS" "${RPROXY_USER}@${RPROXY_HOST}:${REMOTE_PATH}" || {
  echo "Failed to upload HTTPS config"
  exit 1
}

ssh -p "${RPROXY_SSH_PORT:-22}" "${RPROXY_USER}@${RPROXY_HOST}" bash <<EOF
  set -e
  sudo ln -sf "$REMOTE_PATH" "$REMOTE_PATH_ENABLED"
  sudo nginx -t && sudo systemctl reload nginx
EOF

echo "✅ Proxy deployed with HTTPS for $DOMAIN"
