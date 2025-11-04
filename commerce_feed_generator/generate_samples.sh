#!/bin/bash

echo "Generating sample feed files..."

# Generate 10 product sample
echo "Generating 10 product sample..."
docker run --rm \
  -v $(pwd)/output:/output \
  -e DB_HOST=host.docker.internal \
  -e DB_PASSWORD=1234567890 \
  -e BASE_URL=https://shop.example.com \
  -e LIMIT=10 \
  -e OUTPUT_FILE=commerce_feed_sample_10.json \
  commerce-feed-generator

# Generate 100 product sample
echo "Generating 100 product sample..."
docker run --rm \
  -v $(pwd)/output:/output \
  -e DB_HOST=host.docker.internal \
  -e DB_PASSWORD=1234567890 \
  -e BASE_URL=https://shop.example.com \
  -e LIMIT=100 \
  -e OUTPUT_FILE=commerce_feed_sample_100.json \
  commerce-feed-generator

echo "Sample files generated:"
echo "  - ./output/commerce_feed_sample_10.json"
echo "  - ./output/commerce_feed_sample_100.json"