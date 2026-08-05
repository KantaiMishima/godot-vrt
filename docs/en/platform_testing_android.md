# Android Platform Testing

## Overview

godot-vrt supports VRT for Android-exported Godot projects. The workflow builds a
debug APK, installs it on an emulator, captures screenshots to `user://`, extracts
them via `adb run-as`, and uploads the results to Argos.

## Architecture

```text
Build APK (godot --headless --export-debug "Android")
  ↓
Start Xvfb → start Android emulator (API 31, aosp_atd, x86_64, -gpu host)
  ↓
Install APK via adb
  ↓
Godot vrt_runner captures screenshots to user://vr_screenshots/
  ↓
Extract PNGs via: adb exec-out run-as com.godot.vrt.tests cat ...
  ↓
Argos upload for visual comparison
```

## Rendering Configuration (Important)

Three settings are required for correct rendering on CI emulators:

1. **`-gpu host` + Xvfb**: the emulator's built-in SwiftShader (GLES translator)
   has a low uniform limit, so Godot 4's 2D canvas shader fails to link —
   **every draw is silently dropped and screenshots come out as solid clear-color
   gray**. Using `-gpu host` renders through the host's Mesa llvmpipe (GL 4.5)
   instead. `-gpu host` needs an X display, so CI starts Xvfb first.
2. **`gl_compatibility` renderer**: `renderer/rendering_method.mobile="gl_compatibility"`
   in `tests/project.godot`. The emulator's software Vulkan fails to present and
   hangs the app.
3. **Include x86_64 binaries in the APK**: `architectures/x86_64=true`. The app
   then runs natively on x86_64 emulators, avoiding the slowdown and instability
   of ARM binary translation.

## Test Scene

`tests/android_ui_test.tscn` renders a Material Design UI with a status bar, app bar
with hamburger menu, card list, FAB, bottom navigation bar, and notch cutout area.

## Stories

| Story | Viewport | Script | Description |
| --- | --- | --- | --- |
| default | 412x915 | - | Standard phone portrait |
| with_notch | 412x915 | `android_ui_test_capture.vrt.gd` | Notch overlay visible |
| landscape | 915x412 | - | Landscape orientation |
| tablet | 800x1280 | - | Tablet portrait |

## Scene Manifest

Export builds cannot enumerate `.tscn` files under `res://` with `DirAccess`, so
`vrt_runner` reads the capture targets from `tests/vrt_scenes.json`.
**When you add a scene, also add it to this manifest.**

## Prerequisites

- Godot 4.5+ with Android export templates
- Android SDK (API 34+ build tools, API 31 `aosp_atd` system image), Java JDK 17+
- Debug keystore (`~/.android/debug.keystore`)

## Export Settings

Export configuration is defined in `tests/export_presets.cfg` (preset `Android`):

```text
package/unique_name        = "com.godot.vrt.tests"
package/name               = "godot-vrt tests"
export_path                = "build/android/vrt-tests.apk"
architectures/arm64-v8a    = true
architectures/x86_64       = true
```

The export uses debug mode (`--export-debug`) with ETC2/ASTC texture compression
(debug builds are required for `adb run-as` extraction).

## Local Verification

On a development machine with a GPU, the emulator's default GPU mode works fine.
In headless environments (no GPU), use Xvfb + `-gpu host` like the CI does.

```bash
# 1. Export the APK
mkdir -p tests/build/android
godot --headless --path tests --export-debug "Android" build/android/vrt-tests.apk

# 2. Start emulator and install
emulator -avd Pixel_6_API_31 -no-audio &
adb wait-for-device
adb install tests/build/android/vrt-tests.apk

# 3. Launch and wait for completion
adb shell monkey -p com.godot.vrt.tests -c android.intent.category.LAUNCHER 1
adb logcat -s godot | grep -m1 "=== Done ==="

# 4. Extract screenshots
mkdir -p vr_screenshots_android
adb shell run-as com.godot.vrt.tests ls files/vr_screenshots/ | tr -d '\r' | while read f; do
  adb exec-out run-as com.godot.vrt.tests cat "files/vr_screenshots/$f" \
    > "vr_screenshots_android/$f"
done
```

## CI Workflow

Defined in `.github/workflows/vrt-android.yml` (called by `vrt.yml`). Sets up
Java 17, Android SDK, debug keystore, exports the APK, enables KVM, starts Xvfb,
runs the app on a Pixel 6 emulator with `-gpu host`, and uploads the
`vrt-screenshots-android` artifact.

## Limitations

- **Emulator GPU**: without `-gpu host` (i.e. with the built-in SwiftShader),
  Godot 4's shaders fail to link and screenshots come out solid gray.
- **KVM**: Ubuntu CI runners need KVM enabled for emulator performance.
- **Emulator boot time**: Cold boot takes 60-120s; the workflow allows 300s.
- **Screenshot extraction**: `adb run-as` requires debug builds only.
