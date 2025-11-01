#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Base directory (absolute path based on project root)
BASE_DIR="$PROJECT_ROOT/shopping_extracted/magento2/pub/media/catalog/product"

# Test images - including the largest ones
TEST_IMAGES=(
    "$BASE_DIR/B/0/B00A0A3TJO.0.jpg"      # Original test image
    "$BASE_DIR/B/0/B08CV3YPN7.1.jpg"      # 594K, 1280x720
    "$BASE_DIR/B/0/B07HSKLBM4.1.jpg"      # 589K, 1920x1080
    "$BASE_DIR/B/0/B07CJSNLNZ.1.jpg"      # 589K, 1920x1080
)

# Function to test optimization on a single image
test_single_image() {
    echo -e "${GREEN}=== Testing optimization levels on multiple images ===${NC}"
    
    TOTAL_ORIG_SIZE=0
    declare -A TOTAL_SIZES
    
    # Quality levels to test
    QUALITY_LEVELS=(30 40 50 60 70 80 90 100)
    
    for TEST_IMAGE in "${TEST_IMAGES[@]}"; do
        if [ ! -f "$TEST_IMAGE" ]; then
            echo -e "${RED}Test image not found: $TEST_IMAGE${NC}"
            continue
        fi
        
        IMAGE_NAME=$(basename "$TEST_IMAGE")
        echo -e "\n${YELLOW}Testing: $IMAGE_NAME${NC}"
        
        # Get original size
        ORIG_SIZE_BYTES=$(stat -f%z "$TEST_IMAGE" 2>/dev/null || stat -c%s "$TEST_IMAGE" 2>/dev/null)
        ORIG_SIZE=$(ls -lh "$TEST_IMAGE" | awk '{print $5}')
        ORIG_DIMENSIONS=$(identify -format "%wx%h" "$TEST_IMAGE" 2>/dev/null || echo "unknown")
        echo "Original: Size=$ORIG_SIZE, Dimensions=$ORIG_DIMENSIONS"
        TOTAL_ORIG_SIZE=$((TOTAL_ORIG_SIZE + ORIG_SIZE_BYTES))
        
        # Test each quality level
        for QUALITY in "${QUALITY_LEVELS[@]}"; do
            # Create temp file for testing
            TEMP_FILE="/tmp/${IMAGE_NAME%.jpg}_${QUALITY}.jpg"
            
            # Optimize using vips at this quality level
            vips jpegsave "$TEST_IMAGE" "$TEMP_FILE" --Q $QUALITY --strip > /dev/null 2>&1
            
            # Get size after optimization
            SIZE_BYTES=$(stat -f%z "$TEMP_FILE" 2>/dev/null || stat -c%s "$TEMP_FILE" 2>/dev/null)
            SIZE_DISPLAY=$(ls -lh "$TEMP_FILE" | awk '{print $5}')
            
            # Calculate savings
            if [ $ORIG_SIZE_BYTES -gt 0 ]; then
                SAVINGS=$(( (ORIG_SIZE_BYTES - SIZE_BYTES) * 100 / ORIG_SIZE_BYTES ))
            else
                SAVINGS=0
            fi
            
            # Display result
            if [ $QUALITY -eq 85 ]; then
                echo "  ${QUALITY}% quality: $SIZE_DISPLAY (saves ${SAVINGS}%) - recommended"
            else
                echo "  ${QUALITY}% quality: $SIZE_DISPLAY (saves ${SAVINGS}%)"
            fi
            
            # Add to total
            TOTAL_SIZES[$QUALITY]=$((${TOTAL_SIZES[$QUALITY]:-0} + SIZE_BYTES))
        done
    done
    
    echo -e "\n${GREEN}=== TOTAL SAVINGS SUMMARY ===${NC}"
    echo "Original total: $(echo "scale=2; $TOTAL_ORIG_SIZE/1024/1024" | bc) MB"
    
    for QUALITY in "${QUALITY_LEVELS[@]}"; do
        TOTAL_SIZE=${TOTAL_SIZES[$QUALITY]:-0}
        if [ $TOTAL_SIZE -gt 0 ]; then
            TOTAL_MB=$(echo "scale=2; $TOTAL_SIZE/1024/1024" | bc)
            if [ $TOTAL_ORIG_SIZE -gt 0 ]; then
                TOTAL_SAVINGS=$(( (TOTAL_ORIG_SIZE - TOTAL_SIZE) * 100 / TOTAL_ORIG_SIZE ))
            else
                TOTAL_SAVINGS=0
            fi
            
            if [ $QUALITY -eq 85 ]; then
                echo "After ${QUALITY}% quality: ${TOTAL_MB} MB (saves ${TOTAL_SAVINGS}%) - recommended"
            else
                echo "After ${QUALITY}% quality: ${TOTAL_MB} MB (saves ${TOTAL_SAVINGS}%)"
            fi
        fi
    done
    
    echo -e "\n${YELLOW}Test files saved to /tmp/*_*.jpg for visual comparison${NC}"
    echo "Compare largest image variants with:"
    echo "  open /tmp/B07HSKLBM4.1_*.jpg"
    echo "  open /tmp/B08CV3YPN7.1_*.jpg"
    
    # Clean up
    echo -e "\nCleanup test files? (y/n)"
    read -r CLEANUP
    if [ "$CLEANUP" = "y" ]; then
        for QUALITY in "${QUALITY_LEVELS[@]}"; do
            rm -f /tmp/*_${QUALITY}.jpg
        done
        echo "Test files removed."
    fi
}

# Function to optimize all images
optimize_all_images() {
    QUALITY=${1:-85}
    DRY_RUN=${2:-true}
    
    echo -e "${GREEN}=== Optimizing all product images ===${NC}"
    echo "Quality level: $QUALITY%"
    echo "Dry run: $DRY_RUN"
    echo "Excluding: cache directory"
    
    # Count total images
    TOTAL=$(find "$BASE_DIR" -name "*.jpg" -o -name "*.jpeg" | grep -v "/cache/" | wc -l)
    echo "Total images to process: $TOTAL"
    
    if [ "$DRY_RUN" = "true" ]; then
        echo -e "\n${YELLOW}DRY RUN MODE - No files will be modified${NC}"
        echo "Showing what would be processed (first 20 files):"
        find "$BASE_DIR" -name "*.jpg" -o -name "*.jpeg" | grep -v "/cache/" | head -20 | while read -r file; do
            SIZE=$(ls -lh "$file" | awk '{print $5}')
            echo "  Would optimize: $file (current: $SIZE)"
        done
        echo -e "\n${YELLOW}To actually optimize, run: $0 optimize false${NC}"
    else
        echo -e "\n${RED}WARNING: This will modify all images in place!${NC}"
        echo "Press Ctrl+C to cancel, or Enter to continue..."
        read -r
        
        # Create backup directory
        BACKUP_DIR="image_backup_$(date +%Y%m%d_%H%M%S)"
        echo "Creating backup in $BACKUP_DIR..."
        mkdir -p "$BACKUP_DIR"
        
        # Process images
        COUNT=0
        find "$BASE_DIR" -name "*.jpg" -o -name "*.jpeg" | grep -v "/cache/" | while read -r file; do
            COUNT=$((COUNT + 1))
            
            # Backup original
            REL_PATH=${file#$BASE_DIR/}
            BACKUP_FILE="$BACKUP_DIR/$REL_PATH"
            mkdir -p "$(dirname "$BACKUP_FILE")"
            cp "$file" "$BACKUP_FILE"
            
            # Optimize
            jpegoptim -m$QUALITY --strip-all "$file" > /dev/null 2>&1
            
            # Show progress every 100 files
            if [ $((COUNT % 100)) -eq 0 ]; then
                echo "Processed $COUNT/$TOTAL files..."
            fi
        done
        
        echo -e "\n${GREEN}Optimization complete!${NC}"
        echo "Backup saved to: $BACKUP_DIR"
        
        # Show size comparison
        ORIG_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
        NEW_SIZE=$(du -sh "$BASE_DIR" | cut -f1)
        echo "Original total size: $ORIG_SIZE"
        echo "New total size: $NEW_SIZE"
    fi
}

# Main script logic
case "$1" in
    test)
        test_single_image
        ;;
    optimize)
        QUALITY=${3:-85}
        optimize_all_images $QUALITY $2
        ;;
    *)
        echo "Usage: $0 {test|optimize} [false|true] [quality]"
        echo ""
        echo "Commands:"
        echo "  $0 test                    - Test optimization on single image"
        echo "  $0 optimize                - Dry run to see what would be optimized"
        echo "  $0 optimize false          - Actually optimize all images (85% quality)"
        echo "  $0 optimize false 80       - Actually optimize all images (80% quality)"
        echo ""
        echo "Examples:"
        echo "  $0 test                    - Test different quality levels on sample image"
        echo "  $0 optimize                - Preview what would be optimized (dry run)"
        echo "  $0 optimize false 85       - Optimize all images at 85% quality"
        ;;
esac