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

# Export the database
echo "Exporting magentodb database..."
docker exec temp_extract mysqldump -u root -p1234567890 magentodb > mysql-baked/magento_dump.sql || {
    echo "Failed to export database. Trying alternative approach..."
    # Alternative: copy the MySQL data directory
    mkdir -p ../shopping_extracted/
    docker cp temp_extract:/var/lib/mysql ../shopping_extracted/mysql_data_backup
}

# Stop and remove temporary container
docker stop temp_extract
docker rm temp_extract

echo "MySQL dump extraction complete!"