# Random Seed Design

## Background

To reliably compare screenshots in VRT (Visual Regression Testing),
**the same image must be produced every time**.
Scenes that use random numbers produce different visuals on each run, so a mechanism to fix randomness is required.

---

## Types of Randomness in Godot

| Type | Usage | How to fix seed |
| --- | --- | --- |
| Global RNG | `randf()`, `randi()`, `randfn()`, etc. | `seed(n)` |
| `RandomNumberGenerator` | `rng.randf()`, etc. | `rng.seed = n` |
| `noise` (FastNoiseLite, etc.) | Shaders, textures | `noise.seed = n` |

---

## Three Patterns

### Pattern 1: Fix global seed inside capture.gd

Fix the global seed in `capture.gd` **immediately before** loading the scene.

```gdscript
# Inside capture.gd
seed(12345)
var scene_node := packed.instantiate()
vp.add_child(scene_node)
```

**Pros:** No changes needed in scenes. Zero adoption cost.

**Cons:** If the scene calls `randomize()`, the seed is reset and this approach fails.
Does not affect `RandomNumberGenerator` instances or `noise.seed`.

**When to use:** Small scenes that use `randf()` / `randi()` directly.

---

### Pattern 2: Implement a VRT hook method in the scene

Add a `_vrt_setup(seed: int)` method to the scene.
`capture.gd` calls this method after loading the scene.

```gdscript
# Scene side (e.g. particle_scene.gd)
func _vrt_setup(p_seed: int) -> void:
    rng.seed = p_seed
    noise.seed = p_seed
    $AnimationPlayer.stop()  # also stop animations
```

```gdscript
# capture.gd side
var scene_node := packed.instantiate()
vp.add_child(scene_node)
if scene_node.has_method("_vrt_setup"):
    scene_node._vrt_setup(12345)
```

**Pros:** Can fix anything — `RandomNumberGenerator`, noise, animations, etc.
Each scene can customize what gets fixed.

**Cons:** Requires implementation in each scene (additional work for existing scenes).
Has no effect on scenes without `_vrt_setup` (can be combined with Pattern 1).

**When to use:** Scenes that use particles, noise textures, or custom RNG instances.

---

### Pattern 3: Disable randomize() via autoload

Override `randomize()` in an autoload script to prevent seed resets during VRT runs.

```gdscript
# autoload: VRTContext.gd
var _vrt_mode := false

func enable_vrt_mode(p_seed: int = 12345) -> void:
    _vrt_mode = true
    seed(p_seed)

func randomize() -> void:
    if _vrt_mode:
        return  # do nothing — prevent seed from being overwritten
    super.randomize()
```

```gdscript
# capture.gd side
VRTContext.enable_vrt_mode(12345)
var scene_node := packed.instantiate()
```

**Pros:** Can neutralize `randomize()` calls inside scenes.
Higher chance of preserving the seed without modifying existing scenes.

**Cons:** `randomize()` is a built-in function, so a complete override from GDScript is not possible
(does not affect `.randomize()` on `RandomNumberGenerator` instances).
Requires adding an autoload to the project; high implementation cost with limited effect.

**When to use:** Supplementary measure when many existing scenes only use `randomize()`.

---

## Recommended Approach

The practical choice is to **combine Pattern 1 and Pattern 2**.

```text
capture.gd execution order:
  1. seed(12345)                    ← Pattern 1: fix global seed
  2. scene_node = instantiate()
  3. vp.add_child(scene_node)
  4. if has_method("_vrt_setup"):
       _vrt_setup(12345)            ← Pattern 2: scene-side hook
  5. wait frames
  6. get_image()
```

- **Existing scenes are covered as-is** by Pattern 1
- **Only problematic scenes** get a `_vrt_setup` implementation for Pattern 2

Introduce Pattern 2 only when an actual issue occurs with a `RandomNumberGenerator` instance, noise, or similar.
It is not needed at this point.

Pattern 3 has limited effect and is deferred for now.

---

## Per-scene Seed Customization (stories configuration)

Placing a `.stories.json` file next to a scene file lets you define scene-specific seeds and story names.
When a stories config exists, `capture.gd` uses those seeds instead of the default `VRT_SEEDS`.

```text
res://ui/
├── title.tscn
└── title.stories.json   ← scene-specific seed definitions
```

Relationship between stories config and Pattern 1/2:

- Each `seed` in the stories config is used as the Pattern 1 seed
- The same seed is passed to `_vrt_setup(seed)` when Pattern 2 is implemented

See [stories_config.md](stories_config.md) for details.

---

## Current Implementation Status

| Pattern | Status | Notes |
| --- | --- | --- |
| Pattern 1 | **Implemented** | Handled by `seed(vrt_seed)` in `capture.gd` |
| Pattern 2 | Not implemented (future candidate) | To be added only when a specific scene requires it |
| Pattern 3 | Deferred | Limited effectiveness |

`capture.gd` has `VRT_DEFAULT_SEED: int = 12345`.
Without a stories config, it captures one screenshot. Output file: `{scene}.png`.

When a `.stories.json` is placed next to the scene, its seed and name take precedence.
Output file: `{scene}_{story_name}.png` (see [stories_config.md](stories_config.md)).

---

## Progress

1. Added `seed(vrt_seed)` to `capture.gd` (Pattern 1 implementation) ← **Done**
2. Ran with 3 seeds and confirmed reproducibility and variation across seeds ← **Done**
3. Pattern 2 will be addressed when a scene that needs it appears
