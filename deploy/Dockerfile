FROM dunglas/frankenphp

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libpq-dev \
    zip \
    unzip \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-install pdo_pgsql pgsql mbstring exif pcntl bcmath gd

# Install Redis extension
RUN pecl install redis && docker-php-ext-enable redis

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /app

# Copy composer files first for better caching
COPY composer.json composer.lock ./

# Install PHP dependencies (skip scripts that require artisan)
RUN composer install --no-dev --optimize-autoloader --no-interaction --no-scripts

# Copy package.json and package-lock.json for npm
COPY package.json package-lock.json ./

# Install Node.js dependencies (including dev dependencies for build)
RUN npm ci --no-audit --no-fund

# Copy all application code (but not node_modules)
COPY . .

# Verify resources directory was copied
RUN ls -la resources/js/pages/ | head -10

# Run composer scripts now that artisan is available
RUN composer run-script post-autoload-dump

# Build frontend assets (this needs devDependencies)
RUN npm run build

# Verify that assets were built correctly and show detailed information
RUN echo "=== Build assets verification ===" && \
    ls -la public/build/ && \
    echo "=== JS directory ===" && \
    ls -la public/build/js/ && \
    echo "=== JS pages directory ===" && \
    ls -la public/build/js/pages/ | head -10 && \
    echo "=== CSS directory ===" && \
    ls -la public/build/css/ && \
    echo "=== Checking specific layout.js file ===" && \
    ls -la public/build/js/pages/layout.js

# Remove node_modules entirely to save space (built assets are already in public/build)
RUN rm -rf node_modules

# Set proper permissions for web assets
RUN chown -R www-data:www-data /app/public \
    && chmod -R 755 /app/public

# Set proper permissions
RUN chown -R www-data:www-data /app \
    && chmod -R 755 /app/storage \
    && chmod -R 755 /app/bootstrap/cache

# Copy and make startup script executable
COPY deploy/start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

# Expose port
EXPOSE 8080

# Set environment variables
ENV APP_ENV=production
ENV APP_DEBUG=false

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Start Laravel with proper initialization
CMD ["/usr/local/bin/start.sh"]
