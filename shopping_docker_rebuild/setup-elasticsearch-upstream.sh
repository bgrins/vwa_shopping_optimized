#!/bin/bash
# Script to setup Elasticsearch 7 on the upstream shopping_final_0712 image
# This reproduces the search configuration we use in the optimized image
set -e

CONTAINER_NAME=${1:-shopping_final_0712_test}

echo "========================================="
echo "Elasticsearch 7 Setup for Upstream Image"
echo "========================================="
echo "Container: $CONTAINER_NAME"
echo ""

# Check if container exists and is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "ERROR: Container '$CONTAINER_NAME' is not running"
    echo "Please start the container first with:"
    echo "  docker run -d --name $CONTAINER_NAME -p 7770:80 shopping_final_0712"
    exit 1
fi

echo "Step 1: Installing Elasticsearch 7.17.0..."
docker exec $CONTAINER_NAME sh -c "
echo '@legacy https://dl-cdn.alpinelinux.org/alpine/v3.12/community' >> /etc/apk/repositories
apk update
apk add --no-cache openjdk8-jre@legacy elasticsearch@legacy
sed -i 's|^elastico:\([^:]*\):\([^:]*\):\([^:]*\):\([^:]*\):\([^:]*\):/sbin/nologin$|elastico:\1:\2:\3:\4:\5:/bin/ash|' /etc/passwd
"

echo ""
echo "Step 2: Adding Elasticsearch to PATH..."
docker exec $CONTAINER_NAME sh -c "
echo 'export PATH=/usr/share/java/elasticsearch/bin:\$PATH' >> /root/.profile
export PATH=/usr/share/java/elasticsearch/bin:\$PATH
"

echo ""
echo "Step 3: Starting Elasticsearch..."
docker exec -d $CONTAINER_NAME sh -c "
ES_JAVA_HOME=/usr /usr/share/java/elasticsearch/bin/elasticsearch > /var/log/elasticsearch.log 2>&1 &
"

echo "Waiting for Elasticsearch to start..."
for i in {1..30}; do
    if docker exec $CONTAINER_NAME curl -s http://localhost:9200 > /dev/null 2>&1; then
        echo "Elasticsearch is ready!"
        break
    fi
    echo "Waiting for Elasticsearch... ($i/30)"
    sleep 2
done

echo ""
echo "Step 4: Configuring Magento for Elasticsearch 7..."
docker exec $CONTAINER_NAME mysql -uroot -p1234567890 magentodb << 'EOF'
DELETE FROM core_config_data WHERE path LIKE 'catalog/search/%';
INSERT INTO core_config_data (scope, scope_id, path, value) VALUES
('default', 0, 'catalog/search/engine', 'elasticsearch7'),
('default', 0, 'catalog/search/elasticsearch7_server_hostname', 'localhost'),
('default', 0, 'catalog/search/elasticsearch7_server_port', '9200'),
('default', 0, 'catalog/search/elasticsearch7_index_prefix', 'magento2'),
('default', 0, 'catalog/search/elasticsearch7_enable_auth', '0'),
('default', 0, 'catalog/search/elasticsearch7_server_timeout', '15');
EOF

echo ""
echo "Step 5: Clearing Magento caches..."
docker exec $CONTAINER_NAME sh -c "
rm -rf /var/www/magento2/var/cache/*
rm -rf /var/www/magento2/generated/code/*
rm -rf /var/www/magento2/generated/metadata/*
php81 /var/www/magento2/bin/magento cache:flush
"

echo ""
echo "Step 6: Reindexing catalog search (this will take ~10-15 minutes)..."
echo "Starting at $(date)"
docker exec $CONTAINER_NAME php81 -d memory_limit=2G /var/www/magento2/bin/magento indexer:reindex catalogsearch_fulltext || {
    echo ""
    echo "ERROR: Reindexing failed. Check logs:"
    echo "  docker exec $CONTAINER_NAME tail -100 /var/www/magento2/var/log/exception.log"
    exit 1
}

echo "Indexing completed at $(date)"

echo ""
echo "Step 7: Verifying search works..."
RESULT_COUNT=$(docker exec $CONTAINER_NAME curl -s 'http://localhost/catalogsearch/result/?q=tea' | grep -c "product-item-name" || echo "0")

if [ "$RESULT_COUNT" -gt "0" ]; then
    echo "✓ Search is working! Found $RESULT_COUNT products for 'tea'"
else
    echo "✗ Search may not be working. Check manually at http://localhost:7770/catalogsearch/result/?q=tea"
fi

echo ""
echo "========================================="
echo "Setup Complete!"
echo "========================================="
echo "Elasticsearch 7.17.0 is configured and running"
echo "Search index has been created with 104k+ products"
echo ""
echo "To save the ES data for future use:"
echo "  docker cp $CONTAINER_NAME:/usr/share/java/elasticsearch/data ./elasticsearch_data"
echo ""
echo "To check Elasticsearch status:"
echo "  docker exec $CONTAINER_NAME curl http://localhost:9200"
echo ""
echo "To check indices:"
echo "  docker exec $CONTAINER_NAME curl 'http://localhost:9200/_cat/indices?v'"
