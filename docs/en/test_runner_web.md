# Test Runner: Web Platform

## Overview

The Web (HTML5/WebAssembly) test runner is a Godot project exported as a web application that runs in a browser. Test target scenes and scripts are pre-bundled into a `.pck` file, which the runner app loads at startup to execute VRT capture.

Screenshots are retrieved via `JavaScriptBridge`, which communicates with the browser's JavaScript layer to send Base64-encoded PNG data to the host. In CI, Playwright is used to automate browser control.

---

## Architecture

```text
┌─────────────────────────────────────────────────────────┐
│  Host (CI / development machine)                        │
│                                                         │
│  1. godot --headless --export-pack "tests.pck"          │
│  2. godot --headless --export-preset "Web"              │
│  3. Start HTTP server (serving tests.pck)               │
│  4. Launch browser via Playwright                       │
│                                                         │
│  ┌───────────────────────────────────────────────────┐  │
│  │  Browser (Chrome / Firefox)                       │  │
│  │                                                   │  │
│  │  ┌─────────────────────────────────────────────┐  │  │
│  │  │  Godot WebAssembly Runner                   │  │  │
│  │  │                                             │  │  │
│  │  │  a. Fetch & load tests.pck                  │  │  │
│  │  │  b. Execute capture logic                   │  │  │
│  │  │  c. Send screenshots to JS layer            │  │  │
│  │  └─────────────────────────────────────────────┘  │  │
│  │                                                   │  │
│  │  JS: Receive Base64 PNG → download or transfer    │  │
│  └───────────────────────────────────────────────────┘  │
│                                                         │
│  5. Collect screenshots                                 │
│  6. Upload to Argos CI                                  │
└─────────────────────────────────────────────────────────┘
```

---

## PCK Generation

Package the test target scenes and scripts into a PCK file using Godot's `--export-pack` option.

```bash
# Generate PCK from the test project
godot --headless --path tests --export-pack "Web" tests.pck
```

The PCK includes all resources in the test project (`.tscn`, `.gd`, `.stories.json`, `.vrt.gd`). The capture logic is built into the runner app.

---

## Building the Runner App

### Export Preset Configuration

Create a Godot project for the runner and configure the Web export preset.

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
name="Web"
platform="Web"
runnable=true
export_filter="all_resources"

[preset.0.options]
html/canvas_resize_policy=0
html/experimental_virtual_keyboard=false
```

### Build Command

```bash
# Web export (HTML + WASM + JS)
godot --headless --path runner --export-release "Web" build/web/index.html
```

Output:

```text
build/web/
├── index.html
├── index.js
├── index.wasm
├── index.pck
└── index.audio.worklet.js
```

---

## Test Execution Flow

### runner_main.gd Behavior

```gdscript
extends SceneTree

func _initialize() -> void:
    # 1. Load PCK
    var pck_loaded := ProjectSettings.load_resource_pack("res://tests.pck")
    if not pck_loaded:
        # For Web, also try user:// path
        pck_loaded = ProjectSettings.load_resource_pack("user://tests.pck")

    if not pck_loaded:
        printerr("Failed to load test PCK")
        _notify_completion(false)
        quit(1)
        return

    # 2. Execute existing capture logic
    #    (capture.gd core logic built-in or called)
    await _run_capture()

    # 3. Notify JavaScript of completion
    _notify_completion(true)
    quit(0)
```

### PCK Delivery

On Web, the PCK file is delivered to the browser via HTTP. There are two approaches: injecting into the Emscripten virtual filesystem before runner startup, or fetching via `HTTPRequest` from within the runner.

**Method A: Emscripten FS Pre-injection (Recommended)**

```javascript
// Custom script in index.html
async function injectTestPck() {
    const response = await fetch('/tests.pck');
    const buffer = await response.arrayBuffer();
    const data = new Uint8Array(buffer);

    // Write file to Emscripten FS
    FS.writeFile('/userfs/tests.pck', data);
}

// Execute before Godot engine initialization
await injectTestPck();
```

**Method B: Fetch via HTTPRequest**

```gdscript
var http := HTTPRequest.new()
add_child(http)
http.request("http://localhost:8080/tests.pck")
var result := await http.request_completed
# Extract data from result and save to user://
```

---

## Screenshot Retrieval

### Sending via JavaScriptBridge

Use Godot 4.x's `JavaScriptBridge` to send captured images to the JavaScript layer.

```gdscript
## Send screenshot as Base64-encoded PNG to JS
func _send_screenshot_to_js(img: Image, file_name: String) -> void:
    var png_bytes := img.save_png_to_buffer()
    var base64 := Marshalls.raw_to_base64(png_bytes)
    JavaScriptBridge.eval(
        "window._vrtReceiveScreenshot('%s', '%s')" % [file_name, base64]
    )
```

### JavaScript Receiver

```javascript
// Collect screenshots on the browser side
window._vrtScreenshots = {};

window._vrtReceiveScreenshot = function(fileName, base64Data) {
    window._vrtScreenshots[fileName] = base64Data;
};

window._vrtComplete = false;
window._vrtNotifyCompletion = function(success) {
    window._vrtComplete = true;
    window._vrtSuccess = success;
};
```

### Collection via Playwright

```javascript
const { chromium } = require('playwright');

const browser = await chromium.launch();
const page = await browser.newPage();
await page.goto('http://localhost:8080/');

// Wait for completion
await page.waitForFunction(() => window._vrtComplete, { timeout: 120000 });

// Retrieve screenshots and save to files
const screenshots = await page.evaluate(() => window._vrtScreenshots);
for (const [fileName, base64Data] of Object.entries(screenshots)) {
    const buffer = Buffer.from(base64Data, 'base64');
    fs.writeFileSync(`vr_screenshots/${fileName}`, buffer);
}

await browser.close();
```

---

## CI Integration

### GitHub Actions Workflow Example

```yaml
name: VRT (Web)

on:
  push:
    branches: [main]
  pull_request:

jobs:
  vrt-web:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Download Godot
        run: |
          RELEASE_TAG=$(curl -s "https://api.github.com/repos/godotengine/godot/releases/latest" | jq -r '.tag_name')
          wget -q "https://github.com/godotengine/godot/releases/download/${RELEASE_TAG}/Godot_v${RELEASE_TAG}_linux.x86_64.zip"
          unzip -q "Godot_v${RELEASE_TAG}_linux.x86_64.zip"
          mv "Godot_v${RELEASE_TAG}_linux.x86_64" godot
          chmod +x godot

      - name: Download Web export templates
        run: |
          RELEASE_TAG=$(curl -s "https://api.github.com/repos/godotengine/godot/releases/latest" | jq -r '.tag_name')
          mkdir -p ~/.local/share/godot/export_templates/${RELEASE_TAG}/
          wget -q "https://github.com/godotengine/godot/releases/download/${RELEASE_TAG}/Godot_v${RELEASE_TAG}_web_template.zip"
          unzip -q "Godot_v${RELEASE_TAG}_web_template.zip" -d ~/.local/share/godot/export_templates/${RELEASE_TAG}/

      - name: Build test PCK
        run: ./godot --headless --path tests --export-pack "Web" tests.pck

      - name: Build runner
        run: ./godot --headless --path runner --export-release "Web" build/web/index.html

      - name: Copy PCK to build
        run: cp tests/tests.pck build/web/

      - uses: actions/setup-node@v4
        with:
          node-version-file: package.json

      - name: Install dependencies
        run: npm ci

      - name: Run VRT capture
        run: |
          npx serve build/web -p 8080 &
          npx playwright install chromium
          node scripts/capture_web.js

      - name: Upload screenshots to Argos
        run: npm exec -- argos upload --token ${{ secrets.ARGOS_TOKEN }} ./vr_screenshots
```

---

## Constraints

| Item | Details |
| --- | --- |
| Rendering differences | WebGL (GLES3) rendering results may differ from desktop OpenGL/Vulkan/Metal. Web-specific baseline images are required |
| File system | Only the browser's virtual FS is available. Direct local disk writes are not possible |
| GDScript compilation | GDScript is pre-compiled at export time; runtime dynamic compilation is not possible. Must be pre-packaged in a PCK |
| Performance | WebAssembly is slower than native. Allow generous timeout values |
| Browser dependency | Rendering results may differ between Chrome / Firefox / Safari. Recommended to use a single browser in CI |
| SharedArrayBuffer | Required for multi-threading features. Server must set `Cross-Origin-Opener-Policy` and `Cross-Origin-Embedder-Policy` headers |
