#!/bin/sh
set -e

BASE_URL=${BASE_URL:-http://localhost:7770}
MYSQL_HOST=${MYSQL_HOST:-mysql}
MYSQL_PORT=${MYSQL_PORT:-3306}
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-1234567890}
MYSQL_PASSWORD=${MYSQL_PASSWORD:-MyPassword}
MYSQL_USER=${MYSQL_USER:-magentouser}
MYSQL_DATABASE=${MYSQL_DATABASE:-magentodb}

echo "Starting web-only container with external MySQL at $MYSQL_HOST:$MYSQL_PORT"

# Disable MySQL supervisor config since we're using external MySQL
if [ -f "/etc/supervisor.d/mysql.ini" ]; then 
    mv "/etc/supervisor.d/mysql.ini" "/etc/supervisor.d/mysql.disabled"
fi

# Keep other services enabled
for S in elasticsearch mailcatcher redis; do
    if [ -f "/etc/supervisor.d/$S" ]; then 
        mv "/etc/supervisor.d/$S" "/etc/supervisor.d/$S.ini"
    fi
done

# Create nginx directories
if [ ! -d "/var/tmp/nginx/client_body" ]; then
    mkdir -p /run/nginx /var/tmp/nginx/client_body
    chown nginx:nginx -R /run/nginx /var/tmp/nginx/
fi

# Wait for MySQL to be ready
echo "Waiting for MySQL to be ready..."
until mysql -h$MYSQL_HOST -P$MYSQL_PORT -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SELECT 1" > /dev/null 2>&1; do
    echo "Waiting for MySQL at $MYSQL_HOST:$MYSQL_PORT..."
    sleep 2
done
echo "MySQL is ready!"

# Configure Magento directly (always run to ensure BASE_URL is correct)
echo "Configuring Magento base URL to $BASE_URL..."
php81 /var/www/magento2/bin/magento setup:store-config:set --base-url="$BASE_URL" || true

# Update database configuration
echo "Updating ALL database URLs to $BASE_URL/..."
mysql -h$MYSQL_HOST -P$MYSQL_PORT -u$MYSQL_USER -p$MYSQL_PASSWORD $MYSQL_DATABASE -e "UPDATE core_config_data SET value='$BASE_URL/' WHERE path LIKE '%base_url%';" || true

php81 /var/www/magento2/bin/magento cache:flush || true

echo "Disabling product re-indexing..."
php81 /var/www/magento2/bin/magento indexer:set-mode schedule catalogrule_product || true
php81 /var/www/magento2/bin/magento indexer:set-mode schedule catalogrule_rule || true
php81 /var/www/magento2/bin/magento indexer:set-mode schedule catalogsearch_fulltext || true
php81 /var/www/magento2/bin/magento indexer:set-mode schedule catalog_category_product || true
php81 /var/www/magento2/bin/magento indexer:set-mode schedule customer_grid || true
php81 /var/www/magento2/bin/magento indexer:set-mode schedule design_config_grid || true
php81 /var/www/magento2/bin/magento indexer:set-mode schedule inventory || true
php81 /var/www/magento2/bin/magento indexer:set-mode schedule catalog_product_category || true
php81 /var/www/magento2/bin/magento indexer:set-mode schedule catalog_product_attribute || true
php81 /var/www/magento2/bin/magento indexer:set-mode schedule catalog_product_price || true
php81 /var/www/magento2/bin/magento indexer:set-mode schedule cataloginventory_stock || true

exec "$@"