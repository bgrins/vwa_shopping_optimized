#!/bin/bash

# Configurable JPEG optimization script using VIPS
# Usage: ./optimize_jpeg_quality.sh [quality] [source_dir]
# Examples:
#   ./optimize_jpeg_quality.sh 30              # Q=30 from shopping_extracted_backup
#   ./optimize_jpeg_quality.sh 50              # Q=50 from shopping_extracted_backup
#   ./optimize_jpeg_quality.sh 70 custom_dir   # Q=70 from custom_dir

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Parse arguments
QUALITY=${1:-50}
SOURCE_DIR=${2:-"shopping_extracted_backup"}

# Validate quality parameter
if ! [[ "$QUALITY" =~ ^[0-9]+$ ]] || [ "$QUALITY" -lt 1 ] || [ "$QUALITY" -gt 100 ]; then
    echo -e "${RED}Error: Quality must be a number between 1 and 100${NC}"
    echo "Usage: $0 [quality] [source_dir]"
    exit 1
fi

# Set up directories
if [[ "$SOURCE_DIR" = /* ]]; then
    # Absolute path provided
    SOURCE_PATH="$SOURCE_DIR"
else
    # Relative to project root
    SOURCE_PATH="$PROJECT_ROOT/$SOURCE_DIR"
fi

# Output directory based on quality
OUTPUT_DIR="shopping_extracted_jpg${QUALITY}"
OUTPUT_PATH="$PROJECT_ROOT/$OUTPUT_DIR"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}VIPS JPEG Optimization${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}Configuration:${NC}"
echo "  Quality: $QUALITY%"
echo "  Source: $SOURCE_PATH"
echo "  Output: $OUTPUT_PATH"
echo ""

# Check if vips is installed
if ! command -v vips &> /dev/null; then
    echo -e "${RED}vips is not installed!${NC}"
    echo "Install with: brew install vips"
    exit 1
fi

# Check source directory
if [ ! -d "$SOURCE_PATH" ]; then
    echo -e "${RED}Source directory not found: $SOURCE_PATH${NC}"
    exit 1
fi

# Count total images
echo "Counting images..."
TOTAL=$(find "$SOURCE_PATH" -type f \( -name "*.jpg" -o -name "*.jpeg" \) | wc -l | tr -d ' ')
echo "Total images to process: $TOTAL"

# Get source size
SOURCE_SIZE=$(du -sh "$SOURCE_PATH" | cut -f1)
echo "Source directory size: $SOURCE_SIZE"

# Check if output directory exists
if [ -d "$OUTPUT_PATH" ]; then
    echo -e "\n${YELLOW}Output directory already exists: $OUTPUT_PATH${NC}"
    echo "Choose an option:"
    echo "  1) Resume (skip already processed files)"
    echo "  2) Restart (delete and start fresh)"
    echo "  3) Cancel"
    read -r -p "Enter choice (1-3): " choice
    
    case $choice in
        1)
            echo "Resuming optimization..."
            RESUME=true
            ;;
        2)
            echo "Removing existing output directory..."
            rm -rf "$OUTPUT_PATH"
            RESUME=false
            ;;
        *)
            echo "Cancelled."
            exit 0
            ;;
    esac
else
    RESUME=false
fi

echo -e "\n${YELLOW}Ready to optimize $TOTAL images at Q=$QUALITY${NC}"
echo "Press Ctrl+C to cancel, or Enter to continue..."
read -r

echo -e "\n${GREEN}Processing images...${NC}"

# Process images
COUNT=0
FAILED=0
SKIPPED=0
PROCESSED=0

find "$SOURCE_PATH" -type f \( -name "*.jpg" -o -name "*.jpeg" \) | while read -r file; do
    COUNT=$((COUNT + 1))
    
    # Get relative path from source
    REL_PATH=${file#$SOURCE_PATH/}
    OUTPUT_FILE="$OUTPUT_PATH/$REL_PATH"
    OUTPUT_DIR_FOR_FILE=$(dirname "$OUTPUT_FILE")
    DONE_FILE="${OUTPUT_FILE}.done"
    TEMP_FILE="${OUTPUT_FILE}.tmp"
    
    # Skip if already processed (resume mode)
    if [ "$RESUME" = true ] && [ -f "$DONE_FILE" ]; then
        SKIPPED=$((SKIPPED + 1))
        if [ $((SKIPPED % 100)) -eq 0 ]; then
            echo "  Skipped $SKIPPED already-processed files..."
        fi
        continue
    fi
    
    # Create output directory if needed
    mkdir -p "$OUTPUT_DIR_FOR_FILE"
    
    # Remove any incomplete temp file
    [ -f "$TEMP_FILE" ] && rm -f "$TEMP_FILE"
    
    # Get size before
    SIZE_BEFORE=$(ls -lh "$file" 2>/dev/null | awk '{print $5}')
    
    # Optimize with vips (Q=quality, strip=remove metadata)
    if vips jpegsave "$file" "$TEMP_FILE" --Q=$QUALITY --strip 2>/dev/null; then
        # Move to final location
        mv "$TEMP_FILE" "$OUTPUT_FILE"
        # Mark as done
        touch "$DONE_FILE"
        
        PROCESSED=$((PROCESSED + 1))
        
        # Get size after
        SIZE_AFTER=$(ls -lh "$OUTPUT_FILE" 2>/dev/null | awk '{print $5}')
        
        # Show detailed progress for first few files and then every 100th
        if [ $PROCESSED -le 5 ] || [ $((PROCESSED % 100)) -eq 0 ]; then
            echo "  [$PROCESSED/$TOTAL] $REL_PATH: $SIZE_BEFORE → $SIZE_AFTER"
        fi
        
        # Show progress counter every 100 files
        if [ $((PROCESSED % 100)) -eq 0 ]; then
            echo -e "${GREEN}Progress: $PROCESSED/$TOTAL processed, $SKIPPED skipped${NC}"
        fi
    else
        echo -e "${RED}Failed: $file${NC}"
        rm -f "$TEMP_FILE"
        FAILED=$((FAILED + 1))
    fi
done

echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}Optimization Complete${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}Results:${NC}"
echo "  Processed: $PROCESSED files"
[ $SKIPPED -gt 0 ] && echo "  Skipped: $SKIPPED files (already done)"
[ $FAILED -gt 0 ] && echo -e "  ${RED}Failed: $FAILED files${NC}"

# Get final size
if [ -d "$OUTPUT_PATH" ]; then
    FINAL_SIZE=$(du -sh "$OUTPUT_PATH" | cut -f1)
    echo ""
    echo "  Source size: $SOURCE_SIZE"
    echo "  Output size: $FINAL_SIZE"
    
    # Calculate compression ratio
    SOURCE_BYTES=$(du -sb "$SOURCE_PATH" 2>/dev/null | cut -f1)
    OUTPUT_BYTES=$(du -sb "$OUTPUT_PATH" 2>/dev/null | cut -f1)
    if [ -n "$SOURCE_BYTES" ] && [ -n "$OUTPUT_BYTES" ] && [ "$SOURCE_BYTES" -gt 0 ]; then
        RATIO=$(echo "scale=1; 100 - ($OUTPUT_BYTES * 100 / $SOURCE_BYTES)" | bc)
        echo "  Compression: ${RATIO}% reduction"
    fi
fi

# Show sample files for quality check
echo -e "\n${YELLOW}Sample files for quality check:${NC}"
find "$OUTPUT_PATH" -name "*.jpg" -type f | head -3 | while read -r sample; do
    echo "  $sample"
done

echo -e "\n${GREEN}Done!${NC}"
echo ""
echo "Output directory: $OUTPUT_PATH"
echo ""
echo "Cleanup options:"
echo "  • Remove .done markers: find \"$OUTPUT_PATH\" -name '*.done' -delete"
echo "  • Remove output dir: rm -rf \"$OUTPUT_PATH\""
