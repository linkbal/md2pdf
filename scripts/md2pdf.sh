#!/bin/bash

# Markdown to PDF・DOCX Conversion Script with Mermaid Support
# Usage: ./md2pdf.sh [input_dir] [output_dir]
# Example: ./md2pdf.sh ./proposal ./pdf
# Example: ./md2pdf.sh (converts all .md files from . directory to ./pdf)
#
# Environment variables:
#   OUTPUT_FORMATS=pdf,docx  - Output formats (comma-separated)
#   DOCX_TEMPLATE=/path      - Path to reference DOCX template
#
# Requirements:
# - pandoc
# - xelatex (texlive-xetex, texlive-lang-japanese)
# - mermaid-cli (npm install -g @mermaid-js/mermaid-cli)
# - fonts: Noto CJK fonts, Liberation fonts

set -e

# 入力ディレクトリと出力ディレクトリを設定
if [ $# -eq 0 ]; then
  INPUT_DIR="."
else
  INPUT_DIR=${1:-"."}
fi
OUTPUT_DIR=${2:-"./pdf"}

# 環境変数からオプションを取得
OUTPUT_FORMATS=${OUTPUT_FORMATS:-"pdf,docx"}
DOCX_TEMPLATE=${DOCX_TEMPLATE:-""}

# 出力形式を判定
OUTPUT_PDF=false
OUTPUT_DOCX=false
if [[ "$OUTPUT_FORMATS" == *"pdf"* ]]; then
    OUTPUT_PDF=true
fi
if [[ "$OUTPUT_FORMATS" == *"docx"* ]]; then
    OUTPUT_DOCX=true
fi

# パスの末尾のスラッシュを削除
INPUT_DIR=${INPUT_DIR%/}

# 出力ディレクトリがなければ作成
mkdir -p "$OUTPUT_DIR"

# 一時ディレクトリを作成（mermaid画像用）
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# mermaid-cliがインストールされているかチェック
if ! command -v mmdc &> /dev/null; then
    echo "警告: mermaid-cli (mmdc) がインストールされていません。"
    echo "Mermaidダイアグラムを使用する場合は、以下のコマンドでインストールしてください:"
    echo "npm install -g @mermaid-js/mermaid-cli"
    echo ""
    echo "Mermaidダイアグラムなしで処理を続行します..."
    MERMAID_AVAILABLE=false
else
    MERMAID_AVAILABLE=true
fi

# Puppeteer設定ファイル（Docker環境用）
PUPPETEER_CONFIG=${MMDC_PUPPETEER_CONFIG:-""}

# Markdownファイルを検索して配列に格納
mapfile -t md_files < <(find "$INPUT_DIR" -name "*.md" -not -path "*/node_modules/*" -not -path "*/.git/*")

# 処理したファイル数をカウント
count=0
success_count=0

echo "========================================"
echo "Markdown to PDF・DOCX Converter"
echo "========================================"
echo "入力ディレクトリ: $INPUT_DIR"
echo "出力ディレクトリ: $OUTPUT_DIR"
echo "処理するファイル数: ${#md_files[@]}"
echo "出力形式: $OUTPUT_FORMATS"
if [ -n "$DOCX_TEMPLATE" ]; then
    echo "DOCXテンプレート: $DOCX_TEMPLATE"
fi
echo "========================================"

# Mermaidダイアグラムを画像に変換する関数
process_mermaid() {
    local input_file="$1"
    local temp_file="$2"

    if [ "$MERMAID_AVAILABLE" = false ]; then
        cp "$input_file" "$temp_file"
        return
    fi

    # Mermaidコードブロックを検索して画像に変換
    local mermaid_counter=0
    local in_mermaid=false
    local mermaid_content=""
    local output_content=""

    while IFS= read -r line; do
        if [[ "$line" =~ ^\`\`\`mermaid ]]; then
            in_mermaid=true
            mermaid_content=""
            continue
        elif [[ "$line" =~ ^\`\`\`$ ]] && [ "$in_mermaid" = true ]; then
            # Mermaidコードブロックの終了
            in_mermaid=false
            ((++mermaid_counter))

            # 一時的なmermaidファイルを作成
            local mermaid_file="$TEMP_DIR/mermaid_${mermaid_counter}.mmd"
            local png_file="$TEMP_DIR/mermaid_${mermaid_counter}.png"

            echo "$mermaid_content" > "$mermaid_file"

            # mermaidを画像に変換（Dev Container環境対応）
            local error_output
            local conversion_success
            local mmdc_opts="-i $mermaid_file -o $png_file -t neutral -b white --width 800 --height 600"

            # Puppeteer設定ファイルがある場合は追加
            if [ -n "$PUPPETEER_CONFIG" ] && [ -f "$PUPPETEER_CONFIG" ]; then
                mmdc_opts="$mmdc_opts -p $PUPPETEER_CONFIG"
            fi

            if command -v xvfb-run &> /dev/null; then
                # Dev Container環境ではxvfb-runを使用
                if error_output=$(xvfb-run -a mmdc $mmdc_opts 2>&1); then
                    conversion_success=true
                else
                    conversion_success=false
                fi
            else
                # 通常環境
                if error_output=$(mmdc $mmdc_opts 2>&1); then
                    conversion_success=true
                else
                    conversion_success=false
                fi
            fi

            if [ "$conversion_success" = true ]; then
                # 成功した場合、画像参照に置き換え
                output_content+="![Mermaid Diagram]($png_file)"$'\n'
            else
                # 失敗した場合、エラー詳細を出力して元のコードブロックを保持
                echo "エラー: Mermaidダイアグラム $mermaid_counter の変換に失敗しました"
                echo "詳細エラー: $error_output"
                output_content+='```mermaid'$'\n'
                output_content+="$mermaid_content"
                output_content+='```'$'\n'
            fi
            continue
        fi

        if [ "$in_mermaid" = true ]; then
            mermaid_content+="$line"$'\n'
        else
            output_content+="$line"$'\n'
        fi
    done < "$input_file"

    # 処理済みの内容を一時ファイルに書き込み
    printf "%s" "$output_content" > "$temp_file"
}

# 各Markdownファイルを処理
for md_file in "${md_files[@]}"; do
    # 相対パスを計算
    if [ "$INPUT_DIR" = "." ]; then
        rel_path="$md_file"
    else
        rel_path="${md_file#$INPUT_DIR/}"
    fi

    dir_path=$(dirname "$rel_path")

    # 出力ディレクトリを作成
    output_dir_path="$OUTPUT_DIR/$dir_path"
    mkdir -p "$output_dir_path"

    # 出力ファイルパスを決定
    pdf_file="$OUTPUT_DIR/${rel_path%.md}.pdf"
    docx_file="$OUTPUT_DIR/${rel_path%.md}.docx"

    echo ""
    echo "変換中: $md_file"

    # Mermaidダイアグラムを処理
    temp_md_file="$TEMP_DIR/$(basename "$md_file")"
    process_mermaid "$md_file" "$temp_md_file"

    # ヘッダーファイルのパス（Docker内または直接実行用）
    HEADER_FILE="/usr/local/share/pandoc/header.tex"
    if [ ! -f "$HEADER_FILE" ]; then
        HEADER_FILE="$(dirname "$0")/header.tex"
    fi

    local_success=true

    # PDF変換
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
            echo "     成功"
        else
            echo "     失敗"
            local_success=false
        fi
    fi

    # DOCX変換
    if [ "$OUTPUT_DOCX" = "true" ]; then
        echo "  -> DOCX: $docx_file"

        # テンプレートオプションを構築
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
            echo "     成功"
        else
            echo "     失敗"
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
echo "変換完了"
echo "処理ファイル数: $count"
echo "成功: $success_count"
echo "失敗: $((count - success_count))"
echo "========================================"
