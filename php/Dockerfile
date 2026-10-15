FROM php:8.3-fpm-alpine

RUN docker-php-ext-install pdo_mysql mysqli

# phpredis for the shared hit counter; build tools are removed after the build
RUN apk add --no-cache --virtual .build-deps $PHPIZE_DEPS \
    && pecl install redis-6.1.0 \
    && docker-php-ext-enable redis \
    && apk del .build-deps

# Hit counter runs before every PHP script (auto_prepend_file); it lives outside the web root
COPY hits/counter.php /usr/local/lib/hits/counter.php
COPY hits/hits.ini /usr/local/etc/php/conf.d/hits.ini

WORKDIR /var/www/html
COPY public/ .
