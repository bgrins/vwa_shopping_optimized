#!/bin/bash

# Script to analyze Magento product images and cache usage
# Usage: ./analyze_product.sh "product-url-slug"
# Example: ./analyze_product.sh "spanish-cow-milk-cheese-mahon-1-pound"

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Configuration
CONTAINER_NAME="shopping"
DB_USER="magentouser"
DB_PASS="MyPassword"
DB_NAME="magentodb"
CACHE_PATH="$PROJECT_ROOT/shopping_extracted/magento2/pub/media/catalog/product/cache"
PRODUCT_PATH="$PROJECT_ROOT/shopping_extracted/magento2/pub/media/catalog/product"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if product URL slug is provided
if [ $# -eq 0 ]; then
    echo -e "${RED}Error: Please provide a product URL slug${NC}"
    echo "Usage: $0 \"product-url-slug\""
    echo "Example: $0 \"spanish-cow-milk-cheese-mahon-1-pound\""
    exit 1
fi

PRODUCT_SLUG="$1"
PRODUCT_URL="${PRODUCT_SLUG}.html"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Product Image Cache Analysis${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Step 1: Find product ID from URL rewrite
echo -e "${YELLOW}Step 1: Looking up product in database...${NC}"
PRODUCT_INFO=$(docker exec $CONTAINER_NAME mysql -u$DB_USER -p$DB_PASS $DB_NAME -e \
    "SELECT entity_id, target_path FROM url_rewrite WHERE request_path = '$PRODUCT_URL';" 2>/dev/null | tail -n 1)

if [ -z "$PRODUCT_INFO" ]; then
    echo -e "${RED}Product not found with URL: $PRODUCT_URL${NC}"
    exit 1
fi

PRODUCT_ID=$(echo "$PRODUCT_INFO" | awk '{print $1}')
echo -e "${GREEN}✓ Found product ID: $PRODUCT_ID${NC}"
echo -e "  URL: http://localhost:7770/$PRODUCT_URL"
echo ""

# Step 2: Find product images
echo -e "${YELLOW}Step 2: Finding product images...${NC}"
IMAGE_PATHS=$(docker exec $CONTAINER_NAME mysql -u$DB_USER -p$DB_PASS $DB_NAME -e \
    "SELECT DISTINCT g.value FROM catalog_product_entity_media_gallery g 
     JOIN catalog_product_entity_media_gallery_value v ON g.value_id = v.value_id 
     WHERE v.entity_id = $PRODUCT_ID;" 2>/dev/null | tail -n +2)

if [ -z "$IMAGE_PATHS" ]; then
    echo -e "${RED}No images found for product ID: $PRODUCT_ID${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Found images:${NC}"
echo "$IMAGE_PATHS" | while read -r image_path; do
    echo "  - $image_path"
done
echo ""

# Step 3: Analyze cache for each image
echo -e "${YELLOW}Step 3: Analyzing image cache...${NC}"
echo ""

TOTAL_CACHE_SIZE=0
TOTAL_CACHE_FILES=0

echo "$IMAGE_PATHS" | while read -r image_path; do
    # Remove leading slash and get filename
    IMAGE_FILE=$(basename "$image_path")
    IMAGE_DIR=$(dirname "$image_path" | sed 's/^\///')
    
    echo -e "${BLUE}Image: $IMAGE_FILE${NC}"
    
    # Check if original exists
    ORIGINAL_PATH="$PRODUCT_PATH/$IMAGE_DIR/$IMAGE_FILE"
    if [ -f "$ORIGINAL_PATH" ]; then
        ORIGINAL_SIZE=$(ls -lh "$ORIGINAL_PATH" | awk '{print $5}')
        ORIGINAL_DIMS=$(identify -format "%wx%h" "$ORIGINAL_PATH" 2>/dev/null || echo "unknown")
        echo -e "  ${GREEN}Original:${NC}"
        echo -e "    Path: $ORIGINAL_PATH"
        echo -e "    Size: $ORIGINAL_SIZE"
        echo -e "    Dimensions: $ORIGINAL_DIMS"
    else
        echo -e "  ${YELLOW}Original not found locally${NC}"
    fi
    
    # Find cached versions locally
    echo -e "  ${GREEN}Cached versions (local extract):${NC}"
    CACHE_FILES=$(find "$CACHE_PATH" -name "$IMAGE_FILE" -type f 2>/dev/null)
    
    if [ -z "$CACHE_FILES" ]; then
        echo -e "    ${YELLOW}No cached versions found locally${NC}"
    else
        CACHE_COUNT=$(echo "$CACHE_FILES" | wc -l | tr -d ' ')
        echo -e "    Found ${GREEN}$CACHE_COUNT${NC} cached versions:"
        
        # Create a temporary file to store cache info for sorting
        TEMP_FILE=$(mktemp)
        
        echo "$CACHE_FILES" | while read -r cache_file; do
            CACHE_DIR=$(basename $(dirname $(dirname "$cache_file")))
            CACHE_SIZE=$(ls -lh "$cache_file" | awk '{print $5}')
            CACHE_DIMS=$(identify -format "%wx%h" "$cache_file" 2>/dev/null || echo "unknown")
            CACHE_BYTES=$(stat -f %z "$cache_file" 2>/dev/null || stat -c %s "$cache_file" 2>/dev/null || echo 0)
            
            # Store info with size in bytes for sorting
            echo "$CACHE_BYTES|$CACHE_DIMS|$CACHE_SIZE|$CACHE_DIR" >> "$TEMP_FILE"
        done
        
        # Sort by dimensions (largest first) and display
        sort -t'|' -k1 -rn "$TEMP_FILE" | while IFS='|' read -r bytes dims size dir; do
            printf "    %-12s %-10s %s (cache: %s)\n" "$dims" "$size" "" "$dir"
        done
        
        # Calculate total size for this image
        IMAGE_CACHE_SIZE=$(echo "$CACHE_FILES" | xargs du -ch 2>/dev/null | tail -1 | awk '{print $1}')
        echo -e "    ${GREEN}Total cache size for this image: $IMAGE_CACHE_SIZE${NC}"
        
        rm -f "$TEMP_FILE"
        
        TOTAL_CACHE_FILES=$((TOTAL_CACHE_FILES + CACHE_COUNT))
    fi
    
    # Also check cache in the running container
    echo -e "  ${GREEN}Cached versions (in container):${NC}"
    CONTAINER_CACHE_COUNT=$(docker exec $CONTAINER_NAME find /var/www/magento2/pub/media/catalog/product/cache -name "$IMAGE_FILE" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$CONTAINER_CACHE_COUNT" -gt 0 ]; then
        echo -e "    Found ${GREEN}$CONTAINER_CACHE_COUNT${NC} cached versions in container"
        docker exec $CONTAINER_NAME find /var/www/magento2/pub/media/catalog/product/cache -name "$IMAGE_FILE" -exec ls -lh {} \; 2>/dev/null | head -5 | while read line; do
            echo "    $line"
        done
    else
        echo -e "    ${YELLOW}No cached versions found in container${NC}"
    fi
    
    echo ""
done

# Step 4: Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Product URL: ${GREEN}http://localhost:7770/$PRODUCT_URL${NC}"
echo -e "Product ID: ${GREEN}$PRODUCT_ID${NC}"
echo -e "Total cached files: ${GREEN}$TOTAL_CACHE_FILES${NC}"

# Calculate total cache size for all product images
ALL_CACHE_SIZE=$(echo "$IMAGE_PATHS" | while read -r image_path; do
    IMAGE_FILE=$(basename "$image_path")
    find "$CACHE_PATH" -name "$IMAGE_FILE" -type f 2>/dev/null
done | xargs du -ch 2>/dev/null | tail -1 | awk '{print $1}')

if [ ! -z "$ALL_CACHE_SIZE" ]; then
    echo -e "Total cache size: ${GREEN}$ALL_CACHE_SIZE${NC}"
fi

echo ""
echo -e "${YELLOW}Testing Instructions:${NC}"
echo "1. To test cache regeneration, rename a cached file:"
echo "   docker exec $CONTAINER_NAME mv /var/www/magento2/pub/media/catalog/product/cache/[hash]/[path] /var/www/magento2/pub/media/catalog/product/cache/[hash]/[path].bak"
echo ""
echo "2. Load the product page:"
echo "   http://localhost:7770/$PRODUCT_URL"
echo ""
echo "3. Check if cache regenerated:"
echo "   docker exec $CONTAINER_NAME ls -la /var/www/magento2/pub/media/catalog/product/cache/[hash]/[path]"