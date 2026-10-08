#!/bin/bash
set -e

echo "=== ApplicationStart: Restarting services ==="

# Fix permissions one more time (cache writes can create root-owned files)
chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache

systemctl restart php8.2-fpm
systemctl restart nginx

# Make sure CodeDeploy agent is still alive
systemctl restart codedeploy-agent || true

echo "=== ApplicationStart: Done ==="