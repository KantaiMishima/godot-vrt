# iOS プラットフォームテスト

## 概要

godot-vrt は iOS 向け VRT のリファレンス実装を含んでいます。Godot プロジェクトを
Xcode プロジェクトとしてエクスポートし、`xcodebuild` で iOS Simulator 向けにビルド、
`simctl` でインストールしてスクリーンショットを取得します。有効な Apple Developer
Team ID が必要なため、現在は無効化されています。

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

`tests/ios_ui_test.tscn`（`ios_ui_test.stories.json` から参照）は iOS 風 UI を描画
します。Dynamic Island、ラージタイトルナビゲーション、リスト、タブバー、ホーム
インジケーターを含みます。

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

有効化前に `PLACEHOLDER` を実際の Apple Developer Team ID に置き換えてください。

## ローカル検証手順（macOS のみ）

```bash
# 1. エクスポートとビルド
mkdir -p tests/build/ios
godot --headless --path tests --export-release "iOS" build/ios/
xcodebuild -project tests/build/ios/vrt-tests.xcodeproj -scheme vrt-tests \
  -destination 'platform=iOS Simulator,name=iPhone 15' -configuration Release \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build

# 2. Simulator にインストールして実行
xcrun simctl boot "iPhone 15"
APP_PATH=$(find tests/build/ios/Build -name "*.app" -type d | head -1)
xcrun simctl install booted "$APP_PATH"
xcrun simctl launch booted com.godot.vrt.tests

# 3. スクリーンショットを取得
APP_DATA=$(xcrun simctl get_app_container booted com.godot.vrt.tests data)
mkdir -p vr_screenshots_ios
find "$APP_DATA" -name "*.png" -path "*/vr_screenshots/*" -exec cp {} ./vr_screenshots_ios/ \;
```

## 現在のステータスと CI ワークフロー

CI で**無効化**されています（`vrt-ios.yml` に `if: false`）。有効化するには
`tests/export_presets.cfg` に実際の Apple Developer Team ID を設定し `if: false` を
削除します。ワークフロー（`vrt-ios.yml`、`vrt.yml` から呼出）は `macos-latest` で実行。

## 制限事項

- **Apple Developer Team ID**: Simulator ビルドにも有効な Team ID が必要な場合がある。
- **macOS 専用**: iOS Simulator は macOS ランナーでのみ利用可能（CI コスト高）。
- **Simulator と実機の差異**: Metal シェーダーや GPU エフェクトで描画差異が出やすい。
