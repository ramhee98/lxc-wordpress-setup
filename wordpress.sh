#!/bin/bash

# === Script + Config ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config/wordpress.conf"
LOG_FILE="${SCRIPT_DIR}/logs/deployed-wordpress.csv"

# === Load Config ===
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Config file not found: $CONFIG_FILE"
  exit 1
fi
source "$CONFIG_FILE"

# === Ask for container ID + site URL ===
read -p "Enter container CTID to install WordPress into: " CTID
read -p "Enter site URL (e.g. https://example.com): " SITE_URL

# === Validate container ===
if ! pct status "$CTID" &>/dev/null; then
  echo "Container $CTID does not exist."
  exit 1
fi

# === Generate secure passwords ===
DB_NAME="wp_${CTID}"
DB_USER="wpuser_${CTID}"
DB_PASS=$(openssl rand -base64 64 | tr -dc 'A-Za-z0-9')
ADMIN_PASS=$(openssl rand -base64 64 | tr -dc 'A-Za-z0-9')

echo "Installing WordPress in CTID $CTID at $SITE_URL..."

# Install wp-cli inside container
pct exec "$CTID" -- bash -c "
  if ! command -v wp &>/dev/null; then
    curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar &&
    chmod +x wp-cli.phar &&
    mv wp-cli.phar /usr/local/bin/wp
  fi
"

# Remove default Apache index
pct exec "$CTID" -- rm -f ${INSTALL_DIR}/index.html

# Setup DB
pct exec "$CTID" -- bash -c "
  mysql -e \"
    CREATE DATABASE IF NOT EXISTS \\\`${DB_NAME}\\\`;
    CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
    GRANT ALL PRIVILEGES ON \\\`${DB_NAME}\\\`.* TO '${DB_USER}'@'localhost';
    FLUSH PRIVILEGES;
  \"
"

# Download & extract WordPress
pct exec "$CTID" -- bash -c "
  cd /tmp &&
  wget https://wordpress.org/latest.tar.gz &&
  tar -xzf latest.tar.gz &&
  rm -rf ${INSTALL_DIR:?}/* &&
  mv wordpress/* ${INSTALL_DIR}/ &&
  rm -rf wordpress latest.tar.gz
"

# Configure and install WordPress
pct exec "$CTID" -- bash -c "
  cd ${INSTALL_DIR} &&
  /usr/local/bin/wp config create --dbname=${DB_NAME} --dbuser=${DB_USER} --dbpass=${DB_PASS} --allow-root &&
  /usr/local/bin/wp core install \
    --url='${SITE_URL}' \
    --title='${SITE_TITLE}' \
    --admin_user='${ADMIN_USER}' \
    --admin_password='${ADMIN_PASS}' \
    --admin_email='${ADMIN_EMAIL}' \
    --skip-email \
    --allow-root &&
  chown -R www-data:www-data ${INSTALL_DIR}
"

# Add HTTPS support if behind a reverse proxy
pct exec "$CTID" -- sed -i "/<?php/a if (isset(\$_SERVER['HTTP_X_FORWARDED_PROTO']) && \$_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') { \$_SERVER['HTTPS'] = 'on'; }" ${INSTALL_DIR}/wp-config.php

# === Log credentials ===
echo "$CTID,$SITE_URL,$DB_NAME,$DB_USER,$DB_PASS,$ADMIN_USER,$ADMIN_PASS" >> "$LOG_FILE"

echo "✅ WordPress installed at $SITE_URL"
echo "Credentials logged to: $LOG_FILE"
