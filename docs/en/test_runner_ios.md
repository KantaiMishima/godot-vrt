# Test Runner: iOS Platform

## Overview

The iOS test runner is a Godot project exported as an iOS app that runs on the Simulator or a physical device. Test target scenes and scripts are pre-bundled into a `.pck` file and placed in the Simulator's app data directory via `xcrun simctl`. The runner app loads the PCK at startup, executes VRT capture, and results are retrieved directly from the Simulator's filesystem.

CI requires a macOS runner. When using the Simulator, code signing is not needed, making it straightforward to operate.

---

## Architecture

```text
┌─────────────────────────────────────────────────────────────┐
│  Host (macOS CI / development machine)                      │
│                                                             │
│  1. godot --headless --export-pack "tests.pck"              │
│  2. godot --headless --export-release "iOS" build/ios/      │
│  3. xcodebuild for Simulator build                          │
│  4. xcrun simctl install to install the app                 │
│  5. xcrun simctl to place PCK in app data directory         │
│  6. xcrun simctl launch to start the app                    │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  iOS Simulator                                        │  │
│  │                                                       │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │  Godot Runner App                               │  │  │
│  │  │                                                 │  │  │
│  │  │  a. Load Documents/tests.pck                    │  │  │
│  │  │  b. Execute capture logic                       │  │  │
│  │  │  c. Save screenshots to Documents/output/       │  │  │
│  │  │  d. Print "=== Done ===" to stdout              │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  7. xcrun simctl get_app_container to get path              │
│  8. Copy screenshots                                        │
│  9. Upload to Argos CI                                      │
└─────────────────────────────────────────────────────────────┘
```

---

## PCK Generation

Package the test target scenes and scripts into a PCK file.

```bash
# Generate PCK from the test project
godot --headless --path tests --export-pack "iOS" tests.pck
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
name="iOS"
platform="iOS"
runnable=true
export_filter="all_resources"

[preset.0.options]
application/bundle_identifier="com.example.vrtrunner"
application/short_version="1.0"
```

### Prerequisites

- macOS (required for Xcode builds)
- Xcode (latest stable version recommended)
- Godot iOS export templates
- Code signing is not required for Simulator builds

### Build Command

```bash
# Export Xcode project from Godot
godot --headless --path runner --export-release "iOS" build/ios/vrt_runner.xcodeproj

# Build for Simulator with Xcode
xcodebuild \
    -project build/ios/vrt_runner.xcodeproj \
    -scheme vrt_runner \
    -sdk iphonesimulator \
    -configuration Debug \
    -destination "platform=iOS Simulator,name=iPhone 16" \
    -derivedDataPath build/ios/DerivedData \
    build
```

Build artifacts are output to `build/ios/DerivedData/Build/Products/Debug-iphonesimulator/vrt_runner.app`.

---

## Test Execution Flow

### runner_main.gd Behavior

```gdscript
extends SceneTree

const PCK_FILENAME := "tests.pck"
const OUTPUT_SUBDIR := "output"

func _initialize() -> void:
    print("=== VRT iOS Runner ===")

    # 1. Load PCK (from Documents directory)
    var docs_dir := OS.get_user_data_dir()
    var pck_path := docs_dir.path_join(PCK_FILENAME)
    var pck_loaded := ProjectSettings.load_resource_pack(pck_path)

    if not pck_loaded:
        printerr("Failed to load test PCK: ", pck_path)
        quit(1)
        return

    # 2. Prepare output directory
    var output_dir := docs_dir.path_join(OUTPUT_SUBDIR)
    DirAccess.make_dir_recursive_absolute(output_dir)

    # 3. Execute capture logic
    await _run_capture(output_dir)

    # 4. Notify completion
    print("=== Done ===")
    quit(0)
```

### App Installation and PCK Delivery

```bash
BUNDLE_ID="com.example.vrtrunner"
APP_PATH="build/ios/DerivedData/Build/Products/Debug-iphonesimulator/vrt_runner.app"
SIMULATOR="booted"

# Boot Simulator (no-op if already running)
xcrun simctl boot "iPhone 16" 2>/dev/null || true

# Install app
xcrun simctl install ${SIMULATOR} "${APP_PATH}"

# Get app data container path
DATA_DIR=$(xcrun simctl get_app_container ${SIMULATOR} ${BUNDLE_ID} data)

# Place PCK in app's Documents directory
cp tests.pck "${DATA_DIR}/Documents/tests.pck"

# Launch app
xcrun simctl launch --console ${SIMULATOR} ${BUNDLE_ID}
```

### Completion Detection

`xcrun simctl launch --console` pipes the app's stdout to the terminal. Monitor for the completion message.

```bash
# Launch app with --console and monitor stdout
xcrun simctl launch --console ${SIMULATOR} ${BUNDLE_ID} 2>&1 | while read -r line; do
    echo "$line"
    if echo "$line" | grep -q "=== Done ==="; then
        break
    fi
done
```

---

## Screenshot Retrieval

Access the Simulator's filesystem directly to retrieve screenshots.

```bash
BUNDLE_ID="com.example.vrtrunner"
SIMULATOR="booted"

# Get app data container path
DATA_DIR=$(xcrun simctl get_app_container ${SIMULATOR} ${BUNDLE_ID} data)

# Copy screenshots
cp -r "${DATA_DIR}/Documents/output/" ./vr_screenshots/

# Cleanup: uninstall app
xcrun simctl uninstall ${SIMULATOR} ${BUNDLE_ID}
```

---

## CI Integration

### GitHub Actions Workflow Example

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

      - name: Build for Simulator
        run: |
          xcodebuild \
              -project build/ios/vrt_runner.xcodeproj \
              -scheme vrt_runner \
              -sdk iphonesimulator \
              -configuration Debug \
              -destination "platform=iOS Simulator,name=iPhone 16" \
              -derivedDataPath build/ios/DerivedData \
              build

      - name: Boot Simulator
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

          # Launch app and wait for completion (timeout 120 seconds)
          timeout 120 sh -c '
            xcrun simctl launch --console booted '"${BUNDLE_ID}"' 2>&1 | while read -r line; do
              echo "$line"
              if echo "$line" | grep -q "=== Done ==="; then
                break
              fi
            done
          '

          # Retrieve screenshots
          DATA_DIR=$(xcrun simctl get_app_container booted ${BUNDLE_ID} data)
          cp -r "${DATA_DIR}/Documents/output/" ./vr_screenshots/

      - name: Shutdown Simulator
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

## Constraints

| Item | Details |
| --- | --- |
| macOS required | Xcode and iOS Simulator only run on macOS. GitHub Actions macOS runners cost approximately 10x more than Linux |
| Rendering differences | Simulator (Apple GPU simulation) and device (Apple GPU native) may produce different Metal rendering results |
| Code signing | Not required for Simulator builds. Physical device testing requires an Apple Developer account and Provisioning Profile |
| GDScript compilation | GDScript is pre-compiled at export time; runtime dynamic compilation is not possible. Must be pre-packaged in a PCK |
| Sandbox | iOS apps run in a sandbox. File read/write is restricted to the app's Documents directory |
| Simulator limitations | iOS Simulator supports x86_64 / arm64 architectures. GitHub Actions macOS runners use Apple Silicon (arm64) |
| Xcode version | Depends on the Xcode version pre-installed on GitHub Actions macOS runners. Can be controlled with `xcodes` or `xcode-select` |
