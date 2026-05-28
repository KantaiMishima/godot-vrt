# Web Platform Testing

## Overview

godot-vrt supports Visual Regression Testing for Godot projects exported to the Web platform.
The workflow exports the project as an HTML5 build, serves it with required headers,
and uses Playwright to load the page in a real browser. The Godot `vrt_runner` captures
screenshots into the Emscripten virtual filesystem, which Playwright then extracts for
Argos upload.

## Architecture

```text
Build (godot --headless --export-release "Web")
  ↓
Serve with COOP/COEP headers (Node.js HTTP server)
  ↓
Playwright loads page in Chromium
  ↓
Godot vrt_runner captures screenshots inside Emscripten FS
  ↓
Playwright extracts PNG files from Emscripten virtual FS
  ↓
Argos upload for visual comparison
```

## Test Scene

`tests/web_ui_test.tscn` renders a browser-like UI containing a header bar with
navigation buttons and URL field, a responsive card grid, a loading progress bar,
a viewport information panel, and a cookie consent banner.

## Stories

| Story | Viewport | Script | Description |
| --- | --- | --- | --- |
| default | 1280x720 | - | Standard desktop layout |
| loading | 1280x720 | `web_ui_test_capture.vrt.gd` | Progress bar at 65% |
| mobile_portrait | 393x852 | - | Single-column mobile layout |
| tablet_landscape | 1024x768 | - | Two-column tablet layout |

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

## Local Verification

```bash
# 1. Export the Web build
godot --headless --path tests --export-release "Web" build/web/index.html

# 2. Start a local server with required headers
node -e "
const http = require('http'), fs = require('fs'), path = require('path');
http.createServer((req, res) => {
  const file = path.join('tests/build/web', req.url === '/' ? '/index.html' : req.url);
  res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
  res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
  try { res.end(fs.readFileSync(file)); } catch(e) { res.writeHead(404); res.end(); }
}).listen(8080);
"

# 3. Run Playwright tests
npx playwright test --config=playwright.config.js
```

## CI Workflow

The workflow is defined in `.github/workflows/vrt-web.yml` and called by the
orchestrator `.github/workflows/vrt.yml`. It downloads Godot and export templates,
exports the Web build, installs Playwright, captures screenshots, and uploads
them as the `vrt-screenshots-web` artifact.

## Limitations

- **SharedArrayBuffer**: Godot Web builds require `SharedArrayBuffer`, which is only
  available when both `Cross-Origin-Opener-Policy: same-origin` and
  `Cross-Origin-Embedder-Policy: require-corp` headers are set. The local server
  and CI workflow both set these headers.
- **Emscripten FS access**: The mechanism for extracting files from the virtual
  filesystem may vary between Godot versions. Test against the target Godot version
  before upgrading.
- **GPU rendering**: Headless Chromium uses software rendering. Visual differences
  from GPU-rendered output are possible.
