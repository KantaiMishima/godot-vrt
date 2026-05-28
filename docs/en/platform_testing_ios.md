# iOS Platform Testing

## Overview

godot-vrt includes a reference implementation for Visual Regression Testing on iOS.
The workflow exports a Godot project as an Xcode project, builds it for the iOS
Simulator with `xcodebuild`, installs the app via `simctl`, and extracts screenshots
from the app sandbox. This workflow is currently disabled because it requires a valid
Apple Developer Team ID.

## Architecture

```text
Export Xcode project (godot --headless --export-release "iOS")
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

`tests/ios_ui_test.tscn` (referenced by `ios_ui_test.stories.json`) renders an iOS-style
UI containing a Dynamic Island area, a large-title navigation bar, a scrollable list
with row separators, a tab bar with icons, and a home indicator.

## Stories

| Story | Viewport | Script | Description |
| --- | --- | --- | --- |
| iphone_notch | 390x844 | - | iPhone with notch |
| iphone_dynamic_island | 393x852 | `ios_ui_test_capture.vrt.gd` | Dynamic Island style |
| iphone_dark | 393x852 | `ios_ui_test_dark_capture.vrt.gd` | Dark mode variant |
| ipad | 1024x1366 | - | iPad portrait |

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

The `app_store_team_id` is set to `PLACEHOLDER`. Replace it with a real Apple
Developer Team ID before enabling the workflow.

## Local Verification (macOS only)

```bash
# 1. Export the Xcode project
mkdir -p tests/build/ios
godot --headless --path tests --export-release "iOS" build/ios/

# 2. Build for Simulator (code signing disabled)
xcodebuild -project tests/build/ios/vrt-tests.xcodeproj \
  -scheme vrt-tests \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -configuration Release \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  build

# 3. Boot Simulator and install
xcrun simctl boot "iPhone 15"
APP_PATH=$(find tests/build/ios/Build -name "*.app" -type d | head -1)
xcrun simctl install booted "$APP_PATH"
xcrun simctl launch booted com.godot.vrt.tests

# 4. Extract screenshots from app sandbox
APP_DATA=$(xcrun simctl get_app_container booted com.godot.vrt.tests data)
mkdir -p vr_screenshots_ios
find "$APP_DATA" -name "*.png" -path "*/vr_screenshots/*" -exec cp {} ./vr_screenshots_ios/ \;
```

## Current Status

This workflow is **disabled** in CI. The job in `vrt-ios.yml` has `if: false` set.
To enable it: (1) set a real Apple Developer Team ID in `tests/export_presets.cfg`,
(2) remove `if: false` from `.github/workflows/vrt-ios.yml`.

## CI Workflow

The workflow is defined in `.github/workflows/vrt-ios.yml` and called by
`.github/workflows/vrt.yml`. It runs on `macos-latest`, downloads Godot for macOS,
exports the Xcode project, builds for Simulator, runs the app, and uploads
screenshots as the `vrt-screenshots-ios` artifact.

## Limitations

- **Apple Developer Team ID**: Required even for Simulator builds in some Godot
  export configurations. Without it, the export step may fail.
- **macOS only**: iOS Simulator is only available on macOS runners, which are more
  expensive and slower to provision in CI.
- **Simulator differences**: Rendering may differ from physical devices, particularly
  for GPU-accelerated effects and Metal shaders.
