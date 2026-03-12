#!/bin/bash

# Markdown/LaTeX to PDF/DOCX Conversion Script with Mermaid & TeX Image Support
# Usage: ./md2pdf.sh [input_dir] [output_dir]
# Example: ./md2pdf.sh ./proposal ./pdf
# Example: ./md2pdf.sh (converts all .md/.tex files from . directory to ./pdf)
#
# Supported input formats:
#   .md  - Converted via Pandoc + XeLaTeX (with Mermaid support)
#   .tex - Compiled directly with XeLaTeX
#
# TeX image embedding:
#   When a Markdown file references a .tex file as an image, e.g.:
#     ![Caption](path/to/chart.tex)
#   the .tex file is compiled to a PNG image and embedded automatically.
#   Referenced .tex files are excluded from standalone PDF generation.
#
# Environment variables:
#   OUTPUT_FORMATS=pdf,docx       - Output formats (comma-separated, DOCX only for .md)
#   DOCX_TEMPLATE=/path           - Path to reference DOCX template
#   MMDC_PUPPETEER_CONFIG=/path   - Path to Puppeteer config JSON for mermaid-cli (mmdc)
#
# Requirements:
# - pandoc
# - xelatex (texlive-xetex, texlive-lang-japanese)
# - pdftoppm (poppler-utils) - for TeX image conversion
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
HEADER_TEX=${HEADER_TEX:-""}

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

# Build exclude arguments for find
EXCLUDE_PATTERNS=${EXCLUDE_PATTERNS:-""}
FIND_EXCLUDES=(-not -path "*/node_modules/*" -not -path "*/.git/*")
if [ -n "$EXCLUDE_PATTERNS" ]; then
    IFS=',' read -ra PATTERNS <<< "$EXCLUDE_PATTERNS"
    for pattern in "${PATTERNS[@]}"; do
        pattern=$(echo "$pattern" | xargs)  # trim whitespace
        FIND_EXCLUDES+=(-not -path "*/${pattern}/*" -not -path "*/${pattern}")
    done
fi

# Track .tex files referenced as images from Markdown (to skip in standalone processing)
declare -A embedded_tex_files

# Find Markdown and LaTeX files and store in arrays
mapfile -t md_files < <(find "$INPUT_DIR" -name "*.md" "${FIND_EXCLUDES[@]}")
mapfile -t tex_files < <(find "$INPUT_DIR" -name "*.tex" "${FIND_EXCLUDES[@]}")

# Count processed files
count=0
success_count=0

total_files=$(( ${#md_files[@]} + ${#tex_files[@]} ))

echo "========================================"
echo "Markdown/LaTeX to PDF/DOCX Converter"
echo "========================================"
echo "Input directory: $INPUT_DIR"
echo "Output directory: $OUTPUT_DIR"
echo "Files to process: $total_files (${#md_files[@]} md, ${#tex_files[@]} tex)"
echo "Output formats: $OUTPUT_FORMATS"
if [ -n "$DOCX_TEMPLATE" ]; then
    echo "DOCX template: $DOCX_TEMPLATE"
fi
if [ -n "$HEADER_TEX" ]; then
    echo "Custom header: $HEADER_TEX"
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

# Function to convert .tex image references to PNG
# Detects ![...](*.tex) in Markdown, compiles to PNG, and rewrites the reference.
process_tex_images() {
    local input_file="$1"
    local md_source_dir="$2"

    # Find all ![...](*.tex) references
    local tex_refs
    tex_refs=$(grep -oP '!\[[^\]]*\]\([^)]*\.tex\)' "$input_file" 2>/dev/null || true)

    if [ -z "$tex_refs" ]; then
        return
    fi

    echo "  [tex-image] Found .tex image references"

    while IFS= read -r ref; do
        # Extract the .tex path from ![...](path.tex)
        local tex_path
        tex_path=$(echo "$ref" | grep -oP '\(\K[^)]*\.tex')

        # Resolve the full path relative to the Markdown source directory
        local full_tex_path
        if [[ "$tex_path" = /* ]]; then
            full_tex_path="$tex_path"
        else
            full_tex_path="$md_source_dir/$tex_path"
        fi

        # Normalize the path
        full_tex_path=$(realpath "$full_tex_path" 2>/dev/null || echo "$full_tex_path")

        if [ ! -f "$full_tex_path" ]; then
            echo "  [tex-image] Warning: $tex_path not found (resolved: $full_tex_path)"
            continue
        fi

        echo "  [tex-image] Converting: $tex_path"

        # Mark this .tex as embedded (to skip standalone processing later)
        embedded_tex_files["$full_tex_path"]=1

        # Create a unique build directory
        local tex_build_dir="$TEMP_DIR/tex_img_$(echo "$full_tex_path" | md5sum | cut -c1-8)"
        mkdir -p "$tex_build_dir"

        # Compile with xelatex
        local xelatex_ok=true
        for pass in 1 2; do
            if ! xelatex -interaction=nonstopmode \
                -output-directory="$tex_build_dir" \
                "$full_tex_path" > /dev/null 2>&1; then
                if [ "$pass" -eq 1 ]; then
                    xelatex_ok=false
                    break
                fi
            fi
        done

        if [ "$xelatex_ok" = false ]; then
            echo "  [tex-image] Error: xelatex failed for $tex_path"
            continue
        fi

        # Find the generated PDF
        local tex_basename
        tex_basename=$(basename "${full_tex_path%.tex}")
        local generated_pdf="$tex_build_dir/${tex_basename}.pdf"

        if [ ! -f "$generated_pdf" ]; then
            echo "  [tex-image] Error: PDF not generated for $tex_path"
            continue
        fi

        # Convert PDF to PNG using pdftoppm (high resolution)
        local png_base="$TEMP_DIR/tex_img_${tex_basename}"
        if pdftoppm -png -r 300 -singlefile "$generated_pdf" "$png_base" 2>/dev/null; then
            local png_file="${png_base}.png"

            # Escape special characters in the reference for sed
            local escaped_ref
            escaped_ref=$(printf '%s\n' "$ref" | sed 's/[[\.*^$()+?{|]/\\&/g')
            local escaped_png
            escaped_png=$(printf '%s\n' "$png_file" | sed 's/[&/\]/\\&/g')

            # Extract the caption
            local caption
            caption=$(echo "$ref" | grep -oP '!\[\K[^\]]*')

            # Replace the .tex reference with the .png reference
            sed -i "s|${escaped_ref}|![${caption}](${escaped_png})|g" "$input_file"

            echo "  [tex-image] Success: $tex_path -> PNG"
        else
            echo "  [tex-image] Error: pdftoppm failed for $tex_path"
        fi

        # Clean up build directory
        rm -rf "$tex_build_dir"
    done <<< "$tex_refs"
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

    # Process .tex image references (![...](*.tex) -> PNG)
    process_tex_images "$temp_md_file" "$(dirname "$md_file")"

    # Header file path (custom > Docker default > script directory)
    if [ -n "$HEADER_TEX" ] && [ -f "$HEADER_TEX" ]; then
        HEADER_FILE="$HEADER_TEX"
    elif [ -f "/usr/local/share/pandoc/header.tex" ]; then
        HEADER_FILE="/usr/local/share/pandoc/header.tex"
    else
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

# Process each LaTeX file (direct xelatex compilation, PDF only)
for tex_file in "${tex_files[@]}"; do
    # Skip .tex files that were embedded as images in Markdown
    full_tex_path=$(realpath "$tex_file" 2>/dev/null || echo "$tex_file")
    if [ "${embedded_tex_files[$full_tex_path]+_}" ]; then
        echo ""
        echo "Skipping (embedded as image): $tex_file"
        continue
    fi

    # Calculate relative path
    if [ "$INPUT_DIR" = "." ]; then
        rel_path="$tex_file"
    else
        rel_path="${tex_file#$INPUT_DIR/}"
    fi

    dir_path=$(dirname "$rel_path")

    # Create output directory
    output_dir_path="$OUTPUT_DIR/$dir_path"
    mkdir -p "$output_dir_path"

    # Determine output file path
    pdf_file="$OUTPUT_DIR/${rel_path%.tex}.pdf"

    echo ""
    echo "Converting (LaTeX): $tex_file"

    local_success=true

    if [ "$OUTPUT_PDF" = "true" ]; then
        echo "  -> PDF: $pdf_file"

        # Create a temp directory for aux files
        tex_temp_dir="$TEMP_DIR/tex_build"
        mkdir -p "$tex_temp_dir"

        # Run xelatex twice for references/TOC
        xelatex_success=true
        for pass in 1 2; do
            if ! xelatex -interaction=nonstopmode \
                -output-directory="$tex_temp_dir" \
                "$tex_file" > /dev/null 2>&1; then
                if [ "$pass" -eq 1 ]; then
                    xelatex_success=false
                    break
                fi
            fi
        done

        if [ "$xelatex_success" = true ]; then
            # Copy PDF to output directory
            tex_basename=$(basename "${tex_file%.tex}")
            cp "$tex_temp_dir/${tex_basename}.pdf" "$pdf_file"
            echo "     Success"
        else
            echo "     Failed"
            local_success=false
        fi

        # Clean up temp build files
        rm -rf "$tex_temp_dir"
    else
        echo "  -> Skipped (PDF output disabled)"
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
