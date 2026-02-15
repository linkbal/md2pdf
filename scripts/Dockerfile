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
    lmodern \
    fonts-noto-cjk \
    fonts-liberation \
    xvfb \
    xauth \
    chromium \
    && rm -rf /var/lib/apt/lists/*

# Install mermaid-cli
RUN npm install -g @mermaid-js/mermaid-cli

# Puppeteer config for mermaid-cli in Docker
RUN mkdir -p /root/.config/puppeteer && \
    echo '{"executablePath": "/usr/bin/chromium"}' > /root/.config/puppeteer/config.json

# Puppeteer config for mmdc (mermaid-cli)
RUN echo '{"args": []}' > /usr/local/share/puppeteer-config.json

ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV MMDC_PUPPETEER_CONFIG=/usr/local/share/puppeteer-config.json

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
