#!/bin/bash

# AVIF optimization script using avifenc (libavif)
# Usage: ./optimize_avif_avifenc.sh [quality] [source_dir] [speed]
# Examples:
#   ./optimize_avif_avifenc.sh 30              # cq-level=30 from shopping_extracted_backup
#   ./optimize_avif_avifenc.sh 20              # cq-level=20 from shopping_extracted_backup
#   ./optimize_avif_avifenc.sh 25 custom_dir 4 # cq-level=25, speed=4 from custom_dir

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
# Note: avifenc uses cq-level (0-63, lower=better quality)
# We'll use this directly instead of converting from 0-100
CQ_LEVEL=${1:-25}
SOURCE_DIR=${2:-"shopping_extracted_backup"}
SPEED=${3:-4}  # Speed preset (0-10, 0=slowest/best, 10=fastest)

# Validate cq-level parameter
if ! [[ "$CQ_LEVEL" =~ ^[0-9]+$ ]] || [ "$CQ_LEVEL" -lt 0 ] || [ "$CQ_LEVEL" -gt 63 ]; then
    echo -e "${RED}Error: CQ level must be a number between 0 and 63${NC}"
    echo "Note: Lower values = better quality (0=lossless, 18-25=good, 30+=lower quality)"
    echo "Usage: $0 [cq_level] [source_dir] [speed]"
    exit 1
fi

# Validate speed parameter
if ! [[ "$SPEED" =~ ^[0-9]$|^10$ ]]; then
    echo -e "${RED}Error: Speed must be a number between 0 and 10${NC}"
    echo "Usage: $0 [cq_level] [source_dir] [speed]"
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

# Output directory based on cq-level and speed
OUTPUT_DIR="shopping_extracted_avif_cq${CQ_LEVEL}_s${SPEED}"
OUTPUT_PATH="$PROJECT_ROOT/$OUTPUT_DIR"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}avifenc AVIF Optimization${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}Configuration:${NC}"
echo "  CQ Level: $CQ_LEVEL (0=lossless, lower=better quality)"
echo "  Speed: $SPEED (0=slowest/best, 10=fastest)"
echo "  Source: $SOURCE_PATH"
echo "  Output: $OUTPUT_PATH"
echo ""

# Check if avifenc is installed
if ! command -v avifenc &> /dev/null; then
    echo -e "${RED}avifenc is not installed!${NC}"
    echo ""
    echo "Install options:"
    echo "  macOS: brew install libavif"
    echo "  Ubuntu/Debian: sudo apt install libavif-bin"
    echo "  From source: https://github.com/AOMediaCodec/libavif"
    exit 1
fi

# Check source directory
if [ ! -d "$SOURCE_PATH" ]; then
    echo -e "${RED}Source directory not found: $SOURCE_PATH${NC}"
    exit 1
fi

# Count total images (including JPEG and PNG)
echo "Counting images..."
TOTAL=$(find "$SOURCE_PATH" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" \) | wc -l | tr -d ' ')
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

# Determine number of threads
THREADS=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)
echo "Using $THREADS threads for encoding"

echo -e "\n${YELLOW}Ready to optimize $TOTAL images to AVIF (cq-level=$CQ_LEVEL, speed=$SPEED)${NC}"
echo -e "${YELLOW}Note: AVIF encoding is CPU-intensive, especially at lower speed settings${NC}"
echo ""
echo "Quality guide (vs JPEG equivalents):"
echo "  cq-level 0     = lossless"
echo "  cq-level 10-15 = excellent quality (≈ JPEG Q=90-100)"
echo "  cq-level 18-25 = good quality (≈ JPEG Q=75-85)"
echo "  cq-level 25-35 = moderate quality (≈ JPEG Q=50-70)"
echo "  cq-level 35-45 = lower quality (≈ JPEG Q=30-40)"
echo "  cq-level 45-55 = very low quality (≈ JPEG Q=10-20)"
echo ""
echo "Press Ctrl+C to cancel, or Enter to continue..."
read -r

echo -e "\n${GREEN}Processing images...${NC}"

# Process images
COUNT=0
FAILED=0
SKIPPED=0
PROCESSED=0

find "$SOURCE_PATH" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" \) | while read -r file; do
    COUNT=$((COUNT + 1))
    
    # Get relative path from source
    REL_PATH=${file#$SOURCE_PATH/}
    # Change extension to .avif
    REL_PATH_AVIF="${REL_PATH%.*}.avif"
    OUTPUT_FILE="$OUTPUT_PATH/$REL_PATH_AVIF"
    OUTPUT_DIR_FOR_FILE=$(dirname "$OUTPUT_FILE")
    DONE_FILE="${OUTPUT_FILE}.done"
    TEMP_FILE="${OUTPUT_FILE}.tmp.avif"
    
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
    
    # Encode with avifenc
    # --min and --max set the quantizer range (we'll use same value for consistent quality)
    # -a cq-level sets the constant quality level
    # -a tune=ssim optimizes for structural similarity
    # --speed sets encoding speed
    # --jobs sets thread count
    if avifenc \
        --min "$CQ_LEVEL" \
        --max "$CQ_LEVEL" \
        -a end-usage=q \
        -a cq-level="$CQ_LEVEL" \
        -a tune=ssim \
        --speed "$SPEED" \
        --jobs "$THREADS" \
        "$file" \
        "$TEMP_FILE" >/dev/null 2>&1; then
        
        # Move to final location
        mv "$TEMP_FILE" "$OUTPUT_FILE"
        # Mark as done
        touch "$DONE_FILE"
        
        PROCESSED=$((PROCESSED + 1))
        
        # Get size after
        SIZE_AFTER=$(ls -lh "$OUTPUT_FILE" 2>/dev/null | awk '{print $5}')
        
        # Calculate size reduction percentage
        SIZE_BEFORE_BYTES=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
        SIZE_AFTER_BYTES=$(stat -f%z "$OUTPUT_FILE" 2>/dev/null || stat -c%s "$OUTPUT_FILE" 2>/dev/null)
        if [ -n "$SIZE_BEFORE_BYTES" ] && [ -n "$SIZE_AFTER_BYTES" ] && [ "$SIZE_BEFORE_BYTES" -gt 0 ]; then
            REDUCTION=$(echo "scale=1; 100 - ($SIZE_AFTER_BYTES * 100 / $SIZE_BEFORE_BYTES)" | bc)
            SIZE_INFO="$SIZE_BEFORE → $SIZE_AFTER (${REDUCTION}% smaller)"
        else
            SIZE_INFO="$SIZE_BEFORE → $SIZE_AFTER"
        fi
        
        # Show progress for every file with compression ratio
        echo "  [$PROCESSED/$TOTAL] ${REL_PATH%.*}: $SIZE_INFO"
        
        # Show progress counter every 10 files
        if [ $((PROCESSED % 10)) -eq 0 ]; then
            echo -e "${GREEN}Progress: $PROCESSED/$TOTAL processed, $SKIPPED skipped${NC}"
        fi
    else
        echo -e "${RED}Failed: $file${NC}"
        rm -f "$TEMP_FILE"
        FAILED=$((FAILED + 1))
    fi
done

echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}AVIF Optimization Complete${NC}"
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
find "$OUTPUT_PATH" -name "*.avif" -type f | head -3 | while read -r sample; do
    SIZE=$(ls -lh "$sample" 2>/dev/null | awk '{print $5}')
    echo "  $sample ($SIZE)"
done

echo -e "\n${GREEN}Done!${NC}"
echo ""
echo "Output directory: $OUTPUT_PATH"
echo ""
echo "Cleanup options:"
echo "  • Remove .done markers: find \"$OUTPUT_PATH\" -name '*.done' -delete"
echo "  • Remove output dir: rm -rf \"$OUTPUT_PATH\""
