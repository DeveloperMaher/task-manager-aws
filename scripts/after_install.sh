#!/bin/bash
set -e

APP_DIR=/var/www/html
cd $APP_DIR

echo "=== AfterInstall: Setting up Laravel ==="

# ---------- Generate .env from environment variables ----------
cat > $APP_DIR/.env <<EOF
APP_NAME="${APP_NAME:-Task Manager}"
APP_ENV=${APP_ENV:-production}
APP_KEY=
APP_DEBUG=${APP_DEBUG:-false}
APP_URL=${APP_URL:-http://localhost}

LOG_CHANNEL=stack
LOG_LEVEL=error

DB_CONNECTION=mysql
DB_HOST=${DB_HOST}
DB_PORT=${DB_PORT:-3306}
DB_DATABASE=${DB_DATABASE:-task_manager}
DB_USERNAME=${DB_USERNAME:-admin}
DB_PASSWORD=${DB_PASSWORD}

REDIS_CLIENT=predis
REDIS_HOST=${REDIS_HOST}
REDIS_PORT=${REDIS_PORT:-6379}
REDIS_PASSWORD=null

SESSION_DRIVER=redis
SESSION_LIFETIME=120
SESSION_ENCRYPT=false
SESSION_PATH=/
SESSION_DOMAIN=null

CACHE_STORE=redis
QUEUE_CONNECTION=redis
FILESYSTEM_DISK=s3

AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-eu-central-1}
AWS_BUCKET=${AWS_BUCKET}
AWS_USE_PATH_STYLE_ENDPOINT=false

SNS_TOPIC_ARN=${SNS_TOPIC_ARN}

MAIL_MAILER=log
EOF

# ---------- File permissions ----------
chown -R www-data:www-data $APP_DIR
chmod -R 775 $APP_DIR/storage $APP_DIR/bootstrap/cache 2>/dev/null || true

# ---------- Composer install (no dev) ----------
sudo -u www-data composer install \
    --no-dev \
    --no-interaction \
    --prefer-dist \
    --optimize-autoloader \
    --no-progress

# ---------- App key ----------
if ! grep -q "^APP_KEY=base64:" $APP_DIR/.env; then
    sudo -u www-data php artisan key:generate --force
fi

# ---------- Caches ----------
sudo -u www-data php artisan config:cache
sudo -u www-data php artisan route:cache
sudo -u www-data php artisan view:cache

# ---------- Run migrations ----------
sudo -u www-data php artisan migrate --force || echo "Migration failed (may retry on next deploy)"

echo "=== AfterInstall: Done ==="