# syntax=docker/dockerfile:1
# Markdown to PDF Converter with Mermaid Support
FROM node:20-bookworm

# Install LaTeX, Pandoc, and fonts
RUN apt-get update && apt-get install -y --no-install-recommends \
    pandoc \
    texlive-xetex \
    texlive-lang-japanese \
    texlive-lang-chinese \
    texlive-fonts-recommended \
    texlive-fonts-extra \
    texlive-latex-extra \
    texlive-latex-recommended \
    # ulem.sty を提供する。Pandoc は取り消し線 (~~text~~) を含む Markdown に対し
    # \usepackage[normalem]{ulem} を出力するため、これが無いと
    # "LaTeX Error: File `ulem.sty' not found." で変換が失敗する。
    texlive-plain-generic \
    lmodern \
    fonts-noto-cjk \
    fonts-ipafont \
    fonts-liberation \
    poppler-utils \
    unzip \
    zip \
    xvfb \
    xauth \
    chromium \
    && rm -rf /var/lib/apt/lists/*

# Install mermaid-cli
RUN npm install -g @mermaid-js/mermaid-cli

# Puppeteer config for mmdc (mermaid-cli) with --no-sandbox for root execution
#
# NOTE: printf ではなくヒアドキュメント (RUN cat > ... << 'EOF') を使うと、
# BuildKit でしか動かない。従来ビルダー (DOCKER_BUILDKIT=0、buildx 未インストール)
# では Dockerfile パーサがヒアドキュメントを解釈せず、cat が標準入力から何も
# 受け取らないまま **0 バイトのファイル** を作る。結果 mmdc が
# `JSON.parse("")` で落ち、すべての Mermaid 図が変換に失敗する。
# action.yml は DOCKER_BUILDKIT=1 を指定しているので CI では顕在化しないが、
# README が案内しているローカル実行 (docker build -t md2pdf ./scripts) で壊れる。
# printf ならビルダーによらず同じ結果になる。
RUN printf '%s\n' \
    '{' \
    '  "executablePath": "/usr/bin/chromium",' \
    '  "args": ["--no-sandbox", "--disable-setuid-sandbox"]' \
    '}' > /usr/local/share/puppeteer-config.json \
 && node -e "JSON.parse(require('fs').readFileSync('/usr/local/share/puppeteer-config.json','utf8'))" \
 && echo "puppeteer-config.json: OK"

ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV MMDC_PUPPETEER_CONFIG=/usr/local/share/puppeteer-config.json

# UTF-8 locale: required for Pandoc to resolve non-ASCII (e.g. Japanese) image
# file paths. Without this, the default POSIX locale causes
# `[WARNING] Could not fetch resource ...` and images get replaced by alt text.
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Create work directory
WORKDIR /work

# Copy the conversion script and header file
COPY md2pdf.sh /usr/local/bin/md2pdf.sh
COPY header.tex /usr/local/share/pandoc/header.tex
RUN chmod +x /usr/local/bin/md2pdf.sh

# NOTE: Run as root to ensure compatibility with GitHub Actions workspace mounts.
# The previous 'USER 1000:1000' caused permission issues with /work/output.

ENTRYPOINT ["/usr/local/bin/md2pdf.sh"]
CMD ["/work/input", "/work/output"]
