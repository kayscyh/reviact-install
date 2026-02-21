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
CURRENT_NODE=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)

if [ "$CURRENT_NODE" -lt "$REQUIRED_NODE" ]; then
    echo "⚠️  Node version $CURRENT_NODE is too low. Upgrading to v$REQUIRED_NODE..."
    npm install -g n
    n $REQUIRED_NODE
    hash -r
    echo "✅ Node upgraded to $(node -v)"
else
    echo "✅ Node version is sufficient ($(node -v))"
fi

# 3. Check for Yarn
if ! command -v yarn &> /dev/null; then
    echo "📦 Yarn not found. Installing..."
    npm install -g yarn
fi

# 4. Enter Directory & Backup .env
cd $PANEL_DIR || { echo "❌ Directory $PANEL_DIR not found!"; exit 1; }
cp .env .env.reviactyl.bak
echo "💾 Backup of .env created."

# 5. Maintenance Mode
php artisan down || echo "⚠️  Could not enter maintenance mode, continuing anyway..."

# 6. Download and Extract
echo "📥 Fetching latest Reviactyl release..."
if curl -L https://github.com/reviactyl/panel/releases/latest/download/panel.tar.gz | tar -xzv; then
    echo "✅ Files extracted."
else
    echo "❌ Download failed!"
    php artisan up
    exit 1
fi

# 7. Install Dependencies with Error Handling
echo "📦 Running Composer..."
composer install --no-dev --optimize-autoloader --no-interaction || { echo "❌ Composer failed!"; exit 1; }

echo "📦 Running Yarn Install..."
yarn install --ignore-engines || { echo "❌ Yarn install failed!"; exit 1; }

# 8. The Build Process
echo "🏗️  Building assets (Webpack)..."
if yarn build:production; then
    echo "✅ Build successful."
else
    echo "❌ Build failed! Check your RAM and Node version."
    php artisan up
    exit 1
fi

# 9. Permissions & Cleanup
echo "🔐 Finalizing permissions and cache..."
chown -R www-data:www-data $PANEL_DIR/*
php artisan migrate --force
php artisan view:clear
php artisan config:clear
php artisan cache:clear

# 10. Bring it back up
php artisan up
echo "✨ DONE! Reviactyl is ready."
