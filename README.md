# md2pdf

Markdown を PDF・DOCX に変換する GitHub Action です。

## 特徴

- 日本語フォント対応（Noto CJK フォント）
- Mermaid ダイアグラムの自動変換
- 目次の自動生成
- DOCX出力対応（テンプレート指定可能）
- アーティファクト・リリース自動作成

## 使い方

### 基本（PDFのみ）

```yaml
- uses: linkbal/md2pdf@v1
  with:
    input_dir: 'docs'
```

### PDF + DOCX

```yaml
- uses: linkbal/md2pdf@v1
  with:
    input_dir: 'docs'
    output_docx: true
```

### DOCX テンプレート指定

```yaml
- uses: linkbal/md2pdf@v1
  with:
    input_dir: 'docs'
    output_docx: true
    docx_template: 'templates/custom.docx'
```

### リリース付き

```yaml
- uses: linkbal/md2pdf@v1
  with:
    input_dir: 'docs'
    output_docx: true
    create_release: true
    release_name_prefix: '提案書'
```

## 入力パラメータ

| パラメータ | 説明 | デフォルト |
|-----------|------|-----------|
| `input_dir` | Markdownファイルのディレクトリ | `docs` |
| `output_dir` | 出力ディレクトリ | `output` |
| `output_docx` | DOCXも生成するか | `false` |
| `docx_template` | DOCXテンプレートのパス | (なし) |
| `upload_artifact` | アーティファクトをアップロードするか | `true` |
| `artifact_name` | アーティファクト名 | `docs-output` |
| `retention_days` | アーティファクトの保持日数 | `30` |
| `create_release` | GitHub Releaseを作成するか | `false` |
| `release_name_prefix` | リリース名のプレフィックス | `Release` |
| `keep_releases` | 保持するリリース数（0で無制限） | `5` |

## 出力

| 出力 | 説明 |
|------|------|
| `tag_name` | 作成されたタグ名（create_release=true時） |

## 完全な例

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
          output_docx: true
          docx_template: 'templates/style.docx'
          create_release: true
          release_name_prefix: 'ドキュメント'
```

## DOCXテンプレートの作成方法

1. Wordで新規文書を作成
2. スタイル（見出し1、見出し2、本文など）を設定
3. `.docx`として保存
4. リポジトリに配置（例: `templates/style.docx`）

## ローカルでの実行

```bash
git clone https://github.com/linkbal/md2pdf.git
cd md2pdf
docker build -t md2pdf ./scripts

# PDFのみ
docker run --rm \
  -v /path/to/docs:/work/input:ro \
  -v /path/to/output:/work/output \
  md2pdf

# PDF + DOCX
docker run --rm \
  -v /path/to/docs:/work/input:ro \
  -v /path/to/output:/work/output \
  -e OUTPUT_DOCX=true \
  md2pdf

# テンプレート指定
docker run --rm \
  -v /path/to/docs:/work/input:ro \
  -v /path/to/output:/work/output \
  -v /path/to/template.docx:/work/template.docx:ro \
  -e OUTPUT_DOCX=true \
  -e DOCX_TEMPLATE=/work/template.docx \
  md2pdf
```

## ライセンス

MIT
