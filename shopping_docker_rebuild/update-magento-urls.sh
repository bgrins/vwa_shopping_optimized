#!/bin/sh
# Script to update Magento URLs after services are running

BASE_URL=${BASE_URL:-http://localhost:7770}
MYSQL_HOST=${MYSQL_HOST:-localhost}
MYSQL_USER=${MYSQL_USER:-magentouser}
MYSQL_PASSWORD=${MYSQL_PASSWORD:-MyPassword}
MYSQL_DATABASE=${MYSQL_DATABASE:-magentodb}

# Wait for MySQL to be fully ready
echo "Waiting for MySQL to be ready for URL update..."
for i in $(seq 1 30); do
  if mysql -h$MYSQL_HOST -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SELECT 1" > /dev/null 2>&1; then
    echo "MySQL is ready!"
    break
  fi
  echo "Waiting for MySQL... ($i/30)"
  sleep 2
done

# Update database URLs
echo "Updating ALL database URLs to $BASE_URL/..."
if mysql -h$MYSQL_HOST -u$MYSQL_USER -p$MYSQL_PASSWORD $MYSQL_DATABASE -e "UPDATE core_config_data SET value='$BASE_URL/' WHERE path LIKE '%base_url%';"; then
  echo "Database URLs updated successfully"
  
  # Flush cache after successful update
  echo "Flushing Magento cache..."
  php81 /var/www/magento2/bin/magento cache:flush 2>/dev/null || echo "Cache flush failed (Redis might not be ready)"
else
  echo "ERROR: Failed to update database URLs!"
  exit 1
fi