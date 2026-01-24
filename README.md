# md2pdf

Markdown を PDF に変換する Reusable GitHub Actions Workflow です。

## 特徴

- 日本語フォント対応（Noto CJK フォント）
- Mermaid ダイアグラムの自動変換
- 目次の自動生成
- GitHub Actions から簡単に呼び出し可能

## 使い方

### 基本的な使い方

他のリポジトリの `.github/workflows/` に以下のようなワークフローを作成します。

```yaml
name: Generate PDF

on:
  push:
    branches: [main]
    paths:
      - 'docs/**'
  workflow_dispatch:

jobs:
  pdf:
    uses: linkbal/md2pdf/.github/workflows/reusable-pdf.yml@main
    with:
      input_dir: 'docs'
```

### 全オプション

```yaml
jobs:
  pdf:
    uses: linkbal/md2pdf/.github/workflows/reusable-pdf.yml@main
    with:
      input_dir: 'docs'              # Markdownファイルのディレクトリ（デフォルト: docs）
      output_dir: 'output'           # PDF出力ディレクトリ（デフォルト: output）
      artifact_name: 'my-pdf'        # アーティファクト名（デフォルト: pdf-output）
      retention_days: 30             # アーティファクト保持日数（デフォルト: 30）
      create_release: true           # GitHub Releaseを作成するか（デフォルト: false）
      keep_releases: 5               # 保持するリリース数（デフォルト: 5）
```

### GitHub Release を自動作成する例

```yaml
name: Generate PDF and Release

on:
  push:
    branches: [main]
    paths:
      - 'docs/**'

jobs:
  pdf:
    uses: linkbal/md2pdf/.github/workflows/reusable-pdf.yml@main
    with:
      input_dir: 'docs'
      create_release: true
      keep_releases: 5
```

## ローカルでの実行

Docker を使ってローカルでも実行できます。

```bash
# このリポジトリをクローン
git clone https://github.com/linkbal/md2pdf.git
cd md2pdf

# Docker イメージをビルド
docker build -t md2pdf ./scripts

# PDF を生成
docker run --rm \
  -v /path/to/your/docs:/work/input:ro \
  -v /path/to/output:/work/output \
  md2pdf /work/input /work/output
```

## 対応フォーマット

### 入力

- Markdown ファイル (`.md`)
- Mermaid ダイアグラム（コードブロック内）

### 出力

- PDF（A4サイズ、目次付き）

## 依存ツール（Dockerイメージに含まれています）

- Pandoc
- XeLaTeX
- mermaid-cli
- Noto CJK フォント
- Liberation フォント

## ライセンス

MIT
