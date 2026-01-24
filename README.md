# md2pdf

Markdown を PDF に変換する GitHub Action です。

## 特徴

- 日本語フォント対応（Noto CJK フォント）
- Mermaid ダイアグラムの自動変換
- 目次の自動生成

## 使い方

```yaml
- uses: linkbal/md2pdf@v1
  with:
    input_dir: 'docs'
    output_dir: 'output'
```

### 入力パラメータ

| パラメータ | 説明 | デフォルト |
|-----------|------|-----------|
| `input_dir` | Markdownファイルのディレクトリ | `docs` |
| `output_dir` | PDF出力ディレクトリ | `output` |

### 完全な例

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
          output_dir: 'output'

      - uses: actions/upload-artifact@v4
        with:
          name: pdf-output
          path: output/**/*.pdf
```

### GitHub Release 付きの例

```yaml
name: Generate PDF and Release

on:
  push:
    branches: [main]
    paths: ['docs/**']

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

      - name: タグを作成
        id: tag
        run: |
          TAG="v$(date +'%Y%m%d')-${GITHUB_SHA::7}"
          echo "name=$TAG" >> $GITHUB_OUTPUT
          git tag $TAG && git push origin $TAG

      - uses: softprops/action-gh-release@v2
        with:
          tag_name: ${{ steps.tag.outputs.name }}
          files: output/**/*.pdf
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
