FROM debian:12-slim

ENV MYSQL_ROOT_PASSWORD=1234567890 \
    MYSQL_DATABASE=magentodb \
    MYSQL_USER=magentouser \
    MYSQL_PASSWORD=MyPassword \
    COMPOSER_ALLOW_SUPERUSER=1

# Install required packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    supervisor \
    nginx \
    mariadb-server mariadb-client \
    redis-server \
    openjdk-17-jre-headless \
    ruby ruby-dev \
    build-essential \
    libffi-dev \
    php8.2 \
    php8.2-fpm \
    php8.2-bcmath \
    php8.2-curl \
    php8.2-gd \
    php8.2-intl \
    php8.2-mbstring \
    php8.2-mysql \
    php8.2-opcache \
    php8.2-soap \
    php8.2-xml \
    php8.2-xsl \
    php8.2-zip \
    composer \
    git \
    curl \
    wget \
    gnupg \
    ca-certificates \
    lsb-release \
    cron \
    && rm -rf /var/lib/apt/lists/*

# Install Elasticsearch from official repo (supports ARM64)
RUN wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | gpg --dearmor -o /usr/share/keyrings/elastic.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/elastic.gpg] https://artifacts.elastic.co/packages/7.x/apt stable main" > /etc/apt/sources.list.d/elastic-7.x.list && \
    apt-get update && \
    apt-get install -y elasticsearch && \
    rm -rf /var/lib/apt/lists/*

RUN gem install mailcatcher --no-document

# Elasticsearch user is created by the package installation
# Just ensure the directory permissions are correct
RUN mkdir -p /usr/share/elasticsearch && \
    chown -R elasticsearch:elasticsearch /usr/share/elasticsearch

# PHP 8.2 is already the default in Debian 12
# Create php-fpm symlink for compatibility
RUN ln -s /usr/sbin/php-fpm8.2 /usr/local/sbin/php-fpm

COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY supervisor.d /etc/supervisor.d
COPY supervisord.conf /etc/supervisord.conf

RUN chmod +x /docker-entrypoint.sh

RUN mkdir -p /var/www/magento2 && \
    chown -R www-data:www-data /var/www/magento2

# Copy optimized Magento2 files with jpg30 images
COPY --chown=www-data:www-data shopping_extracted/magento2 /var/www/magento2

EXPOSE 80 3306 9200 6379 88 25

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["supervisord", "-n", "-j", "/supervisord.pid"]