FROM php:8.2-apache

# The equities analytics API talks to MySQL via mysqli.
RUN docker-php-ext-install mysqli && docker-php-ext-enable mysqli

# Application code is bind-mounted at /var/www/html at runtime (see docker-compose.yml),
# so there is nothing to COPY here.
