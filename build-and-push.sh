#!/bin/bash
set -e

echo "Building base image..."
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t bgrins/vwa-shopping-optimized-base:latest \
  --load \
  shopping_base_image/

echo "Building and pushing bundled variant (with MySQL)..."
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --target with-mysql \
  -t ghcr.io/bgrins/vwa-shopping-optimized-bundled:latest \
  --push \
  shopping_docker_rebuild/

echo "Building and pushing standalone variant (external database)..."
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --target without-mysql \
  -t ghcr.io/bgrins/vwa-shopping-optimized-standalone:latest \
  --push \
  shopping_docker_rebuild/

echo "✓ Built and pushed both variants to GHCR"
echo ""
echo "Images available:"
echo "  - ghcr.io/bgrins/vwa-shopping-optimized-bundled:latest (with MySQL)"
echo "  - ghcr.io/bgrins/vwa-shopping-optimized-standalone:latest (external DB)"