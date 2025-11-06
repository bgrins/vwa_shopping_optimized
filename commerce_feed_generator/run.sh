#!/bin/bash

# Build and run the feed generator against a fresh upstream container

set -e  # Exit on error

UPSTREAM_IMAGE="ghcr.io/bgrins/vwa-shopping-optimized-bundled:latest"
CONTAINER_NAME="commerce-feed-temp-$(date +%s)"
NETWORK_NAME="commerce-feed-network"

cleanup() {
    echo ""
    echo "Cleaning up..."
    docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
    docker network rm "$NETWORK_NAME" 2>/dev/null || true
}

# Set trap to cleanup on exit
trap cleanup EXIT

echo "Commerce Feed Generator with Fresh Upstream Container"
echo "=" >&2

echo ""
echo "Building feed generator container..."
docker build -t commerce-feed-generator .

echo ""
echo "Creating network..."
docker network create "$NETWORK_NAME" 2>/dev/null || true

echo ""
echo "Starting fresh upstream container..."
docker run -d \
  --name "$CONTAINER_NAME" \
  --network "$NETWORK_NAME" \
  -e MYSQL_ROOT_PASSWORD=1234567890 \
  "$UPSTREAM_IMAGE"

echo "Waiting for database to be ready..."
for i in {1..60}; do
    if docker exec "$CONTAINER_NAME" mysql -u root -p1234567890 -e "SELECT 1" &>/dev/null; then
        echo "Database is ready!"
        break
    fi
    if [ $i -eq 60 ]; then
        echo "Error: Database failed to start within timeout"
        exit 1
    fi
    echo -n "."
    sleep 2
done

echo ""
echo "Configuring database access..."
docker exec "$CONTAINER_NAME" mysql -u root -p1234567890 -e "
GRANT ALL PRIVILEGES ON magentodb.* TO 'root'@'%' IDENTIFIED BY '1234567890';
FLUSH PRIVILEGES;
" || true

echo ""
echo "Running feed generator..."
echo ""

# Create output directory if it doesn't exist
mkdir -p output

# Run the container on the same network
docker run --rm \
  --network "$NETWORK_NAME" \
  -v $(pwd)/output:/output \
  -e DB_HOST="$CONTAINER_NAME" \
  -e DB_PASSWORD=1234567890 \
  -e BASE_URL=https://shop.example.com \
  commerce-feed-generator

if [ $? -eq 0 ]; then
    echo ""
    echo "=" >&2
    echo "Feed generation complete!"
    echo "Output saved to: ./output/"
    echo ""
    echo "Files generated:"
    ls -lh ./output/index.json 2>/dev/null || true
    ls -lh ./output/categories/*.json 2>/dev/null | head -5 || true
    if [ $(ls -1 ./output/categories/*.json 2>/dev/null | wc -l) -gt 5 ]; then
        echo "... and more category files"
    fi
else
    echo ""
    echo "Feed generation failed"
    exit 1
fi