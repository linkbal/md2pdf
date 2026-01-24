# md2pdf

Markdown を PDF に変換する GitHub Action です。

## 特徴

- 日本語フォント対応（Noto CJK フォント）
- Mermaid ダイアグラムの自動変換
- 目次の自動生成
- アーティファクト・リリース自動作成

## 使い方

### 基本（PDFのみ生成）

```yaml
- uses: linkbal/md2pdf@v1
  with:
    input_dir: 'docs'
```

### リリース付き

```yaml
- uses: linkbal/md2pdf@v1
  with:
    input_dir: 'docs'
    create_release: true
    release_name_prefix: '提案書'
```

## 入力パラメータ

| パラメータ | 説明 | デフォルト |
|-----------|------|-----------|
| `input_dir` | Markdownファイルのディレクトリ | `docs` |
| `output_dir` | PDF出力ディレクトリ | `output` |
| `upload_artifact` | アーティファクトをアップロードするか | `true` |
| `artifact_name` | アーティファクト名 | `pdf-output` |
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
name: Generate PDF

on:
  push:
    branches: [main]
    paths: ['docs/**']
  workflow_dispatch:

jobs:
  pdf:
    runs-on: ubuntu-latest
    permissions:
      contents: write

    steps:
      - uses: actions/checkout@v4

      - uses: linkbal/md2pdf@v1
        with:
          input_dir: 'docs'
          artifact_name: 'my-pdf'
          create_release: true
          release_name_prefix: 'ドキュメント'
          keep_releases: 5
```

## ローカルでの実行

```bash
git clone https://github.com/linkbal/md2pdf.git
cd md2pdf
docker build -t md2pdf ./scripts
docker run --rm \
  -v /path/to/docs:/work/input:ro \
  -v /path/to/output:/work/output \
  md2pdf
```

## ライセンス

MIT
