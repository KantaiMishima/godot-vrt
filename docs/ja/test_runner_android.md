# テストランナー: Android プラットフォーム

## 概要

Android 向けのテストランナーは、Godot プロジェクトを APK としてエクスポートしたアプリで、エミュレータまたは実機上で動作する。テスト対象のシーン・スクリプトは `.pck` ファイルとして事前にバンドルし、`adb push` で端末に転送する。ランナーアプリが起動時に PCK をロードして VRT キャプチャを実行し、結果は `adb pull` で回収する。

---

## アーキテクチャ

```text
┌──────────────────────────────────────────────────────────┐
│  ホスト（CI / 開発マシン）                                 │
│                                                          │
│  1. godot --headless --export-pack "tests.pck"           │
│  2. godot --headless --export-release "Android" runner.apk│
│  3. adb install runner.apk                               │
│  4. adb push tests.pck /sdcard/Android/data/{pkg}/files/ │
│  5. adb shell am start -n {pkg}/.GodotApp                │
│                                                          │
│  ┌────────────────────────────────────────────────────┐  │
│  │  Android エミュレータ / 実機                        │  │
│  │                                                    │  │
│  │  ┌──────────────────────────────────────────────┐  │  │
│  │  │  Godot ランナーアプリ（APK）                  │  │  │
│  │  │                                              │  │  │
│  │  │  a. /files/tests.pck をロード                 │  │  │
│  │  │  b. capture ロジック実行                      │  │  │
│  │  │  c. スクリーンショットを /files/output/ に保存  │  │  │
│  │  │  d. logcat に "=== Done ===" を出力           │  │  │
│  │  └──────────────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────┘  │
│                                                          │
│  6. adb logcat で完了を検知                                │
│  7. adb pull /sdcard/Android/data/{pkg}/files/output/    │
│  8. Argos CI にアップロード                                │
└──────────────────────────────────────────────────────────┘
```

---

## PCK 生成

テスト対象のシーンとスクリプトを PCK ファイルにパッケージする。

```bash
# テストプロジェクトから PCK を生成
godot --headless --path tests --export-pack "Android" tests.pck
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
name="Android"
platform="Android"
runnable=true
export_filter="all_resources"

[preset.0.options]
package/unique_name="com.example.vrtrunner"
permissions/storage=true
```

### 前提条件

- Android SDK（API レベル 33 以上推奨）
- Android NDK
- Godot Android エクスポートテンプレート
- `ANDROID_HOME` 環境変数の設定

### ビルドコマンド

```bash
# debug APK をビルド（CI ではリリースビルド不要）
godot --headless --path runner --export-debug "Android" build/android/runner.apk
```

---

## テスト実行フロー

### runner_main.gd の動作

```gdscript
extends SceneTree

const PKG_DATA_DIR := "user://"
const PCK_FILENAME := "tests.pck"
const OUTPUT_SUBDIR := "output"

func _initialize() -> void:
    print("=== VRT Android Runner ===")

    # 1. PCK をロード
    var pck_path := PKG_DATA_DIR.path_join(PCK_FILENAME)
    var pck_loaded := ProjectSettings.load_resource_pack(pck_path)

    if not pck_loaded:
        # OS.get_user_data_dir() でフルパスを試行
        var full_path := OS.get_user_data_dir().path_join(PCK_FILENAME)
        pck_loaded = ProjectSettings.load_resource_pack(full_path)

    if not pck_loaded:
        printerr("Failed to load test PCK")
        quit(1)
        return

    # 2. 出力ディレクトリを準備
    var output_dir := OS.get_user_data_dir().path_join(OUTPUT_SUBDIR)
    DirAccess.make_dir_recursive_absolute(output_dir)

    # 3. capture ロジック実行（capture.gd の主要処理を内蔵）
    await _run_capture(output_dir)

    # 4. 完了通知（logcat に出力）
    print("=== Done ===")
    quit(0)
```

### PCK の配信

`adb` を使って PCK ファイルをアプリのデータディレクトリに転送する。

```bash
PKG="com.example.vrtrunner"

# APK をインストール
adb install -r build/android/runner.apk

# PCK をアプリデータ領域に転送
adb push tests.pck /sdcard/Android/data/${PKG}/files/tests.pck

# ランナーを起動
adb shell am start -n ${PKG}/com.godot.game.GodotApp
```

### 完了の検知

`adb logcat` で Godot の標準出力を監視し、完了メッセージを検知する。

```bash
# logcat を監視して完了を待機
adb logcat -s GodotStdout:* | while read -r line; do
    echo "$line"
    if echo "$line" | grep -q "=== Done ==="; then
        break
    fi
done
```

---

## スクリーンショットの回収

ランナーアプリはスクリーンショットをアプリのデータディレクトリに保存する。`adb pull` で回収する。

```bash
PKG="com.example.vrtrunner"

# スクリーンショットをホストに取得
adb pull /sdcard/Android/data/${PKG}/files/output/ ./vr_screenshots/

# 後片付け: アプリデータをクリア
adb shell pm clear ${PKG}
```

---

## CI 統合

### GitHub Actions ワークフロー例

```yaml
name: VRT (Android)

on:
  push:
    branches: [main]
  pull_request:

jobs:
  vrt-android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up JDK
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: 17

      - name: Download Godot
        run: |
          RELEASE_TAG=$(curl -s "https://api.github.com/repos/godotengine/godot/releases/latest" | jq -r '.tag_name')
          wget -q "https://github.com/godotengine/godot/releases/download/${RELEASE_TAG}/Godot_v${RELEASE_TAG}_linux.x86_64.zip"
          unzip -q "Godot_v${RELEASE_TAG}_linux.x86_64.zip"
          mv "Godot_v${RELEASE_TAG}_linux.x86_64" godot
          chmod +x godot

      - name: Download Android export templates
        run: |
          RELEASE_TAG=$(curl -s "https://api.github.com/repos/godotengine/godot/releases/latest" | jq -r '.tag_name')
          TEMPLATES_DIR=~/.local/share/godot/export_templates/${RELEASE_TAG}
          mkdir -p "${TEMPLATES_DIR}"
          wget -q "https://github.com/godotengine/godot/releases/download/${RELEASE_TAG}/Godot_v${RELEASE_TAG}_export_templates.tpz"
          unzip -q "Godot_v${RELEASE_TAG}_export_templates.tpz" -d /tmp/templates
          cp /tmp/templates/templates/* "${TEMPLATES_DIR}/"

      - name: Build test PCK
        run: ./godot --headless --path tests --export-pack "Android" tests.pck

      - name: Build runner APK
        run: ./godot --headless --path runner --export-debug "Android" build/android/runner.apk

      - name: Run VRT on Android emulator
        uses: reactivecircus/android-emulator-runner@v2
        with:
          api-level: 33
          arch: x86_64
          script: |
            PKG="com.example.vrtrunner"

            adb install -r build/android/runner.apk
            adb push tests/tests.pck /sdcard/Android/data/${PKG}/files/tests.pck
            adb shell am start -n ${PKG}/com.godot.game.GodotApp

            # 完了を待機（タイムアウト 120 秒）
            timeout 120 sh -c '
              adb logcat -s GodotStdout:* | while read -r line; do
                echo "$line"
                if echo "$line" | grep -q "=== Done ==="; then
                  break
                fi
              done
            '

            adb pull /sdcard/Android/data/${PKG}/files/output/ ./vr_screenshots/

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
| レンダリング差異 | エミュレータ（swiftshader）と実機（ハードウェア GPU）で描画結果が異なる。CI では常にエミュレータを使い、ベースラインをエミュレータ基準にする |
| ストレージパス | Android のストレージパスは OS バージョンやデバイスによって異なる場合がある。`OS.get_user_data_dir()` を使用し、ハードコードを避ける |
| GDScript コンパイル | エクスポート時にプリコンパイルされるため、実行時の動的コンパイルは不可。PCK で事前にパッケージする必要がある |
| エミュレータ速度 | x86_64 エミュレータ + KVM がない CI 環境では遅い。GitHub Actions は KVM 非対応の場合があるため、タイムアウトに余裕を持たせる |
| logcat フィルタ | Godot の print 出力は `GodotStdout` タグで出力されるが、Godot バージョンによりタグ名が異なる可能性がある |
| scoped storage | Android 10 以降の scoped storage 制限により、アプリ外のファイルアクセスが制限される。アプリ固有のデータディレクトリ内で完結させる |
