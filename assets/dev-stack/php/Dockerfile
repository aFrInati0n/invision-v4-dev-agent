# IC4 4.7.25 dev PHP-FPM
# Requirements per applications/core/data/requirements.json:
#   php >= 8.1.0 (8.2.0 recommended), mysql >= 5.5.3
# Base image: php:8.2-fpm (matches "recommended" version)
FROM php:8.2-fpm

# IC4 uses ext: curl, mbstring (install checks), intl, gd, pdo_mysql,
# redis + igbinary (caching), opcache (performance), bcmath, xml (always on in base)
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libcurl4-openssl-dev \
        libonig-dev \
        libicu-dev \
        libzip-dev \
        libjpeg62-turbo-dev \
        libpng-dev \
        libwebp-dev \
        libfreetype6-dev \
    # PHP >= 8.2: `docker-php-ext-install gd` no longer enables JPEG/WebP
    # automatically (--with-jpeg/--with-webp default to "no"); configure them
    # explicitly or theme installation fails with "No JPEG support in PHP build".
    && docker-php-ext-configure gd \
        --with-jpeg \
        --with-webp \
        --with-freetype \
    && docker-php-ext-install \
        curl \
        mbstring \
        intl \
        gd \
        pdo_mysql \
        mysqli \
        zip \
        exif \
        bcmath \
        opcache \
    && pecl install igbinary redis \
    && docker-php-ext-enable igbinary redis \
    && rm -rf /var/lib/apt/lists/*

# Dev tuning: opcache for dev, error visibility, upload limits
RUN printf '%s\n' \
    "opcache.enable_cli=1" \
    "opcache.jit=1" \
    "upload_max_filesize=64M" \
    "post_max_size=64M" \
    "max_execution_time=300" \
    "memory_limit=256M" \
    > /usr/local/etc/php/conf.d/zz-dev.ini

# FPM pool: pool.conf completes the base image's [www] pool (docker.conf
# declares [www] without user/group; www.conf is removed so our file must
# supply them under the SAME [www] section name — pool sections merge).
# clear_env=0 so environment: vars from compose reach PHP (IC4_DEV bypass).
RUN rm /usr/local/etc/php-fpm.d/www.conf
COPY conf/pool.conf /usr/local/etc/php-fpm.d/ic4-dev.conf
# Entrypoint: wait for db+redis, then start FPM in foreground
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
