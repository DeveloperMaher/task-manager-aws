#!/bin/bash
set -e

echo "=== ValidateService: Checking app is healthy ==="

# Wait up to 30s for PHP-FPM to bind
for i in {1..6}; do
    if systemctl is-active --quiet php8.2-fpm; then
        echo "PHP-FPM is running."
        break
    fi
    echo "Waiting for PHP-FPM..."
    sleep 5
done

# Health check via Nginx
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/health)

if [ "$HTTP_CODE" = "200" ]; then
    echo "Health check passed (HTTP 200)."
    exit 0
else
    echo "Health check FAILED (HTTP $HTTP_CODE)."
    exit 1
fi