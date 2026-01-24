# CLAUDE.md

このファイルはClaude Codeがこのリポジトリで作業する際のガイドラインを提供します。

## 言語

- Claude Codeは常に**日本語**で応答する（ユーザーが英語で話しかけても日本語で返す）

## コミット・PR規約

- **mainブランチへの直接プッシュは禁止**（必ずPRを作成する）
- PRのタイトルと説明は**日本語**で記述する
- コミットメッセージは英語でも日本語でも可

## プロジェクト概要

このリポジトリは、MarkdownをPDFに変換するReusable GitHub Actions Workflowを提供します。

### 主要ファイル

- `scripts/md2pdf.sh` - PDF変換のメインスクリプト
- `scripts/Dockerfile` - Docker環境の定義
- `scripts/header.tex` - LaTeXのカスタムヘッダー（日本語フォント設定）
- `.github/workflows/reusable-pdf.yml` - 他リポジトリから呼び出されるReusable Workflow

### 機能

- 日本語フォント対応（Noto CJKフォント）
- Mermaidダイアグラムの自動変換
- 目次の自動生成
- GitHub Releaseへの自動公開（オプション）
