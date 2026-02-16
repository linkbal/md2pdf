# md2pdf

A GitHub Action that converts Markdown to PDF and DOCX.

## Features

- Japanese font support (Noto CJK fonts)
- Automatic Mermaid diagram conversion
- Automatic table of contents generation
- DOCX output support (with template customization)
- Automatic artifact and release creation

## Usage

### Basic (Generate both PDF and DOCX)

```yaml
- uses: linkbal/md2pdf@v1
  with:
    input_dir: 'docs'
```

### PDF Only

```yaml
- uses: linkbal/md2pdf@v1
  with:
    input_dir: 'docs'
    output_formats: 'pdf'
```

### DOCX Only

```yaml
- uses: linkbal/md2pdf@v1
  with:
    input_dir: 'docs'
    output_formats: 'docx'
```

### With DOCX Template

```yaml
- uses: linkbal/md2pdf@v1
  with:
    input_dir: 'docs'
    output_formats: 'pdf,docx'
    docx_template: 'templates/custom.docx'
```

### With Release

```yaml
- uses: linkbal/md2pdf@v1
  with:
    input_dir: 'docs'
    output_formats: 'pdf,docx'
    create_release: true
    release_name_prefix: 'Proposal'
```

## Input Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `input_dir` | Directory containing Markdown files | `docs` |
| `output_dir` | Output directory | `output` |
| `output_formats` | Output formats (comma-separated) | `pdf,docx` |
| `docx_template` | Path to DOCX template | (none) |
| `upload_artifact` | Upload as artifact | `true` |
| `artifact_name` | Artifact name | `docs-output` |
| `retention_days` | Artifact retention days | `30` |
| `create_release` | Create GitHub Release | `false` |
| `release_name_prefix` | Release name prefix | `Release` |
| `keep_releases` | Number of releases to keep (0 for unlimited) | `5` |

## Outputs

| Output | Description |
|--------|-------------|
| `tag_name` | Created tag name (when create_release=true) |

## Complete Example

```yaml
name: Generate Documents

on:
  push:
    branches: [main]
    paths: ['docs/**']
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: write

    steps:
      - uses: actions/checkout@v4

      - uses: linkbal/md2pdf@v1
        with:
          input_dir: 'docs'
          output_formats: 'pdf,docx'
          docx_template: 'templates/style.docx'
          create_release: true
          release_name_prefix: 'Documentation'
```

## Creating a DOCX Template

1. Create a new document in Word
2. Configure styles (Heading 1, Heading 2, Body text, etc.)
3. Save as `.docx`
4. Place in your repository (e.g., `templates/style.docx`)

## Local Execution

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `OUTPUT_FORMATS` | Output formats (comma-separated: `pdf`, `docx`) | `pdf,docx` |
| `DOCX_TEMPLATE` | Path to reference DOCX template | (none) |
| `MMDC_PUPPETEER_CONFIG` | Path to Puppeteer config JSON for mermaid-cli | (none in local execution, `/usr/local/share/puppeteer-config.json` in Docker) |

### Examples

```bash
git clone https://github.com/linkbal/md2pdf.git
cd md2pdf
docker build -t md2pdf ./scripts

# PDF only
docker run --rm \
  -v /path/to/docs:/work/input:ro \
  -v /path/to/output:/work/output \
  -e OUTPUT_FORMATS=pdf \
  md2pdf

# PDF + DOCX
docker run --rm \
  -v /path/to/docs:/work/input:ro \
  -v /path/to/output:/work/output \
  md2pdf

# With template
docker run --rm \
  -v /path/to/docs:/work/input:ro \
  -v /path/to/output:/work/output \
  -v /path/to/template.docx:/work/template.docx:ro \
  -e DOCX_TEMPLATE=/work/template.docx \
  md2pdf

# With custom Puppeteer config for Mermaid
docker run --rm \
  -v /path/to/docs:/work/input:ro \
  -v /path/to/output:/work/output \
  -v /path/to/puppeteer-config.json:/work/puppeteer-config.json:ro \
  -e MMDC_PUPPETEER_CONFIG=/work/puppeteer-config.json \
  md2pdf
```

### Security Considerations for Local Execution

The Docker container runs as root user with `--no-sandbox` flag for Chromium. This is to ensure compatibility with GitHub Actions workspace mounts. However, be aware that `--no-sandbox` disables Chromium's sandbox security layer, which normally isolates rendering processes and limits their access to the container's filesystem and other resources. Running with `--no-sandbox` therefore increases the potential impact if malicious or compromised content is rendered.

For enhanced security, you can run as a non-root user with Chromium sandbox enabled:

```bash
# Create a Puppeteer config without --no-sandbox
echo '{"executablePath": "/usr/bin/chromium"}' > /tmp/puppeteer-config.json

docker run --rm \
  --user $(id -u):$(id -g) \
  --security-opt seccomp=unconfined \
  -v /path/to/docs:/work/input:ro \
  -v /path/to/output:/work/output \
  -v /tmp/puppeteer-config.json:/work/puppeteer-config.json:ro \
  -e MMDC_PUPPETEER_CONFIG=/work/puppeteer-config.json \
  md2pdf
```

**Note**: When running as a non-root user:
- `--security-opt seccomp=unconfined` is **required** because Chromium's sandbox uses unprivileged user namespaces, which are restricted by Docker's default seccomp profile. Without this option, you will get "No usable sandbox!" error.
- Override `MMDC_PUPPETEER_CONFIG` with a config that removes `--no-sandbox` flags

## License

MIT
