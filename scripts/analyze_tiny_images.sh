#!/bin/bash

# Script to analyze tiny images and test ultra-low quality compression
# This explores potential savings by using very low quality for small thumbnails

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Base directory
BASE_DIR="$PROJECT_ROOT/shopping_extracted_backup"
TEST_DIR="/tmp/tiny_image_test_$$"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Tiny Image Optimization Analysis${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Create test directory
mkdir -p "$TEST_DIR"

echo -e "${YELLOW}Step 1: Sampling images by size...${NC}"

# Sample some tiny, small, medium images
TINY_SAMPLES=()
SMALL_SAMPLES=()
MEDIUM_SAMPLES=()
LARGE_SAMPLES=()

# Counter variables
TINY_COUNT=0
SMALL_COUNT=0
MEDIUM_COUNT=0
LARGE_COUNT=0
TOTAL_COUNT=0

TINY_SIZE=0
SMALL_SIZE=0
MEDIUM_SIZE=0
LARGE_SIZE=0
TOTAL_SIZE=0

echo "Analyzing image distribution (this may take a moment)..."

# Process a subset for speed - just analyze the B directory which has most images
find "$BASE_DIR/B" -name "*.jpg" -o -name "*.jpeg" 2>/dev/null | while read -r file; do
    SIZE_BYTES=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    SIZE_KB=$((SIZE_BYTES / 1024))
    
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    TOTAL_SIZE=$((TOTAL_SIZE + SIZE_BYTES))
    
    if [ $SIZE_KB -lt 5 ]; then
        TINY_COUNT=$((TINY_COUNT + 1))
        TINY_SIZE=$((TINY_SIZE + SIZE_BYTES))
        if [ ${#TINY_SAMPLES[@]} -lt 5 ]; then
            TINY_SAMPLES+=("$file")
        fi
    elif [ $SIZE_KB -lt 20 ]; then
        SMALL_COUNT=$((SMALL_COUNT + 1))
        SMALL_SIZE=$((SMALL_SIZE + SIZE_BYTES))
        if [ ${#SMALL_SAMPLES[@]} -lt 5 ]; then
            SMALL_SAMPLES+=("$file")
        fi
    elif [ $SIZE_KB -lt 100 ]; then
        MEDIUM_COUNT=$((MEDIUM_COUNT + 1))
        MEDIUM_SIZE=$((MEDIUM_SIZE + SIZE_BYTES))
        if [ ${#MEDIUM_SAMPLES[@]} -lt 3 ]; then
            MEDIUM_SAMPLES+=("$file")
        fi
    else
        LARGE_COUNT=$((LARGE_COUNT + 1))
        LARGE_SIZE=$((LARGE_SIZE + SIZE_BYTES))
        if [ ${#LARGE_SAMPLES[@]} -lt 2 ]; then
            LARGE_SAMPLES+=("$file")
        fi
    fi
    
    # Show progress every 1000 files
    if [ $((TOTAL_COUNT % 1000)) -eq 0 ]; then
        echo "  Processed $TOTAL_COUNT files..."
        # Write current stats to temp file for persistence
        echo "$TINY_COUNT $SMALL_COUNT $MEDIUM_COUNT $LARGE_COUNT $TINY_SIZE $SMALL_SIZE $MEDIUM_SIZE $LARGE_SIZE" > "$TEST_DIR/stats.tmp"
    fi
done

# Read final stats if they were written
if [ -f "$TEST_DIR/stats.tmp" ]; then
    read TINY_COUNT SMALL_COUNT MEDIUM_COUNT LARGE_COUNT TINY_SIZE SMALL_SIZE MEDIUM_SIZE LARGE_SIZE < "$TEST_DIR/stats.tmp"
fi

echo ""
echo -e "${GREEN}Image Distribution in /B directory:${NC}"
echo "  Tiny (<5KB):    $TINY_COUNT images, $(echo "scale=2; $TINY_SIZE/1024/1024" | bc) MB"
echo "  Small (5-20KB): $SMALL_COUNT images, $(echo "scale=2; $SMALL_SIZE/1024/1024" | bc) MB"
echo "  Medium (20-100KB): $MEDIUM_COUNT images, $(echo "scale=2; $MEDIUM_SIZE/1024/1024" | bc) MB"
echo "  Large (>100KB): $LARGE_COUNT images, $(echo "scale=2; $LARGE_SIZE/1024/1024" | bc) MB"
echo "  Total: $TOTAL_COUNT images"
echo ""

echo -e "${YELLOW}Step 2: Testing compression on sample images...${NC}"
echo ""

# Function to test compression at different quality levels
test_compression() {
    local file="$1"
    local category="$2"
    
    if [ ! -f "$file" ]; then
        return
    fi
    
    local filename=$(basename "$file")
    local orig_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    local orig_dims=$(identify -format "%wx%h" "$file" 2>/dev/null || echo "unknown")
    
    echo -e "${BLUE}Testing $category image: $filename${NC}"
    echo "  Original: $(ls -lh "$file" | awk '{print $5}'), $orig_dims"
    
    # Test different quality levels
    for quality in 10 20 30 50 70; do
        local test_file="$TEST_DIR/${filename%.jpg}_q${quality}.jpg"
        
        # Use vips for compression
        if vips jpegsave "$file" "$test_file" --Q=$quality --strip 2>/dev/null; then
            local new_size=$(stat -f%z "$test_file" 2>/dev/null || stat -c%s "$test_file" 2>/dev/null)
            local savings=$(( (orig_size - new_size) * 100 / orig_size ))
            local new_size_display=$(ls -lh "$test_file" | awk '{print $5}')
            
            if [ $quality -eq 10 ]; then
                echo -e "  ${GREEN}Q=$quality: $new_size_display (saves ${savings}%) ← Ultra-low for tiny images${NC}"
            else
                echo "  Q=$quality: $new_size_display (saves ${savings}%)"
            fi
        fi
    done
    echo ""
}

# Test samples from each category
echo -e "${GREEN}=== Testing Tiny Images (<5KB) ===${NC}"
for img in "${TINY_SAMPLES[@]}"; do
    test_compression "$img" "TINY"
done

echo -e "${GREEN}=== Testing Small Images (5-20KB) ===${NC}"
for img in "${SMALL_SAMPLES[@]:0:2}"; do  # Just test 2 small images
    test_compression "$img" "SMALL"
done

echo -e "${GREEN}=== Testing Medium Images (20-100KB) ===${NC}"
for img in "${MEDIUM_SAMPLES[@]:0:1}"; do  # Just test 1 medium image
    test_compression "$img" "MEDIUM"
done

echo -e "${YELLOW}Step 3: Calculating potential savings...${NC}"
echo ""

# Calculate potential savings with aggressive compression
echo -e "${BLUE}Potential Savings Strategy:${NC}"
echo "  • Tiny images (<5KB): Compress to Q=10 (expect ~60% savings)"
echo "  • Small images (5-20KB): Compress to Q=20 (expect ~50% savings)"
echo "  • Medium images (20-100KB): Compress to Q=50 (expect ~40% savings)"
echo "  • Large images (>100KB): Compress to Q=70 (expect ~30% savings)"
echo ""

# Estimate savings based on the /B directory analysis
TINY_SAVINGS=$(echo "scale=2; $TINY_SIZE * 0.6 / 1024 / 1024" | bc)
SMALL_SAVINGS=$(echo "scale=2; $SMALL_SIZE * 0.5 / 1024 / 1024" | bc)
MEDIUM_SAVINGS=$(echo "scale=2; $MEDIUM_SIZE * 0.4 / 1024 / 1024" | bc)
LARGE_SAVINGS=$(echo "scale=2; $LARGE_SIZE * 0.3 / 1024 / 1024" | bc)

TOTAL_B_SIZE=$(echo "scale=2; ($TINY_SIZE + $SMALL_SIZE + $MEDIUM_SIZE + $LARGE_SIZE) / 1024 / 1024" | bc)
TOTAL_SAVINGS=$(echo "scale=2; $TINY_SAVINGS + $SMALL_SAVINGS + $MEDIUM_SAVINGS + $LARGE_SAVINGS" | bc)

echo -e "${GREEN}Estimated Savings for /B directory:${NC}"
echo "  Current size: ${TOTAL_B_SIZE} MB"
echo "  Potential savings: ${TOTAL_SAVINGS} MB"
echo "  New estimated size: $(echo "scale=2; $TOTAL_B_SIZE - $TOTAL_SAVINGS" | bc) MB"
echo ""

# Extrapolate to full backup (5.6GB total)
echo -e "${GREEN}Extrapolated to full backup (5.6GB):${NC}"
if [ "$TOTAL_B_SIZE" != "0" ]; then
    SAVINGS_PERCENT=$(echo "scale=2; $TOTAL_SAVINGS * 100 / $TOTAL_B_SIZE" | bc)
    FULL_SAVINGS=$(echo "scale=2; 5600 * $SAVINGS_PERCENT / 100" | bc)
    echo "  Estimated savings: ~${FULL_SAVINGS} MB (${SAVINGS_PERCENT}%)"
    echo "  New total size: ~$(echo "scale=2; 5600 - $FULL_SAVINGS" | bc) MB"
fi

echo ""
echo -e "${YELLOW}Visual Quality Check:${NC}"
echo "Check the test images to verify acceptable quality:"
echo "  ls -la $TEST_DIR/"
echo ""
echo "Compare original vs compressed:"
for img in "${TINY_SAMPLES[@]:0:2}"; do
    if [ -f "$img" ]; then
        filename=$(basename "$img")
        echo "  open $img $TEST_DIR/${filename%.jpg}_q10.jpg"
        break
    fi
done

echo ""
echo -e "${YELLOW}Cleanup test files with:${NC}"
echo "  rm -rf $TEST_DIR"
echo ""

echo -e "${GREEN}Recommendation:${NC}"
echo "For tiny images (<5KB), Q=10 provides massive savings with minimal"
echo "visual impact since these are likely small thumbnails where quality"
echo "is less critical. Consider implementing size-based quality tiers."