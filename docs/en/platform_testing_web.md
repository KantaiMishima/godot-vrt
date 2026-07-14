# Web Platform Testing

## Overview

godot-vrt supports VRT for Godot projects exported to the Web platform. The workflow
exports an HTML5 build, serves it with required headers, and uses Playwright to load
the page. The `vrt_runner` captures screenshots and uploads them to the same-origin
local server via HTTP POST.

## Architecture

```text
Build (godot --headless --export-debug "Web")
  ↓
Serve with COOP/COEP headers + POST endpoint (Node.js HTTP server)
  ↓
Playwright loads page in Chromium
  ↓
Godot vrt_runner captures screenshots
  ↓
vrt_runner POSTs each PNG to /__vrt_upload/ (before quitting)
  ↓
Argos upload for visual comparison
```

HTTP POST is used to hand off screenshots because the Emscripten virtual filesystem
is torn down when Godot quits, making it unreadable from outside afterwards.

## Test Scene

`tests/web_ui_test.tscn` renders a browser-like UI with a header bar, responsive
card grid, loading progress bar, viewport info panel, and cookie consent banner.

## Stories

| Story | Viewport | Script | Description |
| --- | --- | --- | --- |
| default | 1280x720 | - | Standard desktop layout |
| loading | 1280x720 | `web_ui_test_capture.vrt.gd` | Progress bar at 65% |
| mobile_portrait | 393x852 | - | Single-column mobile layout |
| tablet_landscape | 1024x768 | - | Two-column tablet layout |

## Scene Manifest

Export builds cannot enumerate `.tscn` files under `res://` with `DirAccess`, so
`vrt_runner` reads the capture targets from `tests/vrt_scenes.json`.
**When you add a scene, also add it to this manifest.**

```json
{
  "scenes": [
    "res://web_ui_test.tscn",
    "res://android_ui_test.tscn"
  ]
}
```

## Prerequisites

- Godot 4.5+ with Web export templates installed
- Node.js (version specified in `package.json`)
- Playwright (`npx playwright install chromium`)

## Export Settings

Export configuration is defined in `tests/export_presets.cfg` (preset `Web`):

```text
export_path = "build/web/index.html"
export_filter = "all_resources"
```

The export uses **debug mode (`--export-debug`)**: release builds strip `print()`
output, so Playwright would never see the `=== Done ===` completion marker.

## Local Verification

```bash
# 1. Export the Web build
godot --headless --path tests --export-debug "Web" build/web/index.html

# 2. Start a local server with COOP/COEP headers and an upload endpoint
mkdir -p vr_screenshots_web
node -e "
const http = require('http'), fs = require('fs'), path = require('path');
http.createServer((req, res) => {
  res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
  res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
  if (req.method === 'POST' && req.url.startsWith('/__vrt_upload/')) {
    const name = path.basename(decodeURIComponent(req.url.slice('/__vrt_upload/'.length)));
    const chunks = [];
    req.on('data', (c) => chunks.push(c));
    req.on('end', () => {
      fs.writeFileSync(path.join('vr_screenshots_web', name), Buffer.concat(chunks));
      res.writeHead(200); res.end('OK');
    });
    return;
  }
  const file = path.join('tests/build/web', req.url === '/' ? '/index.html' : req.url);
  try { res.end(fs.readFileSync(file)); } catch(e) { res.writeHead(404); res.end(); }
}).listen(8080);
"

# 3. Run the Playwright test (it just waits for === Done ===)
npx playwright test --config=playwright.config.js

# 4. PNGs are saved into vr_screenshots_web/
```

## CI Workflow

The workflow is defined in `.github/workflows/vrt-web.yml` and called by
`.github/workflows/vrt.yml`. It downloads Godot and export templates, exports the
Web build, installs Playwright, captures screenshots, and uploads them as the
`vrt-screenshots-web` artifact.

## Limitations

- **SharedArrayBuffer**: Godot Web builds require `SharedArrayBuffer`, which needs
  both `Cross-Origin-Opener-Policy: same-origin` and
  `Cross-Origin-Embedder-Policy: require-corp` headers.
- **Debug export required**: Release builds strip `print()` output, breaking
  completion detection and log diagnostics.
- **GPU rendering**: Headless Chromium uses software rendering (SwiftShader).
  Visual differences from GPU-rendered output are possible.
