# Web プラットフォームテスト

## 概要

godot-vrt は Web エクスポートした Godot プロジェクトの VRT に対応しています。HTML5
ビルドを必要なヘッダー付きで配信し、Playwright がブラウザでページを読み込みます。
`vrt_runner` がスクリーンショットを撮影し、同一オリジンのローカルサーバーへ
HTTP POST でアップロードします。

## アーキテクチャ

```text
ビルド (godot --headless --export-debug "Web")
  ↓
COOP/COEP ヘッダー + POST 受信付きで配信 (Node.js HTTP サーバー)
  ↓
Playwright が Chromium でページを読み込み
  ↓
Godot vrt_runner がスクリーンショットを撮影
  ↓
vrt_runner が /__vrt_upload/ へ HTTP POST（quit 前に送信）
  ↓
Argos にアップロードして差分比較
```

スクリーンショットの受け渡しに HTTP POST を使うのは、Godot が終了すると
Emscripten の仮想ファイルシステムが破棄され、外部から読み出せなくなるためです。

## テストシーン

`tests/web_ui_test.tscn` はブラウザ風 UI を描画します。ヘッダーバー、レスポンシブ
カードグリッド、プログレスバー、ビューポート情報パネル、Cookie 同意バナーを含みます。

## ストーリー

| ストーリー | ビューポート | スクリプト | 説明 |
| --- | --- | --- | --- |
| default | 1280x720 | - | 標準デスクトップレイアウト |
| loading | 1280x720 | `web_ui_test_capture.vrt.gd` | プログレスバー 65% 状態 |
| mobile_portrait | 393x852 | - | 1 カラムのモバイルレイアウト |
| tablet_landscape | 1024x768 | - | 2 カラムのタブレットレイアウト |

## シーンマニフェスト

エクスポートビルドでは `DirAccess` で `res://` 内の `.tscn` を列挙できないため、
`vrt_runner` は `tests/vrt_scenes.json` からキャプチャ対象シーンを読み込みます。
**シーンを追加したらこのマニフェストにも追記してください。**

```json
{
  "scenes": [
    "res://web_ui_test.tscn",
    "res://android_ui_test.tscn"
  ]
}
```

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

エクスポートは **デバッグモード（`--export-debug`）** を使います。リリースビルド
では `print()` が出力されず、Playwright が完了マーカー `=== Done ===` を検出
できないためです。

## ローカル検証手順

```bash
# 1. Web ビルドをエクスポート
godot --headless --path tests --export-debug "Web" build/web/index.html

# 2. COOP/COEP ヘッダー + アップロード受信付きサーバーを起動
mkdir -p vr_screenshots_web
node -e "
const http = require('http'), fs = require('fs'), path = require('path');
http.createServer((req, res) => {
  res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
  res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
  if (req.method === 'POST' && req.url.startsWith('/__vrt_upload/')) {
    const name = path.basename(decodeURIComponent(req.url.slice('/__vrt_upload/'.length)));
    const chunks = [];
    req.on('data', (c) => chunks.push(c));
    req.on('end', () => {
      fs.writeFileSync(path.join('vr_screenshots_web', name), Buffer.concat(chunks));
      res.writeHead(200); res.end('OK');
    });
    return;
  }
  const file = path.join('tests/build/web', req.url === '/' ? '/index.html' : req.url);
  try { res.end(fs.readFileSync(file)); } catch(e) { res.writeHead(404); res.end(); }
}).listen(8080);
"

# 3. Playwright テストを実行（=== Done === を待つだけ）
npx playwright test --config=playwright.config.js

# 4. vr_screenshots_web/ に PNG が保存される
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
- **デバッグエクスポート必須**: リリースビルドは `print()` を出力しないため、
  完了検出とログ診断ができません。
- **GPU レンダリング**: ヘッドレス Chromium はソフトウェアレンダリング
  (SwiftShader) を使用します。GPU レンダリングとの見た目の差異が発生する可能性が
  あります。
