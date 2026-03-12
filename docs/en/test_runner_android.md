# Test Runner: Android Platform

## Overview

The Android test runner is a Godot project exported as an APK that runs on an emulator or physical device. Test target scenes and scripts are pre-bundled into a `.pck` file and transferred to the device via `adb push`. The runner app loads the PCK at startup, executes VRT capture, and results are retrieved via `adb pull`.

---

## Architecture

```text
┌──────────────────────────────────────────────────────────┐
│  Host (CI / development machine)                         │
│                                                          │
│  1. godot --headless --export-pack "tests.pck"           │
│  2. godot --headless --export-release "Android" runner.apk│
│  3. adb install runner.apk                               │
│  4. adb push tests.pck /sdcard/Android/data/{pkg}/files/ │
│  5. adb shell am start -n {pkg}/.GodotApp                │
│                                                          │
│  ┌────────────────────────────────────────────────────┐  │
│  │  Android Emulator / Device                         │  │
│  │                                                    │  │
│  │  ┌──────────────────────────────────────────────┐  │  │
│  │  │  Godot Runner App (APK)                      │  │  │
│  │  │                                              │  │  │
│  │  │  a. Load /files/tests.pck                    │  │  │
│  │  │  b. Execute capture logic                    │  │  │
│  │  │  c. Save screenshots to /files/output/       │  │  │
│  │  │  d. Print "=== Done ===" to logcat           │  │  │
│  │  └──────────────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────┘  │
│                                                          │
│  6. Detect completion via adb logcat                     │
│  7. adb pull /sdcard/Android/data/{pkg}/files/output/    │
│  8. Upload to Argos CI                                   │
└──────────────────────────────────────────────────────────┘
```

---

## PCK Generation

Package the test target scenes and scripts into a PCK file.

```bash
# Generate PCK from the test project
godot --headless --path tests --export-pack "Android" tests.pck
```

The PCK includes all resources in the test project (`.tscn`, `.gd`, `.stories.json`, `.vrt.gd`) in pre-compiled form.

---

## Building the Runner App

### Export Preset Configuration

```text
runner/
├── project.godot
├── export_presets.cfg
├── runner_main.gd        ← Entry point (capture logic built-in)
└── runner_main.tscn
```

Key `export_presets.cfg` settings:

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

### Prerequisites

- Android SDK (API level 33 or higher recommended)
- Android NDK
- Godot Android export templates
- `ANDROID_HOME` environment variable configured

### Build Command

```bash
# Build debug APK (release build not needed for CI)
godot --headless --path runner --export-debug "Android" build/android/runner.apk
```

---

## Test Execution Flow

### runner_main.gd Behavior

```gdscript
extends SceneTree

const PKG_DATA_DIR := "user://"
const PCK_FILENAME := "tests.pck"
const OUTPUT_SUBDIR := "output"

func _initialize() -> void:
    print("=== VRT Android Runner ===")

    # 1. Load PCK
    var pck_path := PKG_DATA_DIR.path_join(PCK_FILENAME)
    var pck_loaded := ProjectSettings.load_resource_pack(pck_path)

    if not pck_loaded:
        # Try full path via OS.get_user_data_dir()
        var full_path := OS.get_user_data_dir().path_join(PCK_FILENAME)
        pck_loaded = ProjectSettings.load_resource_pack(full_path)

    if not pck_loaded:
        printerr("Failed to load test PCK")
        quit(1)
        return

    # 2. Prepare output directory
    var output_dir := OS.get_user_data_dir().path_join(OUTPUT_SUBDIR)
    DirAccess.make_dir_recursive_absolute(output_dir)

    # 3. Execute capture logic (capture.gd core logic built-in)
    await _run_capture(output_dir)

    # 4. Notify completion (output to logcat)
    print("=== Done ===")
    quit(0)
```

### PCK Delivery

Use `adb` to transfer the PCK file to the app's data directory.

```bash
PKG="com.example.vrtrunner"

# Install APK
adb install -r build/android/runner.apk

# Transfer PCK to app data area
adb push tests.pck /sdcard/Android/data/${PKG}/files/tests.pck

# Launch runner
adb shell am start -n ${PKG}/com.godot.game.GodotApp
```

### Completion Detection

Monitor Godot's stdout via `adb logcat` to detect the completion message.

```bash
# Monitor logcat and wait for completion
adb logcat -s GodotStdout:* | while read -r line; do
    echo "$line"
    if echo "$line" | grep -q "=== Done ==="; then
        break
    fi
done
```

---

## Screenshot Retrieval

The runner app saves screenshots to its data directory. Retrieve them with `adb pull`.

```bash
PKG="com.example.vrtrunner"

# Pull screenshots to host
adb pull /sdcard/Android/data/${PKG}/files/output/ ./vr_screenshots/

# Cleanup: clear app data
adb shell pm clear ${PKG}
```

---

## CI Integration

### GitHub Actions Workflow Example

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

            # Wait for completion (timeout 120 seconds)
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

## Constraints

| Item | Details |
| --- | --- |
| Rendering differences | Emulator (swiftshader) and device (hardware GPU) produce different rendering results. In CI, always use the emulator and base baselines on emulator output |
| Storage paths | Android storage paths may vary by OS version and device. Use `OS.get_user_data_dir()` and avoid hardcoding paths |
| GDScript compilation | GDScript is pre-compiled at export time; runtime dynamic compilation is not possible. Must be pre-packaged in a PCK |
| Emulator speed | x86_64 emulator without KVM in CI environments can be slow. GitHub Actions may not support KVM, so allow generous timeouts |
| logcat filtering | Godot's print output uses the `GodotStdout` tag, but the tag name may differ between Godot versions |
| Scoped storage | Android 10+ scoped storage restricts file access outside the app. Keep all operations within the app's data directory |
