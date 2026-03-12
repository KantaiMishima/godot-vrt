# テストランナー: iOS プラットフォーム

## 概要

iOS 向けのテストランナーは、Godot プロジェクトを iOS アプリとしてエクスポートし、シミュレータまたは実機上で動作する。テスト対象のシーン・スクリプトは `.pck` ファイルとして事前にバンドルし、`xcrun simctl` でシミュレータのアプリデータ領域に配置する。ランナーアプリが起動時に PCK をロードして VRT キャプチャを実行し、結果はシミュレータのファイルシステムから直接回収する。

CI では macOS ランナーが必須であり、シミュレータ使用時はコード署名が不要なため手軽に運用できる。

---

## アーキテクチャ

```text
┌─────────────────────────────────────────────────────────────┐
│  ホスト（macOS CI / 開発マシン）                               │
│                                                             │
│  1. godot --headless --export-pack "tests.pck"              │
│  2. godot --headless --export-release "iOS" build/ios/      │
│  3. xcodebuild でシミュレータ用ビルド                          │
│  4. xcrun simctl install でアプリをインストール                 │
│  5. xcrun simctl でアプリデータ領域に PCK を配置               │
│  6. xcrun simctl launch でアプリを起動                        │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  iOS シミュレータ                                      │  │
│  │                                                       │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │  Godot ランナーアプリ                             │  │  │
│  │  │                                                 │  │  │
│  │  │  a. Documents/tests.pck をロード                 │  │  │
│  │  │  b. capture ロジック実行                         │  │  │
│  │  │  c. スクリーンショットを Documents/output/ に保存  │  │  │
│  │  │  d. stdout に "=== Done ===" を出力              │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  7. xcrun simctl get_app_container でパスを取得               │
│  8. スクリーンショットをコピー                                  │
│  9. Argos CI にアップロード                                   │
└─────────────────────────────────────────────────────────────┘
```

---

## PCK 生成

テスト対象のシーンとスクリプトを PCK ファイルにパッケージする。

```bash
# テストプロジェクトから PCK を生成
godot --headless --path tests --export-pack "iOS" tests.pck
```

PCK にはテストプロジェクト内の全リソース（`.tscn`, `.gd`, `.stories.json`, `.vrt.gd`）がプリコンパイル済みで含まれる。

---

## ランナーアプリのビルド

### エクスポートプリセットの設定

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
name="iOS"
platform="iOS"
runnable=true
export_filter="all_resources"

[preset.0.options]
application/bundle_identifier="com.example.vrtrunner"
application/short_version="1.0"
```

### 前提条件

- macOS（Xcode のビルドに必須）
- Xcode（最新の安定版推奨）
- Godot iOS エクスポートテンプレート
- シミュレータ使用時はコード署名不要

### ビルドコマンド

```bash
# Godot から Xcode プロジェクトをエクスポート
godot --headless --path runner --export-release "iOS" build/ios/vrt_runner.xcodeproj

# Xcode でシミュレータ向けビルド
xcodebuild \
    -project build/ios/vrt_runner.xcodeproj \
    -scheme vrt_runner \
    -sdk iphonesimulator \
    -configuration Debug \
    -destination "platform=iOS Simulator,name=iPhone 16" \
    -derivedDataPath build/ios/DerivedData \
    build
```

ビルド成果物は `build/ios/DerivedData/Build/Products/Debug-iphonesimulator/vrt_runner.app` に出力される。

---

## テスト実行フロー

### runner_main.gd の動作

```gdscript
extends SceneTree

const PCK_FILENAME := "tests.pck"
const OUTPUT_SUBDIR := "output"

func _initialize() -> void:
    print("=== VRT iOS Runner ===")

    # 1. PCK をロード（Documents ディレクトリから）
    var docs_dir := OS.get_user_data_dir()
    var pck_path := docs_dir.path_join(PCK_FILENAME)
    var pck_loaded := ProjectSettings.load_resource_pack(pck_path)

    if not pck_loaded:
        printerr("Failed to load test PCK: ", pck_path)
        quit(1)
        return

    # 2. 出力ディレクトリを準備
    var output_dir := docs_dir.path_join(OUTPUT_SUBDIR)
    DirAccess.make_dir_recursive_absolute(output_dir)

    # 3. capture ロジック実行
    await _run_capture(output_dir)

    # 4. 完了通知
    print("=== Done ===")
    quit(0)
```

### アプリのインストールと PCK 配信

```bash
BUNDLE_ID="com.example.vrtrunner"
APP_PATH="build/ios/DerivedData/Build/Products/Debug-iphonesimulator/vrt_runner.app"
SIMULATOR="booted"

# シミュレータを起動（まだ起動していない場合）
xcrun simctl boot "iPhone 16" 2>/dev/null || true

# アプリをインストール
xcrun simctl install ${SIMULATOR} "${APP_PATH}"

# アプリのデータコンテナパスを取得
DATA_DIR=$(xcrun simctl get_app_container ${SIMULATOR} ${BUNDLE_ID} data)

# PCK をアプリの Documents ディレクトリに配置
cp tests.pck "${DATA_DIR}/Documents/tests.pck"

# アプリを起動
xcrun simctl launch --console ${SIMULATOR} ${BUNDLE_ID}
```

### 完了の検知

`xcrun simctl launch --console` はアプリの stdout をターミナルに出力する。完了メッセージを検知する。

```bash
# --console でアプリを起動し、stdout を監視
xcrun simctl launch --console ${SIMULATOR} ${BUNDLE_ID} 2>&1 | while read -r line; do
    echo "$line"
    if echo "$line" | grep -q "=== Done ==="; then
        break
    fi
done
```

---

## スクリーンショットの回収

シミュレータのファイルシステムに直接アクセスしてスクリーンショットを取得する。

```bash
BUNDLE_ID="com.example.vrtrunner"
SIMULATOR="booted"

# アプリのデータコンテナパスを取得
DATA_DIR=$(xcrun simctl get_app_container ${SIMULATOR} ${BUNDLE_ID} data)

# スクリーンショットをコピー
cp -r "${DATA_DIR}/Documents/output/" ./vr_screenshots/

# 後片付け: アプリをアンインストール
xcrun simctl uninstall ${SIMULATOR} ${BUNDLE_ID}
```

---

## CI 統合

### GitHub Actions ワークフロー例

```yaml
name: VRT (iOS)

on:
  push:
    branches: [main]
  pull_request:

jobs:
  vrt-ios:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - name: Download Godot
        run: |
          RELEASE_TAG=$(curl -s "https://api.github.com/repos/godotengine/godot/releases/latest" | jq -r '.tag_name')
          wget -q "https://github.com/godotengine/godot/releases/download/${RELEASE_TAG}/Godot_v${RELEASE_TAG}_macos.universal.zip"
          unzip -q "Godot_v${RELEASE_TAG}_macos.universal.zip"
          mv "Godot.app/Contents/MacOS/Godot" godot
          chmod +x godot

      - name: Download iOS export templates
        run: |
          RELEASE_TAG=$(curl -s "https://api.github.com/repos/godotengine/godot/releases/latest" | jq -r '.tag_name')
          TEMPLATES_DIR=~/Library/Application\ Support/Godot/export_templates/${RELEASE_TAG}
          mkdir -p "${TEMPLATES_DIR}"
          wget -q "https://github.com/godotengine/godot/releases/download/${RELEASE_TAG}/Godot_v${RELEASE_TAG}_export_templates.tpz"
          unzip -q "Godot_v${RELEASE_TAG}_export_templates.tpz" -d /tmp/templates
          cp /tmp/templates/templates/* "${TEMPLATES_DIR}/"

      - name: Build test PCK
        run: ./godot --headless --path tests --export-pack "iOS" tests.pck

      - name: Build runner Xcode project
        run: ./godot --headless --path runner --export-release "iOS" build/ios/vrt_runner.xcodeproj

      - name: Build for simulator
        run: |
          xcodebuild \
              -project build/ios/vrt_runner.xcodeproj \
              -scheme vrt_runner \
              -sdk iphonesimulator \
              -configuration Debug \
              -destination "platform=iOS Simulator,name=iPhone 16" \
              -derivedDataPath build/ios/DerivedData \
              build

      - name: Boot simulator
        run: |
          xcrun simctl boot "iPhone 16" 2>/dev/null || true
          xcrun simctl list devices booted

      - name: Run VRT capture
        run: |
          BUNDLE_ID="com.example.vrtrunner"
          APP_PATH="build/ios/DerivedData/Build/Products/Debug-iphonesimulator/vrt_runner.app"

          xcrun simctl install booted "${APP_PATH}"

          DATA_DIR=$(xcrun simctl get_app_container booted ${BUNDLE_ID} data)
          mkdir -p "${DATA_DIR}/Documents"
          cp tests/tests.pck "${DATA_DIR}/Documents/tests.pck"

          # アプリ起動と完了待機（タイムアウト 120 秒）
          timeout 120 sh -c '
            xcrun simctl launch --console booted '"${BUNDLE_ID}"' 2>&1 | while read -r line; do
              echo "$line"
              if echo "$line" | grep -q "=== Done ==="; then
                break
              fi
            done
          '

          # スクリーンショット回収
          DATA_DIR=$(xcrun simctl get_app_container booted ${BUNDLE_ID} data)
          cp -r "${DATA_DIR}/Documents/output/" ./vr_screenshots/

      - name: Shutdown simulator
        if: always()
        run: xcrun simctl shutdown all

      - uses: actions/setup-node@v4
        with:
          node-version-file: package.json

      - name: Install dependencies
        run: npm ci

      - name: Upload screenshots to Argos
        run: npm exec -- argos upload --token ${{ secrets.ARGOS_TOKEN }} ./vr_screenshots
```

---

## 制約事項

| 項目 | 詳細 |
| --- | --- |
| macOS 必須 | Xcode と iOS シミュレータは macOS でのみ動作する。GitHub Actions の macOS ランナーは Linux の約 10 倍のコスト |
| レンダリング差異 | シミュレータ（Apple GPU シミュレーション）と実機（Apple GPU ネイティブ）で Metal レンダリング結果が異なる場合がある |
| コード署名 | シミュレータ向けビルドでは不要。実機テストには Apple Developer アカウントと Provisioning Profile が必要 |
| GDScript コンパイル | エクスポート時にプリコンパイルされるため、実行時の動的コンパイルは不可。PCK で事前にパッケージする必要がある |
| サンドボックス | iOS アプリはサンドボックス内で動作する。ファイルの読み書きはアプリの Documents ディレクトリに限定される |
| シミュレータ制限 | iOS シミュレータは x86_64 / arm64 アーキテクチャに対応。GitHub Actions の macOS ランナーは Apple Silicon（arm64） |
| Xcode バージョン | GitHub Actions の macOS ランナーにプリインストールされている Xcode バージョンに依存する。`xcodes` や `xcode-select` で制御可能 |
