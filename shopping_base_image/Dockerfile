FROM debian:12-slim

ENV MYSQL_ROOT_PASSWORD=1234567890 \
    MYSQL_DATABASE=magentodb \
    MYSQL_USER=magentouser \
    MYSQL_PASSWORD=MyPassword \
    COMPOSER_ALLOW_SUPERUSER=1 \
    PATH=/usr/share/java/elasticsearch/bin:$PATH \
    DEBIAN_FRONTEND=noninteractive

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
    php8.2-ctype \
    php8.2-curl \
    php8.2-dom \
    php8.2-fileinfo \
    php8.2-gd \
    php8.2-iconv \
    php8.2-intl \
    php8.2-mbstring \
    php8.2-mysql \
    php8.2-opcache \
    php8.2-phar \
    php8.2-simplexml \
    php8.2-soap \
    php8.2-tokenizer \
    php8.2-xml \
    php8.2-xmlreader \
    php8.2-xmlwriter \
    php8.2-xsl \
    php8.2-zip \
    composer \
    git \
    curl \
    wget \
    bash \
    cron \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create elastico user for Elasticsearch
RUN groupadd -g 1000 elastico && \
    useradd -m -u 1000 -g elastico -s /bin/bash elastico

# Install mailcatcher
RUN gem install mailcatcher --no-document

# Install Elasticsearch 7.17.0 from official tar (multi-platform support)
ARG TARGETARCH
RUN mkdir -p /usr/share/java && \
    if [ "$TARGETARCH" = "arm64" ]; then \
        ES_ARCH="aarch64"; \
    else \
        ES_ARCH="x86_64"; \
    fi && \
    wget -q https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-7.17.0-linux-${ES_ARCH}.tar.gz && \
    tar -xzf elasticsearch-7.17.0-linux-${ES_ARCH}.tar.gz -C /usr/share/java/ && \
    mv /usr/share/java/elasticsearch-7.17.0 /usr/share/java/elasticsearch && \
    rm -rf /usr/share/java/elasticsearch/modules/x-pack-ml/platform && \
    mkdir -p /var/lib/elasticsearch/_default/plugins && \
    echo "" >> /usr/share/java/elasticsearch/config/elasticsearch.yml && \
    echo "xpack.ml.enabled: false" >> /usr/share/java/elasticsearch/config/elasticsearch.yml && \
    echo "xpack.security.enabled: false" >> /usr/share/java/elasticsearch/config/elasticsearch.yml && \
    echo "xpack.monitoring.collection.enabled: false" >> /usr/share/java/elasticsearch/config/elasticsearch.yml && \
    echo "xpack.watcher.enabled: false" >> /usr/share/java/elasticsearch/config/elasticsearch.yml && \
    echo "ingest.geoip.downloader.enabled: false" >> /usr/share/java/elasticsearch/config/elasticsearch.yml && \
    echo "index.codec: best_compression" >> /usr/share/java/elasticsearch/config/elasticsearch.yml && \
    chown -R elastico:elastico /usr/share/java/elasticsearch && \
    chown -R elastico:elastico /var/lib/elasticsearch && \
    rm elasticsearch-7.17.0-linux-${ES_ARCH}.tar.gz && \
    # Create JDK symlink since we're using system Java instead of bundled JDK \
    ln -s /usr/lib/jvm/java-17-openjdk-$(dpkg --print-architecture) /usr/share/java/elasticsearch/jdk && \
    # Limit memory usage to 1GB (default tries to use 4GB) \
    mkdir -p /usr/share/java/elasticsearch/config/jvm.options.d && \
    echo "-Xms1024m" > /usr/share/java/elasticsearch/config/jvm.options.d/memory.options && \
    echo "-Xmx1024m" >> /usr/share/java/elasticsearch/config/jvm.options.d/memory.options

# Copy pre-indexed Elasticsearch data (104k products, ~850MB)
# This allows instant search on startup without 10-12 minute reindex
COPY --chown=elastico:elastico elasticsearch_data_upstream /usr/share/java/elasticsearch/data

# Configure PHP 8.2 as default and fix PHP-FPM user
RUN sed -i 's/^user = www-data/user = www-data/' /etc/php/8.2/fpm/pool.d/www.conf && \
    sed -i 's/^group = www-data/group = www-data/' /etc/php/8.2/fpm/pool.d/www.conf && \
    sed -i 's/^listen = .*/listen = 127.0.0.1:9000/' /etc/php/8.2/fpm/pool.d/www.conf

# Configure supervisor
COPY supervisor.d /etc/supervisor/conf.d
COPY supervisord.conf /etc/supervisor/supervisord.conf

# Configure nginx
COPY nginx-default.conf /etc/nginx/sites-available/magento.conf
RUN rm -f /etc/nginx/sites-enabled/default && \
    ln -s /etc/nginx/sites-available/magento.conf /etc/nginx/sites-enabled/magento.conf

# Configure MySQL/MariaDB
RUN mkdir -p /etc/mysql/conf.d && \
    printf "[mysqld]\nbind-address = 0.0.0.0\nskip-networking = 0\n" > /etc/mysql/conf.d/custom.cnf

# Set up Magento directory
RUN mkdir -p /var/www/magento2 && \
    chown -R www-data:www-data /var/www/magento2

# Copy Magento2 files extracted from shopping_final_0712 with fewer files and optimized images (jpg 30)
COPY --chown=www-data:www-data shopping_extracted/magento2 /var/www/magento2

EXPOSE 80 3306 9200 6379 88 25