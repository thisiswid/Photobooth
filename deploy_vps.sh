#!/usr/bin/env bash

# ==============================================================================
# SnapTech Photobooth — Automated VPS Setup Script
# Target OS: Ubuntu 24.04 LTS (x86_64)
# Domain: snaptechbooth.my.id
# ==============================================================================

set -e

DOMAIN="snaptechbooth.my.id"
DB_NAME="lumabooth"
DB_USER="lumabooth"
DB_PASS="LumaBoothSecurePass2026!"
APP_DIR="/var/www/snaptechbooth"

echo "============================================================"
echo "Starting Automated Setup for ..."
echo "============================================================"

# 1. Update system packages
echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y software-properties-common curl git unzip zip htop ufw supervisor nginx postgresql postgresql-contrib certbot python3-certbot-nginx ffmpeg

# 2. Setup 2GB Swap Memory (Prevent Out-Of-Memory)
if [ ! -f /swapfile ]; then
    echo "Creating 2GB Swap Memory..."
    sudo fallocate -l 2G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf
    sudo sysctl -p
fi

# 3. Install PHP 8.3 and required extensions
echo "Installing PHP 8.3 & Extensions..."
sudo add-apt-repository -y ppa:ondrej/php
sudo apt update
sudo apt install -y php8.3 php8.3-fpm php8.3-cli php8.3-pgsql php8.3-mbstring \
    php8.3-xml php8.3-curl php8.3-zip php8.3-gd php8.3-imagick php8.3-bcmath \
    php8.3-intl php8.3-sqlite3 php8.3-redis

# 4. Install Composer
if ! command -v composer &> /dev/null; then
    echo "Installing Composer..."
    curl -sS https://getcomposer.org/installer | php
    sudo mv composer.phar /usr/local/bin/composer
    sudo chmod +x /usr/local/bin/composer
fi

# 5. Setup PostgreSQL Database
echo "Configuring PostgreSQL Database..."
sudo -u postgres psql -c "SELECT 1 FROM pg_database WHERE datname = ''" | grep -q 1 || \
sudo -u postgres psql -c "CREATE DATABASE ;"

sudo -u postgres psql -c "SELECT 1 FROM pg_roles WHERE rolname = ''" | grep -q 1 || \
sudo -u postgres psql -c "CREATE USER  WITH ENCRYPTED PASSWORD '';"

sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE  TO ;"
sudo -u postgres psql -d  -c "GRANT ALL ON SCHEMA public TO ;"
sudo -u postgres psql -d  -c "ALTER SCHEMA public OWNER TO ;"

# 6. Setup Directory & Clone / Prepare Project
echo "Setting up project directory at ..."
sudo mkdir -p /var/www
if [ ! -d "/.git" ]; then
    echo "Cloning repository from GitHub..."
    sudo git clone https://github.com/thisiswid/Photobooth.git ""
else
    echo "Updating existing repository..."
    cd ""
    sudo git fetch --all
    sudo git reset --hard origin/dev/session-1-fixes || sudo git pull
fi

cd "/laravel_backend"

# 7. Configure .env file
echo "Creating .env configuration..."
if [ ! -f .env ]; then
    sudo cp .env.example .env
fi

sudo sed -i "s|^APP_NAME=.*|APP_NAME=\"SnapTech Booth\"|" .env
sudo sed -i "s|^APP_ENV=.*|APP_ENV=production|" .env
sudo sed -i "s|^APP_DEBUG=.*|APP_DEBUG=false|" .env
sudo sed -i "s|^APP_URL=.*|APP_URL=https://|" .env

sudo sed -i "s|^DB_CONNECTION=.*|DB_CONNECTION=pgsql|" .env
sudo sed -i "s|^# DB_HOST=.*|DB_HOST=127.0.0.1|" .env
sudo sed -i "s|^DB_HOST=.*|DB_HOST=127.0.0.1|" .env
sudo sed -i "s|^# DB_PORT=.*|DB_PORT=5432|" .env
sudo sed -i "s|^DB_PORT=.*|DB_PORT=5432|" .env
sudo sed -i "s|^# DB_DATABASE=.*|DB_DATABASE=|" .env
sudo sed -i "s|^DB_DATABASE=.*|DB_DATABASE=|" .env
sudo sed -i "s|^# DB_USERNAME=.*|DB_USERNAME=|" .env
sudo sed -i "s|^DB_USERNAME=.*|DB_USERNAME=|" .env
sudo sed -i "s|^# DB_PASSWORD=.*|DB_PASSWORD=|" .env
sudo sed -i "s|^DB_PASSWORD=.*|DB_PASSWORD=|" .env

sudo sed -i "s|^FILESYSTEM_DISK=.*|FILESYSTEM_DISK=public|" .env
sudo sed -i "s|^QUEUE_CONNECTION=.*|QUEUE_CONNECTION=database|" .env

# 8. Install PHP dependencies & Run Migrations
echo "Installing Composer dependencies..."
sudo composer install --no-dev --optimize-autoloader --no-interaction

echo "Generating App Key & Linking Storage..."
sudo php artisan key:generate --force
sudo php artisan storage:link || true

echo "Running Migrations and Seeders..."
sudo php artisan migrate --force --seed

# 9. Set permissions
echo "Setting permissions for www-data..."
sudo chown -R www-data:www-data ""
sudo chmod -R 775 "/laravel_backend/storage"
sudo chmod -R 775 "/laravel_backend/bootstrap/cache"

# 10. Configure Nginx
echo "Configuring Nginx for ..."
cat << 'EOF' | sudo tee /etc/nginx/sites-available/snaptechbooth.my.id
server {
    listen 80;
    listen [::]:80;
    server_name snaptechbooth.my.id www.snaptechbooth.my.id;
    root /var/www/snaptechbooth/laravel_backend/public;

    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";

    index index.php index.html;
    charset utf-8;

    client_max_body_size 100M;

    location / {
        try_files \ \/ /index.php?\;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    error_page 404 /index.php;

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \\;
        include fastcgi_params;
        fastcgi_hide_header X-Powered-By;
        fastcgi_read_timeout 300;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/snaptechbooth.my.id /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx

# 11. Configure Supervisor (Queue Worker)
echo "Configuring Supervisor for Laravel Queue..."
cat << 'EOF' | sudo tee /etc/supervisor/conf.d/snaptech-worker.conf
[program:snaptech-worker]
process_name=%(program_name)s_%(process_num)02d
command=php /var/www/snaptechbooth/laravel_backend/artisan queue:work database --sleep=3 --tries=3 --max-time=3600
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
user=www-data
numprocs=2
redirect_stderr=true
stdout_logfile=/var/www/snaptechbooth/laravel_backend/storage/logs/worker.log
stopwaitsecs=3600
EOF

sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl start all

# 12. Setup Scheduled Cron Jobs
echo "Setting up Laravel Scheduler Cron..."
(crontab -l 2>/dev/null | grep -v "artisan schedule:run"; echo "* * * * * cd /var/www/snaptechbooth/laravel_backend && php artisan schedule:run >> /dev/null 2>&1") | crontab -

# 13. Obtain Free SSL with Certbot
echo "Requesting SSL Certificate from Let's Encrypt..."
sudo certbot --nginx -d snaptechbooth.my.id --non-interactive --agree-tos -m admin@snaptechbooth.my.id --redirect || true

# 14. Optimize Laravel
echo "Optimizing Laravel..."
cd "/laravel_backend"
sudo php artisan config:cache
sudo php artisan route:cache
sudo php artisan view:cache

# 15. Configure Firewall
echo "Configuring Firewall (UFW)..."
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
echo "y" | sudo ufw enable

echo "============================================================"
echo "DEPLOYMENT COMPLETE!"
echo "============================================================"
echo "URL Admin Panel: https:///admin"
echo "Super Admin Login:"
echo "   - Email: superadmin@photobooth.com"
echo "   - Pass : password"
echo "Cafe Admin Login:"
echo "   - Email: admin@fakultaskopi.com"
echo "   - Pass : password"
echo "API Base URL: https:///api"
echo "============================================================"
