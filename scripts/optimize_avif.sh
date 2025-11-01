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
BASE_DIR="$PROJECT_ROOT/shopping_extracted_avif"
QUALITY=43

echo -e "${GREEN}=== VIPS AVIF Conversion ===${NC}"
echo "Directory: $BASE_DIR"
echo "Target quality: $QUALITY%"
echo "Output format: AVIF"
echo ""

# Check if vips is installed
if ! command -v vips &> /dev/null; then
    echo -e "${RED}vips is not installed!${NC}"
    exit 1
fi

# Check if vips supports AVIF
if ! vips -l | grep -q "heifsave"; then
    echo -e "${RED}vips doesn't support AVIF/HEIF!${NC}"
    echo "You may need to: brew reinstall vips --with-heif"
    exit 1
fi

# Count total images
TOTAL=$(find "$BASE_DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" \) | wc -l)
echo "Total images to convert: $TOTAL"

# Get initial size
INITIAL_SIZE=$(du -sh "$BASE_DIR" | cut -f1)
echo "Initial directory size: $INITIAL_SIZE"

echo -e "\n${YELLOW}WARNING: This will convert all JPEGs to AVIF format!${NC}"
echo "Working directory: $BASE_DIR"
echo "Note: Magento may need configuration changes to serve AVIF files"
echo "Press Ctrl+C to cancel, or Enter to continue..."
read -r

echo -e "\n${GREEN}Converting images to AVIF...${NC}"

# Process images
COUNT=0
FAILED=0
SKIPPED=0

find "$BASE_DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" \) | while read -r file; do
    COUNT=$((COUNT + 1))
    
    # Create AVIF file name (replace .jpg/.jpeg with .avif)
    AVIF_FILE="${file%.*}.avif"
    TEMP_FILE="${AVIF_FILE}.tmp"
    DONE_FILE="${AVIF_FILE}.done"
    
    # Skip if already processed
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
    
    # Convert to AVIF with vips (Q=quality, strip=remove metadata)
    # Using heifsave for AVIF format
    if vips heifsave "$file" "$TEMP_FILE" --Q=$QUALITY --compression=av1 --strip 2>/dev/null; then
        # Move to final location
        mv "$TEMP_FILE" "$AVIF_FILE"
        # Remove original JPEG
        rm "$file"
        # Mark as done
        touch "$DONE_FILE"
        
        # Get size after and show progress
        SIZE_AFTER=$(ls -lh "$AVIF_FILE" | awk '{print $5}')
        REL_PATH=${file#$BASE_DIR/}
        echo "  $REL_PATH: $SIZE_BEFORE -> $SIZE_AFTER (AVIF)"
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

echo -e "\n${GREEN}=== Conversion Complete ===${NC}"
echo "Converted: $((COUNT - FAILED - SKIPPED)) files successfully"
echo "Skipped: $SKIPPED files (already converted)"
[ $FAILED -gt 0 ] && echo -e "${RED}Failed: $FAILED files${NC}"

# Get final size
FINAL_SIZE=$(du -sh "$BASE_DIR" | cut -f1)
echo ""
echo "Initial size: $INITIAL_SIZE"
echo "Final size: $FINAL_SIZE"

# Show sample comparison
echo -e "\n${YELLOW}Sample conversions:${NC}"
for file in "$BASE_DIR"/B/0/B08CV3YPN7.1.avif "$BASE_DIR"/B/0/B07HSKLBM4.1.avif "$BASE_DIR"/B/0/B07CJSNLNZ.1.avif; do
    if [ -f "$file" ]; then
        NEW_SIZE=$(ls -lh "$file" | awk '{print $5}')
        echo "  $(basename "$file"): $NEW_SIZE"
    fi
done

echo -e "\n${GREEN}Done!${NC}"
echo ""
echo -e "${YELLOW}IMPORTANT: AVIF files created!${NC}"
echo "You'll need to update Magento to:"
echo "  1. Accept AVIF uploads"
echo "  2. Serve AVIF with correct MIME type (image/avif)"
echo "  3. Update database references from .jpg to .avif"
echo ""
echo "Cleanup options:"
echo "  Remove .done markers: find $BASE_DIR -name '*.done' -delete"
echo "  Restore JPEGs: Copy original files from shopping_extracted_backup"