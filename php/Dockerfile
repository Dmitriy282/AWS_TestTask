FROM php:8.3-fpm-alpine

RUN docker-php-ext-install pdo_mysql mysqli

WORKDIR /var/www/html
COPY . .
