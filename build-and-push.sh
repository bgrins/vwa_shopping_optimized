#!/bin/bash
set -e

# Parse arguments
PUSH_FLAG=""
CUSTOM_TAG=""
ACTION="Building"
RESULT="Built"

while [[ $# -gt 0 ]]; do
  case $1 in
    --push)
      PUSH_FLAG="--push"
      ACTION="Building and pushing"
      RESULT="Built and pushed"
      shift
      ;;
    --tag)
      CUSTOM_TAG="$2"
      shift 2
      ;;
    *)
      # If no --tag flag, treat as tag value
      if [[ -z "$CUSTOM_TAG" && ! "$1" == --* ]]; then
        CUSTOM_TAG="$1"
      fi
      shift
      ;;
  esac
done

# Default to --load if not pushing
if [[ -z "$PUSH_FLAG" ]]; then
  PUSH_FLAG="--load"
fi

echo "Building base image..."
BASE_TAGS="-t ghcr.io/bgrins/vwa-shopping-optimized-base:latest"
if [[ -n "$CUSTOM_TAG" ]]; then
  BASE_TAGS="$BASE_TAGS -t ghcr.io/bgrins/vwa-shopping-optimized-base:$CUSTOM_TAG"
fi
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  $BASE_TAGS \
  --load \
  shopping_base_image/

echo "$ACTION bundled variant (with MySQL)..."
BUNDLED_TAGS="-t ghcr.io/bgrins/vwa-shopping-optimized-bundled:latest"
if [[ -n "$CUSTOM_TAG" ]]; then
  BUNDLED_TAGS="$BUNDLED_TAGS -t ghcr.io/bgrins/vwa-shopping-optimized-bundled:$CUSTOM_TAG"
fi
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --target with-mysql \
  $BUNDLED_TAGS \
  $PUSH_FLAG \
  shopping_docker_rebuild/

echo "$ACTION standalone variant (external database)..."
STANDALONE_TAGS="-t ghcr.io/bgrins/vwa-shopping-optimized-standalone:latest"
if [[ -n "$CUSTOM_TAG" ]]; then
  STANDALONE_TAGS="$STANDALONE_TAGS -t ghcr.io/bgrins/vwa-shopping-optimized-standalone:$CUSTOM_TAG"
fi
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --target without-mysql \
  $STANDALONE_TAGS \
  $PUSH_FLAG \
  shopping_docker_rebuild/

echo "✓ $RESULT both variants"
echo ""
echo "Images available:"
if [[ -n "$CUSTOM_TAG" ]]; then
  echo "  - ghcr.io/bgrins/vwa-shopping-optimized-bundled:latest (with MySQL)"
  echo "  - ghcr.io/bgrins/vwa-shopping-optimized-bundled:$CUSTOM_TAG (with MySQL)"
  echo "  - ghcr.io/bgrins/vwa-shopping-optimized-standalone:latest (external DB)"
  echo "  - ghcr.io/bgrins/vwa-shopping-optimized-standalone:$CUSTOM_TAG (external DB)"
else
  echo "  - ghcr.io/bgrins/vwa-shopping-optimized-bundled:latest (with MySQL)"
  echo "  - ghcr.io/bgrins/vwa-shopping-optimized-standalone:latest (external DB)"
fi
if [[ -z "$PUSH_FLAG" || "$PUSH_FLAG" == "--load" ]]; then
  echo ""
  echo "To push to GHCR, run: ./build-and-push.sh --push"
  if [[ -n "$CUSTOM_TAG" ]]; then
    echo "To push with this tag: ./build-and-push.sh --push --tag $CUSTOM_TAG"
  fi
fi