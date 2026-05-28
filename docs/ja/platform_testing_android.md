# Android プラットフォームテスト

## 概要

godot-vrt は Android にエクスポートした Godot プロジェクトのビジュアルリグレッションテストに対応しています。
デバッグ APK をビルドし、Android エミュレーターにインストールして、Godot の
`vrt_runner` が `user://` にスクリーンショットを保存します。その後 `adb run-as` で
ファイルを取り出し、Argos にアップロードします。

## アーキテクチャ

```text
APK ビルド (godot --headless --export-debug "Android")
  ↓
Android エミュレーター起動 (API 31, google_apis, x86_64)
  ↓
adb で APK をインストール
  ↓
Godot vrt_runner が user://vr_screenshots/ にスクリーンショットを保存
  ↓
adb exec-out run-as com.godot.vrt.tests cat ... で PNG を取得
  ↓
Argos にアップロードして差分比較
```

## テストシーン

`tests/android_ui_test.tscn` は Material Design 風の UI を描画します。時刻とバッテリー
表示付きのステータスバー、ハンバーガーメニュー付きアプリバー、アイコンとサブタイトル
付きのカードリスト、フローティングアクションボタン（FAB）、ボトムナビゲーションバー、
ノッチ表示エリアを含みます。

## ストーリー

| ストーリー | ビューポート | スクリプト | 説明 |
| --- | --- | --- | --- |
| default | 412x915 | - | 標準スマートフォン縦向き |
| with_notch | 412x915 | `android_ui_test_capture.vrt.gd` | ノッチオーバーレイ表示 |
| landscape | 915x412 | - | 横向き |
| tablet | 800x1280 | - | タブレット縦向き |

## 前提条件

- Godot 4.5+ と Android エクスポートテンプレート
- Android SDK（API 34+ ビルドツール、API 31 システムイメージ）
- Java JDK 17+
- デバッグキーストア（`~/.android/debug.keystore`）

## エクスポート設定

エクスポート設定は `tests/export_presets.cfg`（プリセット `Android`）に定義されています。

```text
package/unique_name = "com.godot.vrt.tests"
package/name        = "godot-vrt tests"
export_path         = "build/android/vrt-tests.apk"
```

デバッグモード（`--export-debug`）でエクスポートし、エクスポートテンプレート経由で
ETC2/ASTC テクスチャ圧縮が有効になります。

## ローカル検証手順

```bash
# 1. APK をエクスポート
mkdir -p tests/build/android
godot --headless --path tests --export-debug "Android" build/android/vrt-tests.apk

# 2. エミュレーターを起動してインストール
emulator -avd Pixel_6_API_31 -no-window -no-audio &
adb wait-for-device
adb install tests/build/android/vrt-tests.apk

# 3. アプリを起動して完了を待機
adb shell monkey -p com.godot.vrt.tests -c android.intent.category.LAUNCHER 1
adb logcat -s godot | grep -m1 "=== Done ==="

# 4. スクリーンショットを取得
mkdir -p vr_screenshots_android
adb shell run-as com.godot.vrt.tests ls files/vr_screenshots/ | while read f; do
  adb exec-out run-as com.godot.vrt.tests cat "files/vr_screenshots/$f" \
    > "vr_screenshots_android/$f"
done
```

## CI ワークフロー

ワークフローは `.github/workflows/vrt-android.yml` に定義されており、
オーケストレーター `.github/workflows/vrt.yml` から呼び出されます。
Java 17 と Android SDK のセットアップ、デバッグキーストアの作成、APK のエクスポート、
KVM の有効化、Pixel 6 プロファイルでのエミュレーター実行、スクリーンショットの取得、
`vrt-screenshots-android` アーティファクトとしてのアップロードを行います。

## 制限事項

- **システムイメージ**: x86_64 エミュレーターでの ARM トランスレーションには
  `google_apis` システムイメージが必要です。`default` イメージではネイティブ
  ライブラリがクラッシュする場合があります。
- **KVM**: Ubuntu CI ランナーではエミュレーターの十分なパフォーマンスを得るために
  KVM の有効化が必要です。ワークフローでは udev ルールを設定して KVM アクセスを
  許可しています。
- **エミュレーター起動時間**: コールドブートには 60-120 秒かかります。ワークフローでは
  300 秒のタイムアウトを設定して低速な起動に対応しています。
- **スクリーンショット取得**: `adb run-as` はデバッグビルドの APK でのみ動作します。
  リリースビルドではファイルシステムへのアクセスが制限されます。
