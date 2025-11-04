#!/bin/sh
set -e

BASE_URL=${BASE_URL:-http://localhost:7770}
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-1234567890}
MYSQL_PASSWORD=${MYSQL_PASSWORD:-MyPassword}
MYSQL_USER=${MYSQL_USER:-magentouser}
MYSQL_DATABASE=${MYSQL_DATABASE:-magentodb}

DISABLE=",$DISABLE,"

for S in elasticsearch mailcatcher mysql redis; do
  DS=$(echo $DISABLE | grep -q ",$S," && echo "YES"  || echo "NO")
  if [ "$DS" = "YES" ]; then
    if [ -f "/etc/supervisor.d/$S.ini" ]; then mv "/etc/supervisor.d/$S.ini" "/etc/supervisor.d/$S"; fi
  else
    if [ -f "/etc/supervisor.d/$S" ]; then mv "/etc/supervisor.d/$S" "/etc/supervisor.d/$S.ini"; fi
  fi
done

DISABLE_MYSQL=$(echo $DISABLE | grep -q ",mysql," && echo "YES"  || echo "NO")

if [ ! -d "/var/tmp/nginx/client_body" ]; then
  mkdir -p /run/nginx /var/tmp/nginx/client_body
  chown nginx:nginx -R /run/nginx /var/tmp/nginx/
fi

if [ "$DISABLE_MYSQL" != "YES" ]; then
  if [ ! -f "/run/mysqld/.init" ]; then
    echo "Initializing MySQL database..."
    mkdir -p /run/mysqld /var/lib/mysql
    chown mysql:mysql -R /run/mysqld /var/lib/mysql
    
    if [ -d "/var/lib/mysql.template" ] && [ ! -f "/var/lib/mysql/.initialized" ]; then
      echo "Restoring pre-populated database..."
      cp -R /var/lib/mysql.template/* /var/lib/mysql/
      chown -R mysql:mysql /var/lib/mysql
      touch /var/lib/mysql/.initialized
    else
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

# Configure Magento directly (always run to ensure BASE_URL is correct)
echo "Configuring Magento base URL to $BASE_URL..."
# This may fail if Redis isn't up yet, that's OK
php81 /var/www/magento2/bin/magento setup:store-config:set --base-url="$BASE_URL" 2>/dev/null || true

if [ "$DISABLE_MYSQL" != "YES" ]; then
  # Launch background script to update URLs after MySQL is ready
  echo "Scheduling database URL update..."
  nohup /usr/local/bin/update-magento-urls.sh > /var/log/update-urls.log 2>&1 &
fi

# Cache flush may fail if Redis isn't up yet
php81 /var/www/magento2/bin/magento cache:flush 2>/dev/null || true

echo "Disabling product re-indexing..."
# These indexer commands may fail if Redis isn't up, that's OK
php81 /var/www/magento2/bin/magento indexer:set-mode schedule catalogrule_product 2>/dev/null || true
php81 /var/www/magento2/bin/magento indexer:set-mode schedule catalogrule_rule 2>/dev/null || true
php81 /var/www/magento2/bin/magento indexer:set-mode schedule catalogsearch_fulltext 2>/dev/null || true
php81 /var/www/magento2/bin/magento indexer:set-mode schedule catalog_category_product 2>/dev/null || true
php81 /var/www/magento2/bin/magento indexer:set-mode schedule customer_grid 2>/dev/null || true
php81 /var/www/magento2/bin/magento indexer:set-mode schedule design_config_grid 2>/dev/null || true
php81 /var/www/magento2/bin/magento indexer:set-mode schedule inventory 2>/dev/null || true
php81 /var/www/magento2/bin/magento indexer:set-mode schedule catalog_product_category 2>/dev/null || true
php81 /var/www/magento2/bin/magento indexer:set-mode schedule catalog_product_attribute 2>/dev/null || true
php81 /var/www/magento2/bin/magento indexer:set-mode schedule catalog_product_price 2>/dev/null || true
php81 /var/www/magento2/bin/magento indexer:set-mode schedule cataloginventory_stock 2>/dev/null || true

exec "$@"