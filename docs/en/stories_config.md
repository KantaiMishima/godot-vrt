# Stories Configuration File

## Overview

`.stories.json` is a per-scene configuration file for screenshot capture.
Place it in the same directory as the scene file (`.tscn`), using the same base filename.

```text
res://
├── ui/
│   ├── title.tscn
│   └── title.stories.json   ← stories config for title.tscn
└── game/
    ├── gameplay.tscn
    └── gameplay.stories.json
```

When a config file exists for a scene, screenshots are taken with the seeds and names defined in the file.
Without a config file, one screenshot is captured using seed `12345`.

---

## File Format

```json
{
  "stories": [
    { "name": "story-name", "seed": 12345 },
    { "name": "story-name", "seed": 99999 }
  ]
}
```

**`stories`**: Required. Array of screenshot entries.

Fields per entry:

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `name` | string | ✓ | Identifier for the screenshot. Used in the output filename |
| `seed` | number (int) | ✓ | Global random seed. Integer passed to `seed(n)` |
| `delay_ms` | number (int) | - | Additional wait time in milliseconds after SETTLE_FRAMES. Defaults to 0 |
| `script` | string | - | Path to an external GDScript (`res://` format) to delegate capture. Defaults to standard capture |

---

## Output Filename

| Configuration | Output format |
| --- | --- |
| No stories config | `{scene_name}.png` |
| With stories config | `{scene_name}_{story_name}.png` |
| `script` used, suffix provided | `{scene_name}_{story_name}_{suffix}.png` |
| `script` used, no suffix | `{scene_name}_{story_name}.png` |

---

## Examples

### Basic example

```json
{
  "stories": [
    { "name": "default",     "seed": 12345 },
    { "name": "alternative", "seed": 99999 },
    { "name": "minimal",     "seed": 42    }
  ]
}
```

Output:

```text
vr_screenshots/
├── title_default.png
├── title_alternative.png
└── title_minimal.png
```

### delay_ms: Capture mid-animation states

Reloads the scene with the same seed and captures at different wait times.
Useful for recording intermediate states of auto-playing animations.

```json
{
  "stories": [
    { "name": "t0",    "seed": 12345 },
    { "name": "t100",  "seed": 12345, "delay_ms": 100 },
    { "name": "t500",  "seed": 12345, "delay_ms": 500 },
    { "name": "t2000", "seed": 12345, "delay_ms": 2000 }
  ]
}
```

Output:

```text
vr_screenshots/
├── title_t0.png
├── title_t100.png
├── title_t500.png
└── title_t2000.png
```

### script: Capture multiple screenshots with an external script

Use this when you want multiple screenshots from a single story, or when you need to
interact with the scene (button presses, state changes, etc.).

```json
{
  "stories": [
    {
      "name": "animation",
      "seed": 12345,
      "script": "res://tests/animation_capture.vrt.gd"
    }
  ]
}
```

Example external script (`animation_capture.vrt.gd`):

```gdscript
extends RefCounted

func run(scene_node: Node, session: Object) -> void:
    # Screenshot after 100ms
    await session.wait_ms(100)
    await session.take_screenshot("100ms")

    # Total 500ms
    await session.wait_ms(400)
    await session.take_screenshot("500ms")

    # Total 2000ms
    await session.wait_ms(1500)
    await session.take_screenshot("2000ms")
```

Output:

```text
vr_screenshots/
├── title_animation_100ms.png
├── title_animation_500ms.png
└── title_animation_2000ms.png
```

#### VRTSession API

Methods on the `session` object passed to `run(scene_node, session)`:

| Method | Description |
| --- | --- |
| `await session.wait_ms(ms: float)` | Wait for the specified number of milliseconds |
| `await session.take_screenshot(suffix: String = "")` | Save a screenshot. When suffix is omitted, outputs `{story_name}.png` |

### UI theme variations

```json
{
  "stories": [
    { "name": "light", "seed": 1000 },
    { "name": "dark",  "seed": 2000 }
  ]
}
```

### Single scene, single seed

Use a single-element array when only one variant is needed.

```json
{
  "stories": [
    { "name": "fixed", "seed": 0 }
  ]
}
```

---

## When to Use delay_ms vs. script

| Use case | Recommended approach |
| --- | --- |
| Record multiple points during an animation | `delay_ms` (reloads the scene each time) |
| Capture multiple screenshots from a single load, or interact with the scene | `script` |
| Both `delay_ms` and `script` are specified | `script` takes precedence |

---

## When to Use Stories Config vs. Default Behavior

| Situation | Recommendation |
| --- | --- |
| Scene does not use random numbers | No config needed (capture with the default single seed) |
| Scene uses random numbers, want specific variations | Define variations with a stories config |
| Want to manage screenshots by meaningful names rather than seeds | Use the `name` field in the stories config |

---

## Compatibility with Existing Baseline Images

Adding a stories config changes the output filename.

- **Before:** `scene_name.png`
- **After:** `scene_name_{story_name}.png`

Because the filenames no longer match existing baseline images, **you must recapture and re-register baseline images after adding the config**.

---

## Scope of Seed Fixation

The `seed` field fixes Godot's global RNG (`randf()`, `randi()`, `randf_range()`, etc.).
It does not affect `RandomNumberGenerator` instances or the seed of `FastNoiseLite`.

To fix those, implement a `_vrt_setup(seed: int)` hook in the scene (see [random_seed.md](random_seed.md)).
