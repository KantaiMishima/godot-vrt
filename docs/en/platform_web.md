# Platform VRT: Web (HTML5)

## Overview

Web exports require a pre-built HTML5 bundle. Unlike desktop, Godot's `--script`
flag cannot be used at runtime. Instead, `runner/platform_runner.gd` is set as
the main scene of the export and receives the scene list via URL query parameters.

---

## Architecture

```text
[Build phase]
  Godot Editor (or CI)
    └─ Export as Web → exports/web/index.html

[Capture phase]
  HTTP server (npx serve / nginx)
    └─ serves exports/web/

  Playwright (headless Chromium)
    └─ navigates to: index.html?scenes=res://foo.tscn,res://bar.tscn
         │
         ├─ Godot runtime loads runner.tscn
         │    └─ platform_runner.gd reads ?scenes= via JavaScriptBridge
         │
         ├─ Runner instantiates each scene in SubViewport (1280×720)
         │    └─ Processes .stories.json / .vrt.gd scripts
         │
         ├─ Screenshots → window.__VRT_SCREENSHOTS__ (base64 PNG map)
         │
         └─ Sets window.__VRT_DONE__ = true
    │
    └─ web_capture.js polls __VRT_DONE__, then writes PNGs to vr_screenshots/
```

---

## Directory Layout

```text
godot-vrt/
├── runner/
│   ├── platform_runner.gd   # Main runner (copied into tests/runner/)
│   └── web_capture.js       # Playwright capture script
├── tests/
│   ├── runner/
│   │   ├── platform_runner.gd   # Copy inside the Godot project
│   │   └── runner.tscn          # Main scene set in export preset
│   ├── web_ui_test.gd           # Web-specific UI scene
│   ├── web_ui_test.tscn
│   ├── web_ui_test.stories.json
│   ├── web_ui_test_capture.vrt.gd
│   └── export_presets.cfg       # Web export preset (preset.0)
└── exports/
    └── web/                     # Build output (gitignored)
        └── index.html
```

---

## Web Screenshot Delivery

`platform_runner.gd` saves screenshots to `user://vr_screenshots/` inside the
browser's virtual file system (Emscripten / IDBFS). To retrieve them in
`web_capture.js`, two approaches are available:

**Approach A — window.\_\_VRT\_SCREENSHOTS\_\_ (recommended)**

`_maybe_push_to_web()` in `platform_runner.gd` can be extended to convert each
captured `Image` to a base64 data URL and store it:

```gdscript
func _maybe_push_to_web(img: Image, name: String) -> void:
    if not OS.has_feature("web"):
        return
    var png_bytes := img.save_png_to_buffer()
    var b64 := Marshalls.raw_to_base64(png_bytes)
    var data_url := "data:image/png;base64," + b64
    JavaScriptBridge.eval(
        "window.__VRT_SCREENSHOTS__ = window.__VRT_SCREENSHOTS__ || {};" +
        "window.__VRT_SCREENSHOTS__['%s'] = '%s';" % [name, data_url]
    )
```

**Approach B — page.screenshot() fallback**

If no screenshots are found in `window.__VRT_SCREENSHOTS__`, `web_capture.js`
falls back to a single full-page screenshot. This is useful for smoke testing.

---

## Adding Web-Specific Scenes

1. Create `tests/your_scene.gd` (extends `Control`, `custom_minimum_size = Vector2(1280, 720)`)
2. Create `tests/your_scene.tscn`
3. Optionally create `tests/your_scene.stories.json` and `tests/your_scene_capture.vrt.gd`
4. Run the capture — the runner auto-discovers all `.tscn` files

**Web-specific patterns to test:**

| Pattern | Example |
| --- | --- |
| Browser tab bar | `web_ui_test.gd` — tab switching |
| Cookie / GDPR banner | `web_ui_test.gd` — banner dismiss |
| Touch-friendly buttons (44 px min) | Large tap targets |
| Responsive breakpoints | 375 / 768 / 1280 px layouts |
| In-browser notifications | Toast / snackbar components |

---

## Local Verification

### Prerequisites

```bash
# Node.js 18+
node --version

# Install dependencies
npm install

# Install Playwright browsers (first time only)
npx playwright install chromium
```

### Step 1 — Export the Web Build

```bash
# Godot must be installed and in PATH
# Export templates for Web must be downloaded via Editor → Export Templates

godot --headless --path tests/ --export-release Web "$PWD/exports/web/index.html"
```

### Step 2 — Start HTTP Server

```bash
npx serve exports/web -p 8080
# or: python3 -m http.server 8080 --directory exports/web
```

### Step 3 — Run Web Capture

```bash
# All scenes
node runner/web_capture.js

# Specific scenes
node runner/web_capture.js "res://web_ui_test.tscn,res://button_test.tscn"
```

Screenshots are saved to `tests/vr_screenshots/`.

### Step 4 — Compare with Argos / pixelmatch

```bash
npm exec -- argos upload --token $ARGOS_TOKEN ./tests/vr_screenshots
```

---

## Troubleshooting

**Godot canvas is blank**
: Ensure `html/focus_canvas_on_start=true` in `export_presets.cfg` and that
SharedArrayBuffer headers are set (`Cross-Origin-Opener-Policy: same-origin`).

**JavaScriptBridge not available**
: Only works in Web exports. Desktop/mobile builds fall back to file-based config.

**Timeout waiting for \_\_VRT\_DONE\_\_**
: Increase `VRT_TIMEOUT_MS` env variable. Default is 120 000 ms (2 minutes).
Check browser console for Godot error messages.

**CORS errors when serving**
: Use `npx serve` with `--cors` flag or configure nginx with proper headers.
