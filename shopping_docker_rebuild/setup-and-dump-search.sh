#!/bin/bash
# Script to configure search, reindex, and create a new database dump
# Run this after container restart to set up search properly

set -e

CONTAINER_NAME=${1:-vwa-shopping-optimized-shopping-1}
DUMP_OUTPUT_DIR=${2:-./}

echo "========================================="
echo "Magento Search Setup and Database Dump"
echo "========================================="
echo "Container: $CONTAINER_NAME"
echo "Output dir: $DUMP_OUTPUT_DIR"
echo ""

# Step 1: Configure search engine to MySQL
echo "Step 1: Configuring search engine to use MySQL..."
docker exec $CONTAINER_NAME sh -c "
php81 -d memory_limit=1G /var/www/magento2/bin/magento config:set catalog/search/engine mysql
php81 -d memory_limit=1G /var/www/magento2/bin/magento config:set catalog/search/min_query_length 3
php81 -d memory_limit=1G /var/www/magento2/bin/magento config:set catalog/search/max_query_length 128
"

# Step 2: Clear caches and generated code
echo ""
echo "Step 2: Clearing caches and generated code..."
docker exec $CONTAINER_NAME sh -c "
rm -rf /var/www/magento2/generated/code/*
rm -rf /var/www/magento2/generated/metadata/*
rm -rf /var/www/magento2/var/cache/*
rm -rf /var/www/magento2/var/page_cache/*
php81 -d memory_limit=1G /var/www/magento2/bin/magento cache:clean
php81 -d memory_limit=1G /var/www/magento2/bin/magento cache:flush
"

# Step 3: Reindex catalog search
echo ""
echo "Step 3: Reindexing catalog search (this will take several minutes)..."
echo "Starting at $(date)"
docker exec $CONTAINER_NAME sh -c "
php81 -d memory_limit=2G -d max_execution_time=0 /var/www/magento2/bin/magento indexer:reindex catalogsearch_fulltext
"
echo "Indexing completed at $(date)"

# Step 4: Verify search tables were created
echo ""
echo "Step 4: Verifying search tables..."
docker exec $CONTAINER_NAME mysql -hlocalhost -umagentouser -pMyPassword magentodb -e "
SELECT table_name, table_rows 
FROM information_schema.tables 
WHERE table_schema = 'magentodb' 
AND table_name LIKE 'catalogsearch_fulltext%';"

# Step 5: Test search functionality
echo ""
echo "Step 5: Testing search (searching for 'shirt')..."
docker exec $CONTAINER_NAME mysql -hlocalhost -umagentouser -pMyPassword magentodb -e "
SELECT COUNT(*) as matching_products 
FROM catalogsearch_fulltext_scope1 
WHERE data_index LIKE '%shirt%' 
LIMIT 5;"

# Step 6: Update URLs to localhost (optional)
echo ""
echo "Step 6: Updating base URLs to localhost..."
docker exec $CONTAINER_NAME mysql -hlocalhost -umagentouser -pMyPassword magentodb -e "
UPDATE core_config_data 
SET value='http://localhost:7771/' 
WHERE path LIKE '%base_url%';"

# Step 7: Create database dump
echo ""
echo "Step 7: Creating database dump..."
mkdir -p $DUMP_OUTPUT_DIR

# Create the dump
echo "Dumping database (this will take a while)..."
docker exec $CONTAINER_NAME mysqldump -uroot -p1234567890 \
  --single-transaction \
  --quick \
  --lock-tables=false \
  magentodb > $DUMP_OUTPUT_DIR/magento_dump_with_search.sql

# Get original size
ORIGINAL_SIZE=$(ls -lh $DUMP_OUTPUT_DIR/magento_dump_with_search.sql | awk '{print $5}')
echo "Original dump size: $ORIGINAL_SIZE"

# Compress with xz
echo "Compressing with xz (high compression)..."
xz -9 -k -f $DUMP_OUTPUT_DIR/magento_dump_with_search.sql
XZ_SIZE=$(ls -lh $DUMP_OUTPUT_DIR/magento_dump_with_search.sql.xz | awk '{print $5}')
echo "XZ compressed size: $XZ_SIZE"

# Also create gzip version for compatibility
echo "Compressing with gzip..."
gzip -9 -k -f $DUMP_OUTPUT_DIR/magento_dump_with_search.sql
GZ_SIZE=$(ls -lh $DUMP_OUTPUT_DIR/magento_dump_with_search.sql.gz | awk '{print $5}')
echo "Gzip compressed size: $GZ_SIZE"

echo ""
echo "========================================="
echo "Setup Complete!"
echo "========================================="
echo "Search engine: MySQL"
echo "Database dumps created in: $DUMP_OUTPUT_DIR"
echo "  - magento_dump_with_search.sql ($ORIGINAL_SIZE)"
echo "  - magento_dump_with_search.sql.xz ($XZ_SIZE)"
echo "  - magento_dump_with_search.sql.gz ($GZ_SIZE)"
echo ""
echo "You can now rebuild the Docker image with the new dump"
echo "that includes the search index tables."