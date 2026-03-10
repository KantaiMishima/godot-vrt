# godot-vrt

A Godot addon that brings **visual regression testing** to the Godot engine.

Captures screenshots of scenes and compares them against baseline images to detect unintended visual changes.

> **日本語版:** [README.ja.md](README.ja.md)

---

## Overview

`godot-vrt` is an addon for the Godot engine.

- Automatically captures screenshots of scenes (`.tscn`)
- Detects unintended UI/layout changes by comparing captured images against baselines (**visual regression testing**)
- Supports execution in CI environments (Linux/macOS)

> **Comparison and diff management** are left to the user — combine with any VRT tool such as Argos CI, reg-suit, or pixelmatch.

---

## Position in the Testing Trophy

godot-vrt sits at the **integration test** layer of the **Testing Trophy** (coined by Kent C. Dodds).

```text
           /\
          /E2\          E2E tests (real device, real player input)
         /----\
        /      \
       / Integr \  ← ★ godot-vrt is here
      / -ation   \      renders actual scenes with a real renderer and compares visual output
     /____________\     (the cup = the layer with the most weight in the testing strategy)
         |    |
         |Unit|         Unit tests (logic in isolation) ← stem (less weight)
         |____|
     ____________
    |   Static   |      Static analysis (type checks, lint) ← base
    |____________|
```

| Problem to detect | Appropriate layer | Example tools in Godot |
| --- | --- | --- |
| Type errors, undefined variables | Static analysis | `godot --check-only`, gdlint |
| Logic bugs in scoring or collision | Unit tests | GUT (Godot Unit Test) |
| Correct behavior with real player input | E2E tests | Real device + input macros |
| Unintended UI visual changes | **Integration (VRT)** | godot-vrt |

> **godot-vrt alone is not enough.**
> Combine it with static analysis, unit tests, and E2E tests for best results.

---

## Installation

```bash
# Clone into your project's addons/ directory
git clone https://github.com/KantaiMishima/godot-vrt.git addons/godot-vrt
```

---

## Usage

```bash
# macOS (Metal offscreen)
GODOT_MTL_OFF_SCREEN=1 godot --headless --rendering-driver metal --script addons/godot-vrt/capture.gd

# Linux CI (Xvfb + OpenGL3 software rendering)
xvfb-run godot --rendering-driver opengl3 --script addons/godot-vrt/capture.gd
```

Captured images are saved to `{project}/vr_screenshots/` (`vr` = visual regression).

| Condition | Filename |
| --- | --- |
| No stories config (default) | `{scene_name}.png` |
| With stories config | `{scene_name}_{story_name}.png` |

By default, one screenshot is taken with seed `12345`.
Placing a `{scene_name}.stories.json` next to the scene file lets you configure the seed and story name per scene (see [docs/en/stories_config.md](docs/en/stories_config.md)).

---

## Design

### Separation of Concerns

| Responsibility | Owner |
| --- | --- |
| Scene screenshot capture | **This repository** (`capture.gd`) |
| Diff comparison and baseline management | **User** (any VRT tool) |

**Distribution:** Distributed as a standalone addon repository. Users clone it under `addons/`.

---

## Architecture

```text
[This repository's responsibility]
  capture.gd
    │
    ├─ Enumerate scenes (recursive .tscn search or argument-specified)
    │
    ├─ Launch Godot (offscreen with real renderer)
    │    └─ GODOT_MTL_OFF_SCREEN=1 --rendering-driver metal  (macOS)
    │    └─ xvfb-run --rendering-driver opengl3              (Linux CI)
    │
    ├─ Load scene → wait N frames (layout stabilization)
    │
    ├─ Capture via SubViewport::get_image()
    │    └─ Fixed viewport size (1280×720)
    │
    ├─ Load .stories.json if present (per-scene seed and story name)
    │
    └─ Save PNG → {project}/vr_screenshots/{scene_name}.png
                                          or {scene_name}_{story_name}.png

[User's responsibility]
  Compare with any VRT tool
    ├─ Argos CI (OSS free tier, auto PR comments)
    ├─ reg-suit (stores on S3/GCS)
    ├─ pixelmatch (custom script)
    └─ others
```

---

## Documentation

| Document | Description |
| --- | --- |
| [docs/en/stories_config.md](docs/en/stories_config.md) | Stories configuration file format and usage |
| [docs/en/random_seed.md](docs/en/random_seed.md) | Random seed design and pattern breakdown |
| [docs/en/interaction_testing.md](docs/en/interaction_testing.md) | Interaction testing patterns and implementation examples |

**Japanese documentation:** [docs/ja/](docs/ja/)

---

## License

See [LICENSE](LICENSE).
