# Interaction Testing

> For where godot-vrt fits in the overall testing strategy,
> see [README.md — Position in the Testing Trophy](../../README.md#position-in-the-testing-trophy).

---

## Interaction Patterns

godot-vrt runs in a headless environment (no display), so
**actual mouse and keyboard events are unreliable**.

Instead, the recommended pattern is to **expose public methods** on the scene that reproduce
the desired interactions, and call those methods from a `.vrt.gd` script.

```gdscript
# Scene side: expose a public method
func click_button(idx: int) -> void:
    _buttons[idx].emit_signal("pressed")

# .vrt.gd side: call the method to reproduce the interaction
func run(scene_node: Node, session: Object) -> void:
    scene_node.click_button(0)
    await session.take_screenshot("after_click")
```

This pattern has minimal environment dependency and works reliably in CI.

---

## Pattern 1: Button Operations

Reproduce pressing a Godot `Button` node.

### Scene-side implementation

Use `emit_signal("pressed")` to simulate a button press.
Skipping `disabled` buttons reflects the actual UI constraints.

```gdscript
# button_test.gd (excerpt)
var _buttons: Array[Button] = []

func click_button(idx: int) -> void:
    if idx < 0 or idx >= _buttons.size():
        return
    if _buttons[idx].disabled:
        return
    _buttons[idx].emit_signal("pressed")
```

### `.vrt.gd` implementation

```gdscript
# button_test_capture.vrt.gd
extends RefCounted

func run(scene_node: Node, session: Object) -> void:
    # Initial state
    await session.take_screenshot("01_initial")

    # Press button
    scene_node.click_button(0)
    await session.take_screenshot("02_after_click1")

    # Press more
    scene_node.click_button(0)
    scene_node.click_button(0)
    await session.take_screenshot("03_after_click3")

    # Press reset button
    scene_node.click_button(1)
    await session.take_screenshot("04_after_reset")
```

### `.stories.json` configuration

```json
{
  "stories": [
    {
      "name": "interaction",
      "seed": 0,
      "script": "res://button_test_capture.vrt.gd"
    }
  ]
}
```

### Output files

```text
vr_screenshots/
├── button_test_interaction_01_initial.png      ← Initial state (Count: 0)
├── button_test_interaction_02_after_click1.png ← After 1 click (Count: 1)
├── button_test_interaction_03_after_click3.png ← After 3 clicks (Count: 3)
└── button_test_interaction_04_after_reset.png  ← After reset (Count: 0)
```

Sample implementation: [`tests/button_test.gd`](../../tests/button_test.gd) /
[`tests/button_test_capture.vrt.gd`](../../tests/button_test_capture.vrt.gd)

---

## Pattern 2: Click Operations

Reproduce **clicks on generic controls** such as cards or tiles (not `Button` nodes).
Handles selection toggles and visual changes triggered by clicks.

### Scene-side implementation

Expose a method that manages the selection state.

```gdscript
# click_test.gd (excerpt)
var _cards: Array[ColorRect] = []
var _selected: Array[bool] = []

func select_card(idx: int) -> void:
    if idx < 0 or idx >= _cards.size():
        return
    _selected[idx] = not _selected[idx]
    _cards[idx].color = CARD_SELECTED_COLOR if _selected[idx] else CARD_DEFAULT_COLOR
```

### `.vrt.gd` implementation

```gdscript
# click_test_capture.vrt.gd
extends RefCounted

func run(scene_node: Node, session: Object) -> void:
    # Initial state (all deselected)
    await session.take_screenshot("01_initial")

    # Select one card
    scene_node.select_card(0)
    await session.take_screenshot("02_card0_selected")

    # Select multiple
    scene_node.select_card(3)
    scene_node.select_card(5)
    await session.take_screenshot("03_multi_selected")

    # Click again to deselect
    scene_node.select_card(0)
    await session.take_screenshot("04_card0_deselected")
```

### Output files

```text
vr_screenshots/
├── click_test_interaction_01_initial.png          ← All cards deselected
├── click_test_interaction_02_card0_selected.png   ← Card 0 selected
├── click_test_interaction_03_multi_selected.png   ← Cards 0, 3, 5 selected
└── click_test_interaction_04_card0_deselected.png ← Card 0 deselected (3, 5 remain)
```

Sample implementation: [`tests/click_test.gd`](../../tests/click_test.gd) /
[`tests/click_test_capture.vrt.gd`](../../tests/click_test_capture.vrt.gd)

---

## Pattern 3: Value Manipulation on UI Elements

Record visual changes in **UI elements that hold numeric or state values**,
such as sliders, progress bars, and input fields.

### Scene-side implementation

Expose a method that sets the value from outside.

```gdscript
# timing_test.gd (excerpt)
func set_progress(t: float) -> void:
    _bar.position.x = t * (_track_width - _bar_width)
    _tween.kill()  # stop animation and lock position
```

### `.vrt.gd` implementation

```gdscript
# timing_test_capture.vrt.gd (existing)
extends RefCounted

func run(scene_node: Node, session: Object) -> void:
    for t: float in [0.0, 0.25, 0.5, 1.0]:
        scene_node.set_progress(t)
        await session.take_screenshot("t%03d" % int(t * 100))
```

**Note:** Unlike waiting with `delay_ms`, directly setting values eliminates
rendering-speed dependency and produces more reproducible results.

For guidance on `delay_ms` vs. `script`, see [stories_config.md](stories_config.md).

Sample implementation: [`tests/timing_test.gd`](../../tests/timing_test.gd) /
[`tests/timing_test_capture.vrt.gd`](../../tests/timing_test_capture.vrt.gd)

---

## Pattern 4: Special Effects Triggered by Command Input

Record **special visual effects** triggered by text input or key sequences.
Capturing both correct and incorrect inputs lets you visually compare whether the effect appears.

### Scene-side implementation

Expose methods that handle command input and effect display.

```gdscript
# command_test.gd (excerpt)
const CORRECT_COMMAND := "GODOT"

func input_command(text: String) -> void:
    _input_label.text = "> " + text

    if text == CORRECT_COMMAND:
        _status_label.text = "SUCCESS!"
        for r: ColorRect in _effect_rects:
            r.visible = true      # show rainbow border
    else:
        _status_label.text = "Command not found"
        for r: ColorRect in _effect_rects:
            r.visible = false
```

### `.vrt.gd` implementation

```gdscript
# command_test_capture.vrt.gd
extends RefCounted

func run(scene_node: Node, session: Object) -> void:
    # Initial state
    await session.take_screenshot("01_initial")

    # Wrong command → error message, no effect
    scene_node.input_command("HELLO")
    await session.take_screenshot("02_wrong_command")

    # Correct command → success effect (rainbow border) appears
    scene_node.input_command("GODOT")
    await session.take_screenshot("03_success_effect")
```

### Output files

```text
vr_screenshots/
├── command_test_interaction_01_initial.png        ← Before any input
├── command_test_interaction_02_wrong_command.png  ← After wrong input
└── command_test_interaction_03_success_effect.png ← After correct input (effect shown)
```

Sample implementation: [`tests/command_test.gd`](../../tests/command_test.gd) /
[`tests/command_test_capture.vrt.gd`](../../tests/command_test_capture.vrt.gd)

---

## Method Design Guidelines

Guidelines for designing public methods called from `.vrt.gd`:

| Guideline | Reason |
| --- | --- |
| Name methods by their intent (`click_button`, `select_card`) | Makes the operation clear when reading the VRT script |
| Add bounds checks (ignore out-of-range indices) | Prevents scene crashes from incorrect arguments |
| Do not operate on `disabled` buttons | Reflects the same constraints as the actual UI |
| Stop animations before setting values when animations are involved | Eliminates environment-dependent timing for better reproducibility |
