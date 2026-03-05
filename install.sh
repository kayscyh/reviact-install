#!/bin/bash

# --- CONFIGURATION ---
PANEL_DIR="/var/www/pterodactyl"
REQUIRED_NODE=22

echo "🚀 Starting Robust Reviactyl Installation..."

# 1. Check if running as root
if [ "$EUID" -ne 0 ]; then 
  echo "❌ Please run as root."
  exit 1
fi

# 2. Check/Update Node.js Version
echo "🔍 Checking Node.js version..."
if ! command -v node &> /dev/null; then
    echo "🌐 Installing Node.js v$REQUIRED_NODE..."
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
    apt install -y nodejs
else
    CURRENT_NODE=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$CURRENT_NODE" -lt "$REQUIRED_NODE" ]; then
        echo "⚠️  Upgrading Node to v$REQUIRED_NODE..."
        npm install -g n && n $REQUIRED_NODE && hash -r
    fi
fi

# 3. Ensure Build Tools Exist
for cmd in yarn composer; do
    if ! command -v $cmd &> /dev/null; then
        echo "📦 $cmd not found. Installing..."
        [ "$cmd" == "yarn" ] && npm install -g yarn
        [ "$cmd" == "composer" ] && apt install -y composer
    fi
done

# 4. Directory & Backup Logic
cd $PANEL_DIR || { echo "❌ Directory $PANEL_DIR not found!"; exit 1; }

if [ -f ".env" ]; then
    cp .env .env.reviactyl.bak
    echo "💾 Backup of .env created."
    php artisan down || echo "⚠️  Entering maintenance mode..."
fi

# 5. Download & Extract
echo "📥 Fetching Reviactyl files..."
if curl -L https://github.com/reviactyl/panel/releases/latest/download/panel.tar.gz | tar -xzv; then
    echo "✅ Extraction complete."
else
    echo "❌ Download failed!"
    [ -f "artisan" ] && php artisan up
    exit 1
fi

# 6. Build Phase
echo "🏗️  Building assets (this uses significant RAM)..."
export NODE_OPTIONS=--openssl-legacy-provider
composer install --no-dev --optimize-autoloader --no-interaction
yarn install --ignore-engines
yarn build:production || { echo "❌ Build failed!"; php artisan up; exit 1; }

# 7. THE SAFETY NET: Permissions & Optimization
echo "🔐 Restoring permissions for www-data..."
chown -R www-data:www-data $PANEL_DIR/*
chmod -R 755 storage/* bootstrap/cache

if [ -f ".env" ]; then
    php artisan migrate --force
    php artisan view:clear
    php artisan config:clear
    php artisan up
fi

echo "✨ SUCCESS! Your Green Node is safe and Reviactyl is live."
