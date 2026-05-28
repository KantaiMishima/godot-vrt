# Web プラットフォームテスト

## 概要

godot-vrt は Web プラットフォームにエクスポートした Godot プロジェクトのビジュアルリグレッションテストに対応しています。
プロジェクトを HTML5 ビルドとしてエクスポートし、必要なヘッダー付きで配信した上で、
Playwright が実ブラウザ上でページを読み込みます。Godot の `vrt_runner` が Emscripten
仮想ファイルシステム内にスクリーンショットを保存し、Playwright がそれを取り出して
Argos にアップロードします。

## アーキテクチャ

```text
ビルド (godot --headless --export-release "Web")
  ↓
COOP/COEP ヘッダー付きで配信 (Node.js HTTP サーバー)
  ↓
Playwright が Chromium でページを読み込み
  ↓
Godot vrt_runner が Emscripten FS 内にスクリーンショットを保存
  ↓
Playwright が Emscripten 仮想 FS から PNG を取得
  ↓
Argos にアップロードして差分比較
```

## テストシーン

`tests/web_ui_test.tscn` はブラウザ風の UI を描画します。ナビゲーションボタンと
URL フィールドを備えたヘッダーバー、レスポンシブなカードグリッド、ローディング
プログレスバー、ビューポート情報パネル、Cookie 同意バナーを含みます。

## ストーリー

| ストーリー | ビューポート | スクリプト | 説明 |
| --- | --- | --- | --- |
| default | 1280x720 | - | 標準デスクトップレイアウト |
| loading | 1280x720 | `web_ui_test_capture.vrt.gd` | プログレスバー 65% 状態 |
| mobile_portrait | 393x852 | - | 1 カラムのモバイルレイアウト |
| tablet_landscape | 1024x768 | - | 2 カラムのタブレットレイアウト |

## 前提条件

- Godot 4.5+ と Web エクスポートテンプレート
- Node.js（`package.json` で指定されたバージョン）
- Playwright（`npx playwright install chromium`）

## エクスポート設定

エクスポート設定は `tests/export_presets.cfg`（プリセット `Web`）に定義されています。

```text
export_path = "build/web/index.html"
export_filter = "all_resources"
```

## ローカル検証手順

```bash
# 1. Web ビルドをエクスポート
godot --headless --path tests --export-release "Web" build/web/index.html

# 2. 必要なヘッダー付きでローカルサーバーを起動
node -e "
const http = require('http'), fs = require('fs'), path = require('path');
http.createServer((req, res) => {
  const file = path.join('tests/build/web', req.url === '/' ? '/index.html' : req.url);
  res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
  res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
  try { res.end(fs.readFileSync(file)); } catch(e) { res.writeHead(404); res.end(); }
}).listen(8080);
"

# 3. Playwright テストを実行
npx playwright test --config=playwright.config.js
```

## CI ワークフロー

ワークフローは `.github/workflows/vrt-web.yml` に定義されており、
`.github/workflows/vrt.yml` から呼び出されます。Godot とエクスポートテンプレートの
ダウンロード、Web ビルドのエクスポート、Playwright のインストール、スクリーンショット
撮影、`vrt-screenshots-web` アーティファクトとしてのアップロードを行います。

## 制限事項

- **SharedArrayBuffer**: Godot の Web ビルドは `SharedArrayBuffer` を必要とし、
  `Cross-Origin-Opener-Policy: same-origin` と
  `Cross-Origin-Embedder-Policy: require-corp` の両ヘッダーが必要です。
- **Emscripten FS アクセス**: 仮想ファイルシステムからのファイル取得は Godot の
  バージョンによって異なる場合があります。
- **GPU レンダリング**: ヘッドレス Chromium はソフトウェアレンダリングを使用します。
  GPU レンダリングとの見た目の差異が発生する可能性があります。
