# Android Platform Testing

## Overview

godot-vrt supports Visual Regression Testing for Godot projects exported to Android.
The workflow builds a debug APK, installs it on an Android emulator, lets the Godot
`vrt_runner` capture screenshots to `user://`, extracts them via `adb run-as`, and
uploads the results to Argos.

## Architecture

```text
Build APK (godot --headless --export-debug "Android")
  ↓
Start Android emulator (API 31, google_apis, x86_64)
  ↓
Install APK via adb
  ↓
Godot vrt_runner captures screenshots to user://vr_screenshots/
  ↓
Extract PNGs via: adb exec-out run-as com.godot.vrt.tests cat ...
  ↓
Argos upload for visual comparison
```

## Test Scene

`tests/android_ui_test.tscn` renders a Material Design UI containing a status bar
with time and battery indicators, an app bar with a hamburger menu, a card list with
icons and subtitles, a floating action button (FAB), a bottom navigation bar, and a
notch cutout area.

## Stories

| Story | Viewport | Script | Description |
| --- | --- | --- | --- |
| default | 412x915 | - | Standard phone portrait |
| with_notch | 412x915 | `android_ui_test_capture.vrt.gd` | Notch overlay visible |
| landscape | 915x412 | - | Landscape orientation |
| tablet | 800x1280 | - | Tablet portrait |

## Prerequisites

- Godot 4.5+ with Android export templates installed
- Android SDK (API 34+ build tools, API 31 system image)
- Java JDK 17+
- Debug keystore (`~/.android/debug.keystore`)

## Export Settings

Export configuration is defined in `tests/export_presets.cfg` (preset `Android`):

```text
package/unique_name = "com.godot.vrt.tests"
package/name        = "godot-vrt tests"
export_path         = "build/android/vrt-tests.apk"
```

The export uses debug mode (`--export-debug`) with ETC2/ASTC texture compression
enabled via the export templates.

## Local Verification

```bash
# 1. Export the APK
mkdir -p tests/build/android
godot --headless --path tests --export-debug "Android" build/android/vrt-tests.apk

# 2. Start emulator and install
emulator -avd Pixel_6_API_31 -no-window -no-audio &
adb wait-for-device
adb install tests/build/android/vrt-tests.apk

# 3. Launch and wait for completion
adb shell monkey -p com.godot.vrt.tests -c android.intent.category.LAUNCHER 1
adb logcat -s godot | grep -m1 "=== Done ==="

# 4. Extract screenshots
mkdir -p vr_screenshots_android
adb shell run-as com.godot.vrt.tests ls files/vr_screenshots/ | while read f; do
  adb exec-out run-as com.godot.vrt.tests cat "files/vr_screenshots/$f" \
    > "vr_screenshots_android/$f"
done
```

## CI Workflow

The workflow is defined in `.github/workflows/vrt-android.yml` and called by the
orchestrator `.github/workflows/vrt.yml`. It sets up Java 17, Android SDK, creates
a debug keystore, exports the APK, enables KVM for emulator acceleration, runs the
app on a Pixel 6 profile emulator, extracts screenshots, and uploads them as the
`vrt-screenshots-android` artifact.

## Limitations

- **System image**: The `google_apis` system image is required for ARM translation
  support on x86_64 emulators. Using `default` images may cause crashes with native
  libraries.
- **KVM**: Ubuntu CI runners require KVM to be enabled for acceptable emulator
  performance. The workflow configures udev rules to allow KVM access.
- **Emulator boot time**: Cold-booting the emulator can take 60-120 seconds. The
  workflow sets a 300-second timeout to handle slow starts.
- **Screenshot extraction**: `adb run-as` requires the APK to be a debug build.
  Release builds restrict filesystem access.
