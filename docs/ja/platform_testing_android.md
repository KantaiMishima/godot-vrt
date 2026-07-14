# Android プラットフォームテスト

## 概要

godot-vrt は Android エクスポートした Godot プロジェクトの VRT に対応しています。
デバッグ APK をビルドしてエミュレーターにインストールし、`vrt_runner` が `user://`
にスクリーンショットを保存、`adb run-as` で取り出して Argos にアップロードします。

## アーキテクチャ

```text
APK ビルド (godot --headless --export-debug "Android")
  ↓
Xvfb 起動 → Android エミュレーター起動 (API 31, aosp_atd, x86_64, -gpu host)
  ↓
adb で APK をインストール
  ↓
Godot vrt_runner が user://vr_screenshots/ にスクリーンショットを保存
  ↓
adb exec-out run-as com.godot.vrt.tests cat ... で PNG を取得
  ↓
Argos にアップロードして差分比較
```

## レンダリング構成（重要）

CI エミュレーターで正しく描画するために、以下の3点が必要です。

1. **`-gpu host` + Xvfb**: エミュレーター内蔵の SwiftShader (GLES translator) は
   uniform 数の上限が低く、Godot 4 の 2D キャンバスシェーダーがリンクに失敗して
   **全描画が無効化され、画面全体がクリアカラー（灰色）になります**。
   `-gpu host` でホスト側 Mesa llvmpipe (GL 4.5) を使うことで回避します。
   `-gpu host` には X ディスプレイが必要なため、CI では Xvfb を起動します。
2. **`gl_compatibility` レンダラー**: `tests/project.godot` の
   `renderer/rendering_method.mobile="gl_compatibility"`。エミュレーターの
   ソフトウェア Vulkan は present に失敗しアプリがハングするためです。
3. **x86_64 バイナリを APK に含める**: `architectures/x86_64=true`。
   x86_64 エミュレーター上でネイティブ実行され、ARM バイナリ変換による
   低速化と不安定さを避けられます。

## テストシーン

`tests/android_ui_test.tscn` は Material Design 風 UI を描画します。ステータスバー、
アプリバー、カードリスト、FAB、ボトムナビゲーション、ノッチ表示エリアを含みます。

## ストーリー

| ストーリー | ビューポート | スクリプト | 説明 |
| --- | --- | --- | --- |
| default | 412x915 | - | 標準スマートフォン縦向き |
| with_notch | 412x915 | `android_ui_test_capture.vrt.gd` | ノッチオーバーレイ表示 |
| landscape | 915x412 | - | 横向き |
| tablet | 800x1280 | - | タブレット縦向き |

## シーンマニフェスト

エクスポートビルドでは `DirAccess` で `res://` 内の `.tscn` を列挙できないため、
`vrt_runner` は `tests/vrt_scenes.json` からキャプチャ対象シーンを読み込みます。
**シーンを追加したらこのマニフェストにも追記してください。**

## 前提条件

- Godot 4.5+ と Android エクスポートテンプレート
- Android SDK（API 34+ ビルドツール、API 31 `aosp_atd` システムイメージ）、
  Java JDK 17+
- デバッグキーストア（`~/.android/debug.keystore`）

## エクスポート設定

エクスポート設定は `tests/export_presets.cfg`（プリセット `Android`）に定義されています。

```text
package/unique_name        = "com.godot.vrt.tests"
package/name               = "godot-vrt tests"
export_path                = "build/android/vrt-tests.apk"
architectures/arm64-v8a    = true
architectures/x86_64       = true
```

デバッグモード（`--export-debug`）で ETC2/ASTC テクスチャ圧縮付きのエクスポートです
（`adb run-as` での取り出しにはデバッグビルドが必須）。

## ローカル検証手順

GPU のある開発マシンではエミュレーターのデフォルト GPU 設定で問題ありません。
ヘッドレス環境（GPU なし）では CI と同様に Xvfb + `-gpu host` を使ってください。

```bash
# 1. APK をエクスポート
mkdir -p tests/build/android
godot --headless --path tests --export-debug "Android" build/android/vrt-tests.apk

# 2. エミュレーターを起動してインストール
emulator -avd Pixel_6_API_31 -no-audio &
adb wait-for-device
adb install tests/build/android/vrt-tests.apk

# 3. アプリを起動して完了を待機
adb shell monkey -p com.godot.vrt.tests -c android.intent.category.LAUNCHER 1
adb logcat -s godot | grep -m1 "=== Done ==="

# 4. スクリーンショットを取得
mkdir -p vr_screenshots_android
adb shell run-as com.godot.vrt.tests ls files/vr_screenshots/ | tr -d '\r' | while read f; do
  adb exec-out run-as com.godot.vrt.tests cat "files/vr_screenshots/$f" \
    > "vr_screenshots_android/$f"
done
```

## CI ワークフロー

`.github/workflows/vrt-android.yml`（`vrt.yml` から呼出）に定義されています。
Java 17・Android SDK セットアップ、デバッグキーストア作成、APK エクスポート、KVM
有効化、Xvfb 起動、Pixel 6 エミュレーター実行（`-gpu host`）、
`vrt-screenshots-android` アップロードを行います。

## 制限事項

- **エミュレーター GPU**: `-gpu host` なし（内蔵 SwiftShader）では Godot 4 の
  シェーダーがリンクできず、スクリーンショットが灰色一色になります。
- **KVM**: Ubuntu CI ランナーではエミュレーターのために KVM の有効化が必要です。
- **エミュレーター起動時間**: コールドブートに 60-120 秒。タイムアウトは 300 秒。
- **スクリーンショット取得**: `adb run-as` はデバッグビルドでのみ動作します。
