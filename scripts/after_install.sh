#!/bin/bash
set -e

APP_DIR=/var/www/html
cd $APP_DIR

echo "=== AfterInstall: Setting up Laravel ==="

# ---------- Clear stale caches from previous deploys ----------
rm -f $APP_DIR/bootstrap/cache/config.php
rm -f $APP_DIR/bootstrap/cache/routes-v7.php
rm -f $APP_DIR/bootstrap/cache/packages.php
rm -f $APP_DIR/bootstrap/cache/services.php
rm -rf $APP_DIR/storage/framework/views/*
rm -rf $APP_DIR/storage/framework/cache/data/*

# ---------- Fetch config from SSM Parameter Store ----------
PARAM_PREFIX="/task-manager/prod"
REGION="eu-central-1"

echo "Fetching configuration from SSM..."
DB_HOST=$(aws ssm get-parameter --region $REGION --name "${PARAM_PREFIX}/DB_HOST" --query "Parameter.Value" --output text)
DB_PORT=$(aws ssm get-parameter --region $REGION --name "${PARAM_PREFIX}/DB_PORT" --query "Parameter.Value" --output text)
DB_DATABASE=$(aws ssm get-parameter --region $REGION --name "${PARAM_PREFIX}/DB_DATABASE" --query "Parameter.Value" --output text)
DB_USERNAME=$(aws ssm get-parameter --region $REGION --name "${PARAM_PREFIX}/DB_USERNAME" --query "Parameter.Value" --output text)
DB_PASSWORD=$(aws ssm get-parameter --region $REGION --name "${PARAM_PREFIX}/DB_PASSWORD" --with-decryption --query "Parameter.Value" --output text)
REDIS_HOST=$(aws ssm get-parameter --region $REGION --name "${PARAM_PREFIX}/REDIS_HOST" --query "Parameter.Value" --output text)
REDIS_PORT=$(aws ssm get-parameter --region $REGION --name "${PARAM_PREFIX}/REDIS_PORT" --query "Parameter.Value" --output text)
AWS_BUCKET=$(aws ssm get-parameter --region $REGION --name "${PARAM_PREFIX}/AWS_BUCKET" --query "Parameter.Value" --output text)
SNS_TOPIC_ARN=$(aws ssm get-parameter --region $REGION --name "${PARAM_PREFIX}/SNS_TOPIC_ARN" --query "Parameter.Value" --output text)

# ---------- Generate .env from SSM values ----------
cat > $APP_DIR/.env <<EOF
APP_NAME="Task Manager"
APP_ENV=production
APP_KEY=
APP_DEBUG=false
APP_URL=http://localhost

LOG_CHANNEL=stack
LOG_LEVEL=error

DB_CONNECTION=mysql
DB_HOST=${DB_HOST}
DB_PORT=${DB_PORT}
DB_DATABASE=${DB_DATABASE}
DB_USERNAME=${DB_USERNAME}
DB_PASSWORD=${DB_PASSWORD}

REDIS_CLIENT=predis
REDIS_HOST=${REDIS_HOST}
REDIS_PORT=${REDIS_PORT}
REDIS_PASSWORD=null

SESSION_DRIVER=redis
SESSION_LIFETIME=120
SESSION_ENCRYPT=false
SESSION_PATH=/
SESSION_DOMAIN=null

CACHE_STORE=redis
QUEUE_CONNECTION=redis
FILESYSTEM_DISK=s3

AWS_DEFAULT_REGION=${REGION}
AWS_BUCKET=${AWS_BUCKET}
AWS_USE_PATH_STYLE_ENDPOINT=false

SNS_TOPIC_ARN=${SNS_TOPIC_ARN}

MAIL_MAILER=log
EOF

# ---------- File permissions ----------
chown -R www-data:www-data $APP_DIR
chmod -R 775 $APP_DIR/storage $APP_DIR/bootstrap/cache 2>/dev/null || true

# ---------- Recreate health endpoint (wiped by BeforeInstall) ----------
echo "OK" > $APP_DIR/public/health
chown www-data:www-data $APP_DIR/public/health

# ---------- Composer install (no dev) ----------
sudo -u www-data COMPOSER_HOME=/tmp/composer composer install \
    --no-dev \
    --no-interaction \
    --prefer-dist \
    --optimize-autoloader \
    --no-progress

# ---------- App key ----------
if ! grep -q "^APP_KEY=base64:" $APP_DIR/.env; then
    sudo -u www-data php artisan key:generate --force
fi

# ---------- Caches (non-fatal if any fail) ----------
sudo -u www-data php artisan config:cache || echo "config:cache failed"
sudo -u www-data php artisan route:cache || echo "route:cache failed"
sudo -u www-data php artisan view:cache || echo "view:cache skipped"

# ---------- Run migrations ----------
sudo -u www-data php artisan migrate --force || echo "Migration failed (may retry on next deploy)"

echo "=== AfterInstall: Done ==="