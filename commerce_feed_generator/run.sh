#!/bin/bash

# Build and run the feed generator

echo "Building feed generator container..."
docker build -t commerce-feed-generator .

if [ $? -ne 0 ]; then
    echo "Failed to build container"
    exit 1
fi

echo ""
echo "Running feed generator..."
echo ""

# Create output directory if it doesn't exist
mkdir -p output

echo "Setting up MySQL access for Docker containers..."
docker exec vwa-shopping-optimized-shopping-1 mysql -u root -p1234567890 -e "
GRANT ALL PRIVILEGES ON magentodb.* TO 'root'@'%' IDENTIFIED BY '1234567890';
GRANT ALL PRIVILEGES ON magentodb.* TO 'root'@'192.168.%' IDENTIFIED BY '1234567890';
GRANT ALL PRIVILEGES ON magentodb.* TO 'root'@'172.%' IDENTIFIED BY '1234567890';
FLUSH PRIVILEGES;
"

# Run the container connecting to exposed MySQL port
# On macOS, use host.docker.internal to connect to host services
docker run --rm \
  -v $(pwd)/output:/output \
  -e DB_HOST=host.docker.internal \
  -e DB_PASSWORD=1234567890 \
  -e BASE_URL=https://shop.example.com \
  commerce-feed-generator

if [ $? -eq 0 ]; then
    echo ""
    echo "Feed generation complete!"
    echo "Output saved to: ./output/commerce_feed.json"
    
    # Show a sample of the output if it exists
    if [ -f "./output/commerce_feed.json" ]; then
        echo ""
        echo "First product in feed:"
        head -20 ./output/commerce_feed.json
    fi
else
    echo ""
    echo "Feed generation failed"
    exit 1
fi