#!/bin/bash

# Markdown to PDF/DOCX Conversion Script with Mermaid Support
# Usage: ./md2pdf.sh [input_dir] [output_dir]
# Example: ./md2pdf.sh ./proposal ./pdf
# Example: ./md2pdf.sh (converts all .md files from . directory to ./pdf)
#
# Environment variables:
#   OUTPUT_FORMATS=pdf,docx       - Output formats (comma-separated)
#   DOCX_TEMPLATE=/path           - Path to reference DOCX template
#   MMDC_PUPPETEER_CONFIG=/path   - Path to Puppeteer config JSON for mermaid-cli (mmdc)
#
# Requirements:
# - pandoc
# - xelatex (texlive-xetex, texlive-lang-japanese)
# - mermaid-cli (npm install -g @mermaid-js/mermaid-cli)
# - fonts: Noto CJK fonts, Liberation fonts

set -e

# Set input and output directories
if [ $# -eq 0 ]; then
  INPUT_DIR="."
else
  INPUT_DIR=${1:-"."}
fi
OUTPUT_DIR=${2:-"./pdf"}

# Get options from environment variables
OUTPUT_FORMATS=${OUTPUT_FORMATS:-"pdf,docx"}
DOCX_TEMPLATE=${DOCX_TEMPLATE:-""}

# Determine output formats
OUTPUT_PDF=false
OUTPUT_DOCX=false
if [[ "$OUTPUT_FORMATS" == *"pdf"* ]]; then
    OUTPUT_PDF=true
fi
if [[ "$OUTPUT_FORMATS" == *"docx"* ]]; then
    OUTPUT_DOCX=true
fi

# Remove trailing slash from path
INPUT_DIR=${INPUT_DIR%/}

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Create temporary directory for mermaid images
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Check if mermaid-cli is installed
if ! command -v mmdc &> /dev/null; then
    echo "Warning: mermaid-cli (mmdc) is not installed."
    echo "To use Mermaid diagrams, install it with:"
    echo "npm install -g @mermaid-js/mermaid-cli"
    echo ""
    echo "Continuing without Mermaid diagram support..."
    MERMAID_AVAILABLE=false
else
    MERMAID_AVAILABLE=true
fi

# Puppeteer config file (for Docker environment)
PUPPETEER_CONFIG=${MMDC_PUPPETEER_CONFIG:-""}
if [ -n "$PUPPETEER_CONFIG" ] && [ ! -f "$PUPPETEER_CONFIG" ]; then
    echo "Warning: MMDC_PUPPETEER_CONFIG is set but file does not exist: $PUPPETEER_CONFIG"
fi

# Find Markdown files and store in array
mapfile -t md_files < <(find "$INPUT_DIR" -name "*.md" -not -path "*/node_modules/*" -not -path "*/.git/*")

# Count processed files
count=0
success_count=0

echo "========================================"
echo "Markdown to PDF/DOCX Converter"
echo "========================================"
echo "Input directory: $INPUT_DIR"
echo "Output directory: $OUTPUT_DIR"
echo "Files to process: ${#md_files[@]}"
echo "Output formats: $OUTPUT_FORMATS"
if [ -n "$DOCX_TEMPLATE" ]; then
    echo "DOCX template: $DOCX_TEMPLATE"
fi
echo "========================================"

# Function to convert Mermaid diagrams to images
process_mermaid() {
    local input_file="$1"
    local temp_file="$2"

    if [ "$MERMAID_AVAILABLE" = false ]; then
        cp "$input_file" "$temp_file"
        return
    fi

    # Use awk to extract and replace Mermaid blocks
    # This approach preserves newlines correctly
    local mermaid_counter=0
    local intermediate_file="$TEMP_DIR/intermediate.md"

    # First pass: extract mermaid blocks to separate files and mark positions
    awk -v temp_dir="$TEMP_DIR" '
    BEGIN { in_mermaid = 0; counter = 0; mermaid_file = "" }
    /^```mermaid/ {
        in_mermaid = 1
        counter++
        mermaid_file = temp_dir "/mermaid_" counter ".mmd"
        print "MERMAID_PLACEHOLDER_" counter
        next
    }
    /^```$/ && in_mermaid {
        in_mermaid = 0
        close(mermaid_file)
        next
    }
    in_mermaid {
        print >> mermaid_file
        next
    }
    { print }
    ' "$input_file" > "$intermediate_file"

    # Count mermaid blocks
    mermaid_counter=$(ls "$TEMP_DIR"/mermaid_*.mmd 2>/dev/null | wc -l)

    # Convert each mermaid file to PNG
    for i in $(seq 1 "$mermaid_counter"); do
        local mermaid_file="$TEMP_DIR/mermaid_${i}.mmd"
        local png_file="$TEMP_DIR/mermaid_${i}.png"

        if [ ! -f "$mermaid_file" ]; then
            continue
        fi

        local error_output
        local conversion_success
        local -a mmdc_opts=(-i "$mermaid_file" -o "$png_file" -t neutral -b white --width 1200 --height 800)

        # Add Puppeteer config file if available
        if [ -n "$PUPPETEER_CONFIG" ] && [ -f "$PUPPETEER_CONFIG" ]; then
            mmdc_opts+=(-p "$PUPPETEER_CONFIG")
        fi

        # Run mmdc directly (headless by default); Puppeteer config mainly sets Chromium args (e.g. --no-sandbox) and paths
        if error_output=$(mmdc "${mmdc_opts[@]}" 2>&1); then
            conversion_success=true
        else
            conversion_success=false
        fi

        if [ "$conversion_success" = true ]; then
            # Replace placeholder with image reference
            sed -i "s|MERMAID_PLACEHOLDER_${i}|![Mermaid Diagram](${png_file})|" "$intermediate_file"
        else
            # On failure, output error details and restore original code block
            echo "Error: Failed to convert Mermaid diagram $i"
            echo "Details: $error_output"
            # Restore original mermaid block
            # Restore original mermaid block
            # Create a temp file with the replacement
            # Create a temp file with the replacement
            local replacement_file="$TEMP_DIR/replacement_${i}.txt"
            {
                echo '```mermaid'
                cat "$mermaid_file"
                echo '```'
            } > "$replacement_file"
            # Use awk for multi-line replacement
            awk -v placeholder="MERMAID_PLACEHOLDER_${i}" -v replacement_file="$replacement_file" '
            $0 == placeholder {
                while ((getline line < replacement_file) > 0) print line
                close(replacement_file)
                next
            }
            { print }
            ' "$intermediate_file" > "$intermediate_file.tmp" && mv "$intermediate_file.tmp" "$intermediate_file"
        fi
    done

    mv "$intermediate_file" "$temp_file"
}

# Process each Markdown file
for md_file in "${md_files[@]}"; do
    # Calculate relative path
    if [ "$INPUT_DIR" = "." ]; then
        rel_path="$md_file"
    else
        rel_path="${md_file#$INPUT_DIR/}"
    fi

    dir_path=$(dirname "$rel_path")

    # Create output directory
    output_dir_path="$OUTPUT_DIR/$dir_path"
    mkdir -p "$output_dir_path"

    # Determine output file paths
    pdf_file="$OUTPUT_DIR/${rel_path%.md}.pdf"
    docx_file="$OUTPUT_DIR/${rel_path%.md}.docx"

    echo ""
    echo "Converting: $md_file"

    # Process Mermaid diagrams
    temp_md_file="$TEMP_DIR/$rel_path"
    mkdir -p "$(dirname "$temp_md_file")"
    process_mermaid "$md_file" "$temp_md_file"

    # Header file path (for Docker or direct execution)
    HEADER_FILE="/usr/local/share/pandoc/header.tex"
    if [ ! -f "$HEADER_FILE" ]; then
        HEADER_FILE="$(dirname "$0")/header.tex"
    fi

    local_success=true

    # PDF conversion
    if [ "$OUTPUT_PDF" = "true" ]; then
        echo "  -> PDF: $pdf_file"
        if pandoc "$temp_md_file" \
            -o "$pdf_file" \
            --resource-path="$(dirname "$md_file"):$INPUT_DIR:$TEMP_DIR" \
            --pdf-engine=xelatex \
            --toc \
            --toc-depth=3 \
            -V "papersize=a4" \
            -V "geometry:top=2.5cm,bottom=2.5cm,left=3cm,right=2.5cm" \
            -V "fontsize=11pt" \
            -V "linestretch=1.2" \
            -V "documentclass=book" \
            -V "classoption=oneside" \
            -V "mainfont=Liberation Serif" \
            -V "sansfont=Liberation Sans" \
            -V "monofont=Liberation Mono" \
            -V "colorlinks=true" \
            -V "linkcolor=blue" \
            -V "urlcolor=blue" \
            -V "toccolor=black" \
            -H "$HEADER_FILE" \
            -V "block-headings=true"; then
            echo "     Success"
        else
            echo "     Failed"
            local_success=false
        fi
    fi

    # DOCX conversion
    if [ "$OUTPUT_DOCX" = "true" ]; then
        echo "  -> DOCX: $docx_file"

        # Build template options
        docx_opts=()
        if [ -n "$DOCX_TEMPLATE" ] && [ -f "$DOCX_TEMPLATE" ]; then
            docx_opts+=("--reference-doc=$DOCX_TEMPLATE")
        fi

        if pandoc "$temp_md_file" \
            -o "$docx_file" \
            --resource-path="$(dirname "$md_file"):$INPUT_DIR:$TEMP_DIR" \
            --toc \
            --toc-depth=3 \
            "${docx_opts[@]}"; then
            echo "     Success"
        else
            echo "     Failed"
            local_success=false
        fi
    fi

    if [ "$local_success" = true ]; then
        ((++success_count))
    fi
    ((++count))
done

echo ""
echo "========================================"
echo "Conversion complete"
echo "Files processed: $count"
echo "Succeeded: $success_count"
echo "Failed: $((count - success_count))"
echo "========================================"
