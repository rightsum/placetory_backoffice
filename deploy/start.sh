#!/bin/bash

# Start script for Laravel Octane with FrankenPHP
# This script runs Laravel optimizations at runtime when environment variables are available

set -e

echo "Starting Laravel application..."

# Clear any existing cached config that might have wrong values
echo "Clearing Laravel caches..."
php artisan config:clear || true
php artisan route:clear || true
php artisan view:clear || true

# Run Laravel optimizations with proper environment variables
echo "Optimizing Laravel..."
php artisan config:cache
php artisan route:cache
php artisan view:cache

# Run database migrations if needed (optional)
# Run database migrations if LARAVEL_MIGRATE is set to true
if [ "$LARAVEL_MIGRATE" = "true" ]; then
    echo "Running database migrations..."
    php artisan migrate --force
fi

echo "Starting Laravel Octane with FrankenPHP..."
exec php artisan octane:start --server=frankenphp --host=0.0.0.0 --port=8080
