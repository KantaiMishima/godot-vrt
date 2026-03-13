# Platform VRT: iOS

## Overview

iOS exports require a pre-built `.xcodeproj` and an IPA installed into the
iOS Simulator. `runner/platform_runner.gd` acts as the main scene; it reads
`user://vrt_config.json` from the app's Documents directory to determine which
scenes to capture. Screenshots are saved to `user://vr_screenshots/` and
retrieved via `xcrun simctl`.

> **CI Requirement:** iOS builds require a **macOS runner** in GitHub Actions.
> macOS runners are billed per-minute and cost more than Linux runners.
> Consider running iOS VRT only on scheduled workflows or release branches.

---

## Architecture

```text
[Build phase — macOS only]
  Godot Editor (or CI with macOS runner)
    └─ Export as iOS → exports/ios/godot_vrt_tests.xcodeproj
    └─ xcodebuild → exports/ios/godot_vrt_tests.app (Simulator build)

[Capture phase — iOS Simulator]

  xcrun simctl boot "iPhone 15"
  xcrun simctl install booted exports/ios/godot_vrt_tests.app
    │
  xcrun simctl launch booted <bundle-id>
    │
    ├─ Godot runtime loads runner.tscn
    │    └─ platform_runner.gd reads user://vrt_config.json
    │
    ├─ Runner instantiates each scene in SubViewport (1280×720)
    │    └─ Processes .stories.json / .vrt.gd scripts
    │
    ├─ Screenshots → user://vr_screenshots/*.png
    │    (resolves to ~/Library/Developer/CoreSimulator/Devices/<UUID>/
    │              data/Containers/Data/Application/<UUID>/Documents/
    │              vr_screenshots/)
    │
    └─ Writes user://vrt_done when finished
    │
  CI polls for vrt_done via simctl file access
  xcrun simctl data pull <UUID> vr_screenshots/ → tests/vr_screenshots/
```

---

## Directory Layout

```text
godot-vrt/
├── runner/
│   └── platform_runner.gd   # Addon-level runner template
├── tests/
│   ├── runner/
│   │   ├── platform_runner.gd   # Copy inside the Godot project
│   │   └── runner.tscn          # Main scene set in export preset
│   ├── ios_ui_test.gd           # iOS-specific UI scene
│   ├── ios_ui_test.tscn
│   ├── ios_ui_test.stories.json
│   ├── ios_ui_test_capture.vrt.gd
│   └── export_presets.cfg       # iOS export preset (preset.2)
└── exports/
    └── ios/                     # Build output (gitignored)
        └── godot_vrt_tests.xcodeproj
```

---

## Config File Format

Place `vrt_config.json` at `user://vrt_config.json` before launching the app.
On iOS Simulator this resolves to the app's Documents directory.

```json
{
  "scenes": [
    "res://ios_ui_test.tscn",
    "res://button_test.tscn",
    "res://click_test.tscn"
  ]
}
```

Omit `scenes` or leave the file absent to capture **all** `.tscn` files.

---

## Adding iOS-Specific Scenes

1. Create `tests/your_scene.gd` (extends `Control`, `custom_minimum_size = Vector2(1280, 720)`)
2. Create `tests/your_scene.tscn`
3. Optionally create `tests/your_scene.stories.json` and `tests/your_scene_capture.vrt.gd`

**iOS-specific patterns to test:**

| Pattern | Example |
| --- | --- |
| Dynamic Island / Safe Area | `ios_ui_test.gd` — notch + status bar |
| Navigation Bar (Back / Done) | `ios_ui_test.gd` — nav push |
| Tab Bar (5 items, bottom) | `ios_ui_test.gd` — tab switching |
| Home Indicator | `ios_ui_test.gd` — bottom gesture area |
| Settings-style list | Dividers, chevrons, secondary labels |

---

## Local Verification

### Prerequisites

```bash
# macOS with Xcode 15+ installed
xcode-select --install
xcodebuild -version   # should show Xcode 15.x or later

# Godot with iOS export templates
# Download via: Editor → Export Templates → Download

# List available simulators
xcrun simctl list devices available
```

### Step 1 — Boot Simulator

```bash
# Replace device name / runtime as needed
xcrun simctl boot "iPhone 15"

# Verify it is booted
xcrun simctl list devices | grep Booted
```

### Step 2 — Export iOS Build

```bash
# Export .xcodeproj from Godot
godot --headless --path tests/ \
  --export-debug iOS "$PWD/exports/ios/godot_vrt_tests.xcodeproj"

# Build .app for Simulator (no code signing needed for Simulator)
xcodebuild \
  -project exports/ios/godot_vrt_tests.xcodeproj \
  -scheme godot_vrt_tests \
  -sdk iphonesimulator \
  -configuration Debug \
  -derivedDataPath exports/ios/build \
  CODE_SIGNING_ALLOWED=NO \
  build
```

> The built `.app` is located at:
> `exports/ios/build/Build/Products/Debug-iphonesimulator/godot_vrt_tests.app`

### Step 3 — Install and Configure

```bash
APP="exports/ios/build/Build/Products/Debug-iphonesimulator/godot_vrt_tests.app"
BUNDLE_ID="com.example.godot-vrt-tests"

xcrun simctl install booted "$APP"

# Get the app's UUID in the simulator
APP_UUID=$(xcrun simctl get_app_container booted "$BUNDLE_ID" data)
DOCS_DIR="${APP_UUID}/Documents"
mkdir -p "${DOCS_DIR}/vr_screenshots"

# Optionally push a config for specific scenes only:
# echo '{"scenes":["res://ios_ui_test.tscn"]}' > "${DOCS_DIR}/vrt_config.json"
```

### Step 4 — Launch and Wait

```bash
xcrun simctl launch booted "$BUNDLE_ID"

# Poll for vrt_done (timeout 120s)
DONE="${DOCS_DIR}/vrt_done"
for i in $(seq 1 60); do
  if [ -f "$DONE" ]; then
    echo "VRT complete."
    break
  fi
  sleep 2
done
```

### Step 5 — Collect Screenshots

```bash
mkdir -p tests/vr_screenshots
cp "${DOCS_DIR}/vr_screenshots/"*.png tests/vr_screenshots/ 2>/dev/null || true
```

### Step 6 — Compare with Argos / pixelmatch

```bash
npm exec -- argos upload --token $ARGOS_TOKEN ./tests/vr_screenshots
```

---

## Troubleshooting

**Simulator boot times out**
: Run `open -a Simulator` to launch the Simulator app first, then retry `xcrun simctl boot`.

**Godot export fails with "missing template"**
: Download iOS export templates: `Editor → Export Templates → Download`.

**xcodebuild fails with signing error**
: Add `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO` flags (Simulator builds do not need signing).

**vrt\_done file never appears**
: Check Console.app (macOS) for crash logs from the app. Increase `SETTLE_FRAMES`
in `platform_runner.gd` if scenes are not rendering in time.

**Screenshots are blank**
: Godot's Metal renderer requires the app to be in the foreground.
Use `xcrun simctl launch --console booted <bundle>` to confirm the app is running.
