# AI Shell Switch distribution site

AI Shell Switch の公開配布ページです。GitHubのソースZIPとリポジトリへ案内し、
対応環境・インストール方法・安全上の境界を日本語で説明します。

## Local development

Node.js 22.13以降を使用します。

```sh
npm install
npm run dev
```

## Verification

```sh
npm run build
npm test
npm run lint
npm audit --omit=dev
```

`npm test` は本番Workerを起動せずにサーバーレンダリングし、配布リンク、
対応環境、ソース配布の明示、OGメタデータを検証します。

## Hosting

Sitesのプロジェクト設定は `.openai/hosting.json` に保存します。
本番URLやソース配布先はページ内で動的に生成・参照します。
