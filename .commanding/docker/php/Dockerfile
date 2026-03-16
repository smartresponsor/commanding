ARG PHP_VERSION=8.4
FROM php:${PHP_VERSION}-fpm-alpine

# Install system deps
RUN apk add --no-cache \
    bash git unzip icu-dev libzip-dev oniguruma-dev \
    postgresql-dev mysql-client \
    && docker-php-ext-install -j$(nproc) intl pdo pdo_pgsql pdo_mysql zip opcache \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && rm -rf /tmp/pear

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /app
