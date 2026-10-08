#!/bin/bash
set -e

echo "=== BeforeInstall: Cleaning old release ==="

# Clean previous release (but keep .env and storage)
if [ -d /var/www/html ]; then
    rm -rf /var/www/html/* 2>/dev/null || true
    rm -rf /var/www/html/.[!.]* 2>/dev/null || true
fi

mkdir -p /var/www/html
chown -R www-data:www-data /var/www/html

echo "=== BeforeInstall: Done ==="