#!/bin/sh
set -e

BASE_URL=${BASE_URL:-http://localhost:7770}
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-1234567890}
MYSQL_PASSWORD=${MYSQL_PASSWORD:-MyPassword}
MYSQL_USER=${MYSQL_USER:-magentouser}
MYSQL_DATABASE=${MYSQL_DATABASE:-magentodb}
REDIS_HOST=${REDIS_HOST:-127.0.0.1}
REDIS_PORT=${REDIS_PORT:-6379}
REDIS_PASSWORD=${REDIS_PASSWORD:-}

DISABLE=",$DISABLE,"

# Auto-disable local Redis if external Redis is configured
if [ "$REDIS_HOST" != "127.0.0.1" ] && [ "$REDIS_HOST" != "localhost" ]; then
  echo "External Redis configured at $REDIS_HOST:$REDIS_PORT, disabling local Redis..."
  DISABLE="$DISABLE,redis"
fi

for S in elasticsearch mailcatcher mysql redis; do
  DS=$(echo $DISABLE | grep -q ",$S," && echo "YES"  || echo "NO")
  if [ "$DS" = "YES" ]; then
    if [ -f "/etc/supervisor/conf.d/$S.ini" ]; then mv "/etc/supervisor/conf.d/$S.ini" "/etc/supervisor/conf.d/$S"; fi
  else
    if [ -f "/etc/supervisor/conf.d/$S" ]; then mv "/etc/supervisor/conf.d/$S" "/etc/supervisor/conf.d/$S.ini"; fi
  fi
done

DISABLE_MYSQL=$(echo $DISABLE | grep -q ",mysql," && echo "YES"  || echo "NO")

if [ ! -d "/var/tmp/nginx/client_body" ]; then
  mkdir -p /run/nginx /var/tmp/nginx/client_body
  chown www-data:www-data -R /run/nginx /var/tmp/nginx/
fi

if [ "$DISABLE_MYSQL" != "YES" ]; then
  # Check if we should reset to golden state
  RESET_DB_ON_START=${RESET_DB_ON_START:-false}
  
  if [ "$RESET_DB_ON_START" = "true" ] && [ -d "/var/lib/mysql.golden" ]; then
    echo "RESET_DB_ON_START is true, resetting database to golden state..."
    rm -rf /var/lib/mysql
    cp -R /var/lib/mysql.golden /var/lib/mysql
    chown -R mysql:mysql /var/lib/mysql
    rm -f /run/mysqld/.init
    echo "Database reset to golden state complete"
  fi
  
  if [ ! -f "/run/mysqld/.init" ]; then
    echo "Initializing MySQL runtime directories..."
    mkdir -p /run/mysqld
    chown mysql:mysql -R /run/mysqld
    
    # Check if database already exists (from build stage)
    if [ -d "/var/lib/mysql/mysql" ]; then
      echo "Using pre-built database from image"
    elif [ -d "/var/lib/mysql.golden" ]; then
      echo "Restoring database from golden state..."
      cp -R /var/lib/mysql.golden /var/lib/mysql
      chown -R mysql:mysql /var/lib/mysql
    else
      # Fallback: create empty database if no golden state exists
      echo "No pre-built database found, creating empty database..."
      mkdir -p /var/lib/mysql
      chown mysql:mysql -R /var/lib/mysql
      mysql_install_db --user=mysql --datadir=/var/lib/mysql
      
      SQL=$(mktemp)
      echo "CREATE DATABASE IF NOT EXISTS $MYSQL_DATABASE CHARACTER SET utf8 COLLATE utf8_general_ci;" >> $SQL
      echo "GRANT ALL ON $MYSQL_DATABASE.* to '$MYSQL_USER'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';" >> $SQL
      echo "GRANT ALL ON $MYSQL_DATABASE.* to '$MYSQL_USER'@'127.0.0.1' IDENTIFIED BY '$MYSQL_PASSWORD';" >> $SQL
      echo "GRANT ALL ON $MYSQL_DATABASE.* to '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD';" >> $SQL
      echo "ALTER user 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD';" >> $SQL
      echo "DELETE FROM mysql.user WHERE User = '' OR Password = '';" >> $SQL
      echo "FLUSH PRIVILEGES;" >> $SQL
      
      cat "$SQL" | mysqld --user=mysql --bootstrap --silent-startup --skip-grant-tables=FALSE
      rm -f $SQL
    fi
    
    touch /run/mysqld/.init
  fi
  
  # Set MYSQL_HOST for internal MySQL (needs to be outside the init block!)
  MYSQL_HOST=localhost
else
  echo "Using external MySQL at $MYSQL_HOST:$MYSQL_PORT"
fi

# Configure Redis if external host is specified
if [ "$REDIS_HOST" != "127.0.0.1" ] || [ "$REDIS_PORT" != "6379" ] || [ -n "$REDIS_PASSWORD" ]; then
  echo "Configuring Magento to use Redis at $REDIS_HOST:$REDIS_PORT..."
  php /var/www/magento2/bin/magento setup:config:set \
    --cache-backend=redis \
    --cache-backend-redis-server="$REDIS_HOST" \
    --cache-backend-redis-port="$REDIS_PORT" \
    --cache-backend-redis-password="$REDIS_PASSWORD" \
    --cache-backend-redis-db=0 \
    --page-cache=redis \
    --page-cache-redis-server="$REDIS_HOST" \
    --page-cache-redis-port="$REDIS_PORT" \
    --page-cache-redis-password="$REDIS_PASSWORD" \
    --page-cache-redis-db=1 \
    --session-save=redis \
    --session-save-redis-host="$REDIS_HOST" \
    --session-save-redis-port="$REDIS_PORT" \
    --session-save-redis-password="$REDIS_PASSWORD" \
    --session-save-redis-db=2 \
    -n 2>/dev/null || true
fi

# Configure Magento directly (always run to ensure BASE_URL is correct)
echo "Configuring Magento base URL to $BASE_URL..."
# This may fail if Redis isn't up yet, that's OK
php /var/www/magento2/bin/magento setup:store-config:set --base-url="$BASE_URL" 2>/dev/null || true

if [ "$DISABLE_MYSQL" != "YES" ]; then
  # Launch background script to update URLs after MySQL is ready
  echo "Scheduling database URL update..."
  nohup /usr/local/bin/update-magento-urls.sh > /var/log/update-urls.log 2>&1 &
fi

# Cache flush may fail if Redis isn't up yet
php /var/www/magento2/bin/magento cache:flush 2>/dev/null || true

echo "Disabling product re-indexing..."
# These indexer commands may fail if Redis isn't up, that's OK
php /var/www/magento2/bin/magento indexer:set-mode schedule catalogrule_product 2>/dev/null || true
php /var/www/magento2/bin/magento indexer:set-mode schedule catalogrule_rule 2>/dev/null || true
php /var/www/magento2/bin/magento indexer:set-mode schedule catalogsearch_fulltext 2>/dev/null || true
php /var/www/magento2/bin/magento indexer:set-mode schedule catalog_category_product 2>/dev/null || true
php /var/www/magento2/bin/magento indexer:set-mode schedule customer_grid 2>/dev/null || true
php /var/www/magento2/bin/magento indexer:set-mode schedule design_config_grid 2>/dev/null || true
php /var/www/magento2/bin/magento indexer:set-mode schedule inventory 2>/dev/null || true
php /var/www/magento2/bin/magento indexer:set-mode schedule catalog_product_category 2>/dev/null || true
php /var/www/magento2/bin/magento indexer:set-mode schedule catalog_product_attribute 2>/dev/null || true
php /var/www/magento2/bin/magento indexer:set-mode schedule catalog_product_price 2>/dev/null || true
php /var/www/magento2/bin/magento indexer:set-mode schedule cataloginventory_stock 2>/dev/null || true

exec "$@"