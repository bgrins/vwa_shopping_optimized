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
    elasticsearch \
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

RUN gem install mailcatcher --no-document

RUN adduser -D -h /usr/share/java/elasticsearch elasticsearch && \
    mkdir -p /usr/share/java/elasticsearch && \
    chown -R elasticsearch:elasticsearch /usr/share/java/elasticsearch

RUN ln -s /usr/bin/php81 /usr/bin/php && \
    ln -s /usr/sbin/php-fpm81 /usr/local/sbin/php-fpm

COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY supervisor.d /etc/supervisor.d
COPY supervisord.conf /etc/supervisord.conf

RUN chmod +x /docker-entrypoint.sh

RUN mkdir -p /var/www/magento2 && \
    chown -R www-data:www-data /var/www/magento2

EXPOSE 80 3306 9200 6379 88 25

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["supervisord", "-n", "-j", "/supervisord.pid"]