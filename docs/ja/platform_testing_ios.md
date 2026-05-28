# iOS プラットフォームテスト

## 概要

godot-vrt は iOS でのビジュアルリグレッションテストのリファレンス実装を含んでいます。
Godot プロジェクトを Xcode プロジェクトとしてエクスポートし、`xcodebuild` で iOS
Simulator 向けにビルドし、`simctl` でアプリをインストールしてスクリーンショットを
アプリサンドボックスから取得します。このワークフローは有効な Apple Developer Team ID
が必要なため、現在は無効化されています。

## アーキテクチャ

```text
Xcode プロジェクトをエクスポート (godot --headless --export-release "iOS")
  ↓
Simulator 向けにビルド (xcodebuild -destination 'iOS Simulator')
  ↓
Simulator を起動して xcrun simctl でインストール
  ↓
Godot vrt_runner がアプリサンドボックスにスクリーンショットを保存
  ↓
simctl get_app_container でサンドボックスから PNG を取得
  ↓
Argos にアップロードして差分比較
```

## テストシーン

`tests/ios_ui_test.tscn`（`ios_ui_test.stories.json` から参照）は iOS 風の UI を
描画します。Dynamic Island エリア、ラージタイトルナビゲーションバー、セパレーター
付きスクロールリスト、アイコン付きタブバー、ホームインジケーターを含みます。

## ストーリー

| ストーリー | ビューポート | スクリプト | 説明 |
| --- | --- | --- | --- |
| iphone_notch | 390x844 | - | ノッチ付き iPhone |
| iphone_dynamic_island | 393x852 | `ios_ui_test_capture.vrt.gd` | Dynamic Island スタイル |
| iphone_dark | 393x852 | `ios_ui_test_dark_capture.vrt.gd` | ダークモード |
| ipad | 1024x1366 | - | iPad 縦向き |

## 前提条件

- macOS と Xcode
- Godot 4.5+ と iOS エクスポートテンプレート
- iOS Simulator ランタイム（Xcode に同梱）

## エクスポート設定

エクスポート設定は `tests/export_presets.cfg`（プリセット `iOS`）に定義されています。

```text
application/app_store_team_id  = "PLACEHOLDER"
application/bundle_identifier  = "com.godot.vrt.tests"
application/min_ios_version    = "15.0"
export_path                    = "build/ios/"
```

`app_store_team_id` は `PLACEHOLDER` に設定されています。ワークフローを有効にする前に
実際の Apple Developer Team ID に置き換えてください。

## ローカル検証手順（macOS のみ）

```bash
# 1. Xcode プロジェクトをエクスポート
mkdir -p tests/build/ios
godot --headless --path tests --export-release "iOS" build/ios/

# 2. Simulator 向けにビルド（コード署名無効）
xcodebuild -project tests/build/ios/vrt-tests.xcodeproj \
  -scheme vrt-tests \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -configuration Release \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  build

# 3. Simulator を起動してインストール
xcrun simctl boot "iPhone 15"
APP_PATH=$(find tests/build/ios/Build -name "*.app" -type d | head -1)
xcrun simctl install booted "$APP_PATH"
xcrun simctl launch booted com.godot.vrt.tests

# 4. アプリサンドボックスからスクリーンショットを取得
APP_DATA=$(xcrun simctl get_app_container booted com.godot.vrt.tests data)
mkdir -p vr_screenshots_ios
find "$APP_DATA" -name "*.png" -path "*/vr_screenshots/*" -exec cp {} ./vr_screenshots_ios/ \;
```

## 現在のステータス

このワークフローは CI で**無効化**されています。`vrt-ios.yml` のジョブに `if: false`
が設定されています。有効化するには: (1) `tests/export_presets.cfg` に実際の Apple
Developer Team ID を設定、(2) `.github/workflows/vrt-ios.yml` から `if: false` を削除。

## CI ワークフロー

ワークフローは `.github/workflows/vrt-ios.yml` に定義されており、
`.github/workflows/vrt.yml` から呼び出されます。`macos-latest` で実行され、
macOS 用 Godot のダウンロード、Xcode プロジェクトのエクスポート、Simulator 向け
ビルド、アプリの実行、`vrt-screenshots-ios` アーティファクトのアップロードを行います。

## 制限事項

- **Apple Developer Team ID**: 一部の Godot エクスポート設定では Simulator ビルドにも
  有効な Team ID が必要です。未設定の場合、エクスポートが失敗する可能性があります。
- **macOS 専用**: iOS Simulator は macOS ランナーでのみ利用可能です。CI の macOS
  ランナーはプロビジョニングが遅く、コストも高くなります。
- **Simulator と実機の差異**: レンダリングは実機と異なる場合があります。特に GPU
  アクセラレーションされたエフェクトや Metal シェーダーで差異が出やすいです。
