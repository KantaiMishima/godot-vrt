# テストランナー: Web プラットフォーム

## 概要

Web（HTML5/WebAssembly）向けのテストランナーは、Godot プロジェクトを Web エクスポートしたアプリとしてブラウザ上で動作する。テスト対象のシーン・スクリプトは `.pck` ファイルとして事前にバンドルし、ランナーアプリが起動時にロードして VRT キャプチャを実行する。

スクリーンショットの回収には `JavaScriptBridge` を使い、ブラウザ側の JavaScript と連携して Base64 エンコードされた PNG をホストに送信する。CI では Playwright を用いてブラウザを自動制御する。

---

## アーキテクチャ

```text
┌─────────────────────────────────────────────────────────┐
│  ホスト（CI / 開発マシン）                                │
│                                                         │
│  1. godot --headless --export-pack "tests.pck"          │
│  2. godot --headless --export-preset "Web"              │
│  3. HTTP サーバー起動（tests.pck を配信）                  │
│  4. Playwright でブラウザを起動                            │
│                                                         │
│  ┌───────────────────────────────────────────────────┐  │
│  │  ブラウザ（Chrome / Firefox）                      │  │
│  │                                                   │  │
│  │  ┌─────────────────────────────────────────────┐  │  │
│  │  │  Godot WebAssembly ランナー                  │  │  │
│  │  │                                             │  │  │
│  │  │  a. tests.pck を fetch & ロード              │  │  │
│  │  │  b. capture ロジック実行                     │  │  │
│  │  │  c. スクリーンショットを JS 側に送信          │  │  │
│  │  └─────────────────────────────────────────────┘  │  │
│  │                                                   │  │
│  │  JS: Base64 PNG を受信 → ダウンロード or 転送     │  │
│  └───────────────────────────────────────────────────┘  │
│                                                         │
│  5. スクリーンショットを収集                               │
│  6. Argos CI にアップロード                               │
└─────────────────────────────────────────────────────────┘
```

---

## PCK 生成

テスト対象のシーンとスクリプトを PCK ファイルにパッケージする。Godot の `--export-pack` オプションを使用する。

```bash
# テストプロジェクトから PCK を生成
godot --headless --path tests --export-pack "Web" tests.pck
```

PCK にはテストプロジェクト内の全リソース（`.tscn`, `.gd`, `.stories.json`, `.vrt.gd`）が含まれる。capture.gd のロジックはランナーアプリ側に組み込む。

---

## ランナーアプリのビルド

### エクスポートプリセットの設定

ランナー用の Godot プロジェクトを作成し、Web エクスポートプリセットを設定する。

```text
runner/
├── project.godot
├── export_presets.cfg
├── runner_main.gd        ← エントリポイント（capture ロジック内蔵）
└── runner_main.tscn
```

`export_presets.cfg` の主要設定:

```ini
[preset.0]
name="Web"
platform="Web"
runnable=true
export_filter="all_resources"

[preset.0.options]
html/canvas_resize_policy=0
html/experimental_virtual_keyboard=false
```

### ビルドコマンド

```bash
# Web エクスポート（HTML + WASM + JS）
godot --headless --path runner --export-release "Web" build/web/index.html
```

出力:

```text
build/web/
├── index.html
├── index.js
├── index.wasm
├── index.pck
└── index.audio.worklet.js
```

---

## テスト実行フロー

### runner_main.gd の動作

```gdscript
extends SceneTree

func _initialize() -> void:
    # 1. PCK をロード
    var pck_loaded := ProjectSettings.load_resource_pack("res://tests.pck")
    if not pck_loaded:
        # Web の場合、user:// パスも試行
        pck_loaded = ProjectSettings.load_resource_pack("user://tests.pck")

    if not pck_loaded:
        printerr("Failed to load test PCK")
        _notify_completion(false)
        quit(1)
        return

    # 2. 既存の capture ロジックを実行
    #    （capture.gd の _capture_scene 等を内蔵または呼び出し）
    await _run_capture()

    # 3. 完了を JavaScript 側に通知
    _notify_completion(true)
    quit(0)
```

### PCK の配信方法

Web プラットフォームでは、PCK ファイルを HTTP 経由でブラウザに配信する。Godot の Emscripten FS API を使ってランナー起動前に仮想ファイルシステムへ注入する方法と、ランナー内部から `HTTPRequest` で fetch する方法がある。

**方法 A: Emscripten FS 事前注入（推奨）**

```javascript
// index.html のカスタムスクリプト
async function injectTestPck() {
    const response = await fetch('/tests.pck');
    const buffer = await response.arrayBuffer();
    const data = new Uint8Array(buffer);

    // Emscripten FS にファイルを書き込み
    FS.writeFile('/userfs/tests.pck', data);
}

// Godot エンジン初期化前に実行
await injectTestPck();
```

**方法 B: HTTPRequest による fetch**

```gdscript
var http := HTTPRequest.new()
add_child(http)
http.request("http://localhost:8080/tests.pck")
var result := await http.request_completed
# result からデータを取得し user:// に保存
```

---

## スクリーンショットの回収

### JavaScriptBridge 経由の送信

Godot 4.x の `JavaScriptBridge` を使い、キャプチャした画像を JavaScript 側に送信する。

```gdscript
## スクリーンショットを Base64 エンコードして JS に送信
func _send_screenshot_to_js(img: Image, file_name: String) -> void:
    var png_bytes := img.save_png_to_buffer()
    var base64 := Marshalls.raw_to_base64(png_bytes)
    JavaScriptBridge.eval(
        "window._vrtReceiveScreenshot('%s', '%s')" % [file_name, base64]
    )
```

### JavaScript 側の受信

```javascript
// ブラウザ側でスクリーンショットを収集
window._vrtScreenshots = {};

window._vrtReceiveScreenshot = function(fileName, base64Data) {
    window._vrtScreenshots[fileName] = base64Data;
};

window._vrtComplete = false;
window._vrtNotifyCompletion = function(success) {
    window._vrtComplete = true;
    window._vrtSuccess = success;
};
```

### Playwright による収集

```javascript
const { chromium } = require('playwright');

const browser = await chromium.launch();
const page = await browser.newPage();
await page.goto('http://localhost:8080/');

// 完了を待機
await page.waitForFunction(() => window._vrtComplete, { timeout: 120000 });

// スクリーンショットを取得してファイルに保存
const screenshots = await page.evaluate(() => window._vrtScreenshots);
for (const [fileName, base64Data] of Object.entries(screenshots)) {
    const buffer = Buffer.from(base64Data, 'base64');
    fs.writeFileSync(`vr_screenshots/${fileName}`, buffer);
}

await browser.close();
```

---

## CI 統合

### GitHub Actions ワークフロー例

```yaml
name: VRT (Web)

on:
  push:
    branches: [main]
  pull_request:

jobs:
  vrt-web:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Download Godot
        run: |
          RELEASE_TAG=$(curl -s "https://api.github.com/repos/godotengine/godot/releases/latest" | jq -r '.tag_name')
          wget -q "https://github.com/godotengine/godot/releases/download/${RELEASE_TAG}/Godot_v${RELEASE_TAG}_linux.x86_64.zip"
          unzip -q "Godot_v${RELEASE_TAG}_linux.x86_64.zip"
          mv "Godot_v${RELEASE_TAG}_linux.x86_64" godot
          chmod +x godot

      - name: Download Web export templates
        run: |
          RELEASE_TAG=$(curl -s "https://api.github.com/repos/godotengine/godot/releases/latest" | jq -r '.tag_name')
          mkdir -p ~/.local/share/godot/export_templates/${RELEASE_TAG}/
          wget -q "https://github.com/godotengine/godot/releases/download/${RELEASE_TAG}/Godot_v${RELEASE_TAG}_web_template.zip"
          unzip -q "Godot_v${RELEASE_TAG}_web_template.zip" -d ~/.local/share/godot/export_templates/${RELEASE_TAG}/

      - name: Build test PCK
        run: ./godot --headless --path tests --export-pack "Web" tests.pck

      - name: Build runner
        run: ./godot --headless --path runner --export-release "Web" build/web/index.html

      - name: Copy PCK to build
        run: cp tests/tests.pck build/web/

      - uses: actions/setup-node@v4
        with:
          node-version-file: package.json

      - name: Install dependencies
        run: npm ci

      - name: Run VRT capture
        run: |
          npx serve build/web -p 8080 &
          npx playwright install chromium
          node scripts/capture_web.js

      - name: Upload screenshots to Argos
        run: npm exec -- argos upload --token ${{ secrets.ARGOS_TOKEN }} ./vr_screenshots
```

---

## 制約事項

| 項目 | 詳細 |
| --- | --- |
| レンダリング差異 | WebGL (GLES3) のレンダリング結果はデスクトップ OpenGL/Vulkan/Metal と異なる場合がある。Web 専用のベースライン画像が必要 |
| ファイルシステム | ブラウザの仮想 FS のみ使用可能。ローカルディスクへの直接書き込みは不可 |
| GDScript コンパイル | エクスポート時にプリコンパイルされるため、実行時の動的コンパイルは不可。PCK で事前にパッケージする必要がある |
| パフォーマンス | WebAssembly はネイティブより遅い。タイムアウト値に余裕を持たせる |
| ブラウザ依存 | Chrome / Firefox / Safari で描画結果が異なる可能性がある。CI では単一ブラウザに固定推奨 |
| SharedArrayBuffer | マルチスレッド機能に必要。サーバー側で `Cross-Origin-Opener-Policy` と `Cross-Origin-Embedder-Policy` ヘッダーの設定が必要 |
