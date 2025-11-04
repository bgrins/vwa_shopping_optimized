FROM alpine:3.16

ENV MYSQL_ROOT_PASSWORD=1234567890 \
    MYSQL_DATABASE=magentodb \
    MYSQL_USER=magentouser \
    MYSQL_PASSWORD=MyPassword \
    COMPOSER_ALLOW_SUPERUSER=1

RUN apk update && apk add --no-cache \
    supervisor \
    nginx \
    mysql mysql-client \
    redis \
    openjdk11-jre \
    ruby ruby-dev \
    build-base \
    libffi-dev \
    php81 \
    php81-fpm \
    php81-bcmath \
    php81-ctype \
    php81-curl \
    php81-dom \
    php81-fileinfo \
    php81-gd \
    php81-iconv \
    php81-intl \
    php81-json \
    php81-mbstring \
    php81-mysqli \
    php81-opcache \
    php81-openssl \
    php81-pdo \
    php81-pdo_mysql \
    php81-phar \
    php81-session \
    php81-simplexml \
    php81-soap \
    php81-sodium \
    php81-tokenizer \
    php81-xml \
    php81-xmlreader \
    php81-xmlwriter \
    php81-xsl \
    php81-zip \
    php81-zlib \
    composer \
    git \
    curl \
    bash \
    cronie

# Elasticsearch will need to be installed manually or run as separate container
# Not available as Alpine package

RUN gem install mailcatcher --no-document

# Configure PHP 8.1 as default and fix PHP-FPM user
RUN rm -f /usr/bin/php && \
    ln -s /usr/bin/php81 /usr/bin/php && \
    sed -i 's/^user = nobody/user = nginx/' /etc/php81/php-fpm.d/www.conf && \
    sed -i 's/^group = nobody/group = nginx/' /etc/php81/php-fpm.d/www.conf

# Create elasticsearch user for compatibility even if ES isn't installed
# Also create a dummy elasticsearch command that just sleeps
RUN adduser -D -h /usr/share/java/elasticsearch elastico && \
    mkdir -p /usr/share/java/elasticsearch && \
    chown -R elastico:elastico /usr/share/java/elasticsearch && \
    echo '#!/bin/sh' > /usr/bin/elasticsearch && \
    echo 'echo "Elasticsearch not installed, sleeping..."' >> /usr/bin/elasticsearch && \
    echo 'sleep infinity' >> /usr/bin/elasticsearch && \
    chmod +x /usr/bin/elasticsearch

COPY supervisor.d /etc/supervisor.d
COPY supervisord.conf /etc/supervisord.conf
COPY nginx-default.conf /etc/nginx/http.d/magento.conf

RUN rm -f /etc/nginx/http.d/default.conf /etc/nginx/conf.d/default.conf && \
    echo -e "[mysqld]\nbind-address = 0.0.0.0\nskip-networking = 0" >> /etc/my.cnf

RUN mkdir -p /var/www/magento2 && \
    chown -R nginx:nginx /var/www/magento2

# Copy optimized Magento2 files with jpg30 images
COPY --chown=nginx:nginx shopping_extracted/magento2 /var/www/magento2

EXPOSE 80 3306 9200 6379 88 25