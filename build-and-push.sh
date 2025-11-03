#!/bin/bash
set -e

# Check for --push flag
PUSH_FLAG=""
if [[ "$1" == "--push" ]]; then
  PUSH_FLAG="--push"
  ACTION="Building and pushing"
  RESULT="Built and pushed"
else
  PUSH_FLAG="--load"
  ACTION="Building"
  RESULT="Built"
fi

echo "Building base image..."
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t bgrins/vwa-shopping-optimized-base:latest \
  --load \
  shopping_base_image/

echo "$ACTION bundled variant (with MySQL)..."
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --target with-mysql \
  -t ghcr.io/bgrins/vwa-shopping-optimized-bundled:latest \
  $PUSH_FLAG \
  shopping_docker_rebuild/

echo "$ACTION standalone variant (external database)..."
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --target without-mysql \
  -t ghcr.io/bgrins/vwa-shopping-optimized-standalone:latest \
  $PUSH_FLAG \
  shopping_docker_rebuild/

echo "✓ $RESULT both variants"
echo ""
echo "Images available:"
echo "  - ghcr.io/bgrins/vwa-shopping-optimized-bundled:latest (with MySQL)"
echo "  - ghcr.io/bgrins/vwa-shopping-optimized-standalone:latest (external DB)"
if [[ "$1" != "--push" ]]; then
  echo ""
  echo "To push to GHCR, run: ./build-and-push.sh --push"
fi