#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Base directory (absolute path based on project root)
BASE_DIR="$PROJECT_ROOT/shopping_extracted_jpg50"
QUALITY=50

echo -e "${GREEN}=== VIPS Image Optimization ===${NC}"
echo "Directory: $BASE_DIR"
echo "Target quality: $QUALITY%"
echo ""

# Check if vips is installed
if ! command -v vips &> /dev/null; then
    echo -e "${RED}vips is not installed!${NC}"
    exit 1
fi

# Count total images
TOTAL=$(find "$BASE_DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" \) | wc -l)
echo "Total images to process: $TOTAL"

# Get initial size
INITIAL_SIZE=$(du -sh "$BASE_DIR" | cut -f1)
echo "Initial directory size: $INITIAL_SIZE"

echo -e "\n${YELLOW}WARNING: This will modify all images in place!${NC}"
echo "Backup exists at: shopping_extracted_backup"
echo "Press Ctrl+C to cancel, or Enter to continue..."
read -r

echo -e "\n${GREEN}Processing images...${NC}"

# Process images
COUNT=0
FAILED=0
SKIPPED=0

find "$BASE_DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" \) | while read -r file; do
    COUNT=$((COUNT + 1))
    
    # Create temp file name
    TEMP_FILE="${file}.tmp"
    DONE_FILE="${file}.done"
    
    # Skip if already processed (either .done marker exists or .tmp exists from interrupted run)
    if [ -f "$DONE_FILE" ]; then
        SKIPPED=$((SKIPPED + 1))
        if [ $((SKIPPED % 100)) -eq 0 ]; then
            echo "Skipped $SKIPPED already-processed files..."
        fi
        continue
    fi
    
    if [ -f "$TEMP_FILE" ]; then
        # .tmp exists - previous run was interrupted, remove and reprocess
        rm -f "$TEMP_FILE"
        echo "  Reprocessing interrupted: $(basename "$file")"
    fi
    
    # Get size before
    SIZE_BEFORE=$(ls -lh "$file" | awk '{print $5}')
    
    # Recompress with vips (Q=quality, strip=remove metadata)
    if vips jpegsave "$file" "$TEMP_FILE" --Q=$QUALITY --strip 2>/dev/null; then
        # Replace original with optimized version
        mv "$TEMP_FILE" "$file"
        # Mark as done
        touch "$DONE_FILE"
        
        # Get size after and show progress
        SIZE_AFTER=$(ls -lh "$file" | awk '{print $5}')
        REL_PATH=${file#$BASE_DIR/}
        echo "  $REL_PATH: $SIZE_BEFORE -> $SIZE_AFTER"
    else
        echo -e "${RED}Failed: $file${NC}"
        rm -f "$TEMP_FILE"
        FAILED=$((FAILED + 1))
    fi
    
    # Show progress every 100 files
    PROCESSED=$((COUNT - SKIPPED))
    if [ $((PROCESSED % 100)) -eq 0 ] && [ $PROCESSED -gt 0 ]; then
        echo "Processed $PROCESSED/$TOTAL files (skipped $SKIPPED)..."
    fi
done

echo -e "\n${GREEN}=== Optimization Complete ===${NC}"
echo "Processed: $((COUNT - FAILED)) files successfully"
[ $FAILED -gt 0 ] && echo -e "${RED}Failed: $FAILED files${NC}"

# Get final size
FINAL_SIZE=$(du -sh "$BASE_DIR" | cut -f1)
echo ""
echo "Initial size: $INITIAL_SIZE"
echo "Final size: $FINAL_SIZE"

# Show sample comparison
echo -e "\n${YELLOW}Sample size changes:${NC}"
for file in "$BASE_DIR"/B/0/B08CV3YPN7.1.jpg "$BASE_DIR"/B/0/B07HSKLBM4.1.jpg "$BASE_DIR"/B/0/B07CJSNLNZ.1.jpg; do
    if [ -f "$file" ]; then
        NEW_SIZE=$(ls -lh "$file" | awk '{print $5}')
        echo "  $(basename "$file"): $NEW_SIZE"
    fi
done

echo -e "\n${GREEN}Done!${NC}"
echo ""
echo "Cleanup options:"
echo "  Remove .done markers: find $BASE_DIR -name '*.done' -delete"
echo "  Restore from backup: rm -rf $BASE_DIR && cp -r shopping_extracted_backup $BASE_DIR"