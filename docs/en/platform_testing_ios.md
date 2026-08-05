# iOS Platform Testing

## Overview

godot-vrt includes a reference VRT implementation for iOS. The workflow exports a
Godot project as an Xcode project, builds for iOS Simulator with `xcodebuild`,
installs via `simctl`, and extracts screenshots from the app sandbox. Currently
disabled because it requires a valid Apple Developer Team ID.

## Architecture

```text
Export Xcode project (godot --headless --export-debug "iOS")
  ↓
Build for Simulator (xcodebuild -destination 'iOS Simulator')
  ↓
Boot Simulator and install via xcrun simctl
  ↓
Godot vrt_runner captures screenshots to app sandbox
  ↓
Extract PNGs from sandbox via simctl get_app_container
  ↓
Argos upload for visual comparison
```

## Test Scene

`tests/ios_ui_test.tscn` (referenced by `ios_ui_test.stories.json`) renders an
iOS-style UI with a Dynamic Island area, large-title navigation bar, scrollable list,
tab bar, and home indicator.

## Stories

| Story | Viewport | Script | Description |
| --- | --- | --- | --- |
| iphone_notch | 390x844 | - | iPhone with notch |
| iphone_dynamic_island | 393x852 | `ios_ui_test_capture.vrt.gd` | Dynamic Island style |
| iphone_dark | 393x852 | `ios_ui_test_dark_capture.vrt.gd` | Dark mode variant |
| ipad | 1024x1366 | - | iPad portrait |

## Scene Manifest

Export builds cannot enumerate `.tscn` files under `res://` with `DirAccess`, so
`vrt_runner` reads the capture targets from `tests/vrt_scenes.json`.
**When you add a scene, also add it to this manifest.**

## Prerequisites

- macOS with Xcode installed
- Godot 4.5+ with iOS export templates
- iOS Simulator runtime (included with Xcode)

## Export Settings

Export configuration is defined in `tests/export_presets.cfg` (preset `iOS`):

```text
application/app_store_team_id  = "PLACEHOLDER"
application/bundle_identifier  = "com.godot.vrt.tests"
application/min_ios_version    = "15.0"
export_path                    = "build/ios/"
```

Replace `PLACEHOLDER` with a real Apple Developer Team ID before enabling.

## Local Verification (macOS only)

```bash
# 1. Export and build
mkdir -p tests/build/ios
godot --headless --path tests --export-debug "iOS" build/ios/
xcodebuild -project tests/build/ios/vrt-tests.xcodeproj -scheme vrt-tests \
  -destination 'platform=iOS Simulator,name=iPhone 15' -configuration Debug \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build

# 2. Install and run on Simulator
xcrun simctl boot "iPhone 15"
APP_PATH=$(find tests/build/ios/Build -name "*.app" -type d | head -1)
xcrun simctl install booted "$APP_PATH"
xcrun simctl launch booted com.godot.vrt.tests

# 3. Extract screenshots
APP_DATA=$(xcrun simctl get_app_container booted com.godot.vrt.tests data)
mkdir -p vr_screenshots_ios
find "$APP_DATA" -name "*.png" -path "*/vr_screenshots/*" -exec cp {} ./vr_screenshots_ios/ \;
```

## Current Status and CI Workflow

This workflow is **disabled** (`if: false` in `vrt-ios.yml`). To enable, set a real
Apple Developer Team ID in `tests/export_presets.cfg` and remove `if: false`. The
workflow (`.github/workflows/vrt-ios.yml`, called by `vrt.yml`) runs on `macos-latest`.

## Limitations

- **Apple Developer Team ID**: Required even for Simulator builds in some cases.
- **macOS only**: iOS Simulator needs macOS runners (slower and more expensive in CI).
- **Simulator differences**: Rendering may differ from physical devices, particularly
  for Metal shaders and GPU-accelerated effects.
