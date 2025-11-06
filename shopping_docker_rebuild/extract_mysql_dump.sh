#!/bin/bash
# Extract MySQL dump from the shopping_final_0712 image

set -e

echo "Starting MySQL dump extraction process..."

# Create temporary container from the image
docker create --name temp_extract shopping_final_0712 || { echo "Failed to create container. Make sure shopping_final_0712 image exists."; exit 1; }

# Start MySQL in the container
docker start temp_extract
echo "Waiting for MySQL to start..."
sleep 20  # Give MySQL more time to start

docker exec temp_extract php81 /var/www/magento2/bin/magento cache:flush

# Export the database
echo "Exporting magentodb database..."
docker exec temp_extract mysqldump -u root -p1234567890 magentodb > magento_dump.sql
xz -k magento_dump.sql
gzip magento_dump.sql

# Stop and remove temporary container
docker stop temp_extract
docker rm temp_extract

echo "MySQL dump extraction complete!"
