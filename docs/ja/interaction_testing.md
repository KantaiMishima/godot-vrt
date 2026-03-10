# インタラクション操作のテスト

> godot-vrt がテスト戦略全体でどこに位置するかは
> [README.ja.md — テスティングトロフィーにおける位置づけ](../../README.ja.md#テスティングトロフィーにおける位置づけ) を参照してください。

---

## インタラクション操作のパターン

godot-vrt はヘッドレス環境（画面なし）で実行されるため、
**実際のマウスイベントやキーボードイベントは不安定**です。

代わりに、シーン側に操作を再現する **public メソッドを公開**し、
`.vrt.gd` スクリプトからそれを呼び出すパターンを推奨します。

```gdscript
# シーン側: public メソッドを公開する
func click_button(idx: int) -> void:
    _buttons[idx].emit_signal("pressed")

# .vrt.gd 側: メソッドを呼び出して操作を再現する
func run(scene_node: Node, session: Object) -> void:
    scene_node.click_button(0)
    await session.take_screenshot("after_click")
```

このパターンは環境依存が少なく、CI 環境でも確実に動作します。

---

## パターン 1: ボタン操作

Godot の `Button` ノードを押下する操作を再現します。

### シーン側の実装

`emit_signal("pressed")` でボタン押下を再現します。
`disabled` なボタンは除外することで実際の UI の制約も反映できます。

```gdscript
# button_test.gd（抜粋）
var _buttons: Array[Button] = []

func click_button(idx: int) -> void:
    if idx < 0 or idx >= _buttons.size():
        return
    if _buttons[idx].disabled:
        return
    _buttons[idx].emit_signal("pressed")
```

### `.vrt.gd` 側の実装

```gdscript
# button_test_capture.vrt.gd
extends RefCounted

func run(scene_node: Node, session: Object) -> void:
    # 初期状態
    await session.take_screenshot("01_initial")

    # ボタンを押す
    scene_node.click_button(0)
    await session.take_screenshot("02_after_click1")

    # さらに押す
    scene_node.click_button(0)
    scene_node.click_button(0)
    await session.take_screenshot("03_after_click3")

    # リセットボタンを押す
    scene_node.click_button(1)
    await session.take_screenshot("04_after_reset")
```

### `.stories.json` の設定

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

### 出力ファイル

```text
vr_screenshots/
├── button_test_interaction_01_initial.png      ← 初期状態（Count: 0）
├── button_test_interaction_02_after_click1.png ← 1 回押した後（Count: 1）
├── button_test_interaction_03_after_click3.png ← 3 回押した後（Count: 3）
└── button_test_interaction_04_after_reset.png  ← リセット後（Count: 0）
```

サンプル実装: [`tests/button_test.gd`](../../tests/button_test.gd) /
[`tests/button_test_capture.vrt.gd`](../../tests/button_test_capture.vrt.gd)

---

## パターン 2: クリック操作

`Button` ではなく、カードやタイルなど **汎用コントロールへのクリック**を再現します。
選択状態のトグルや、クリックによる見た目の変化を記録するケースに対応します。

### シーン側の実装

選択状態を管理するメソッドを公開します。

```gdscript
# click_test.gd（抜粋）
var _cards: Array[ColorRect] = []
var _selected: Array[bool] = []

func select_card(idx: int) -> void:
    if idx < 0 or idx >= _cards.size():
        return
    _selected[idx] = not _selected[idx]
    _cards[idx].color = CARD_SELECTED_COLOR if _selected[idx] else CARD_DEFAULT_COLOR
```

### `.vrt.gd` 側の実装

```gdscript
# click_test_capture.vrt.gd
extends RefCounted

func run(scene_node: Node, session: Object) -> void:
    # 初期状態（全未選択）
    await session.take_screenshot("01_initial")

    # 1 枚選択
    scene_node.select_card(0)
    await session.take_screenshot("02_card0_selected")

    # 複数選択
    scene_node.select_card(3)
    scene_node.select_card(5)
    await session.take_screenshot("03_multi_selected")

    # 再クリックで選択解除
    scene_node.select_card(0)
    await session.take_screenshot("04_card0_deselected")
```

### 出力ファイル

```text
vr_screenshots/
├── click_test_interaction_01_initial.png          ← 全カード未選択
├── click_test_interaction_02_card0_selected.png   ← カード 0 のみ選択
├── click_test_interaction_03_multi_selected.png   ← カード 0・3・5 を選択
└── click_test_interaction_04_card0_deselected.png ← カード 0 を解除（3・5 のみ）
```

サンプル実装: [`tests/click_test.gd`](../../tests/click_test.gd) /
[`tests/click_test_capture.vrt.gd`](../../tests/click_test_capture.vrt.gd)

---

## パターン 3: UI 上の値操作

スライダー・プログレスバー・入力フィールドなど、**数値や状態を持つ UI 要素**の変化を記録します。

### シーン側の実装

値を外部から設定できるメソッドを公開します。

```gdscript
# timing_test.gd（抜粋）
func set_progress(t: float) -> void:
    _bar.position.x = t * (_track_width - _bar_width)
    _tween.kill()  # アニメーションを停止して位置を固定
```

### `.vrt.gd` 側の実装

```gdscript
# timing_test_capture.vrt.gd（既存）
extends RefCounted

func run(scene_node: Node, session: Object) -> void:
    for t: float in [0.0, 0.25, 0.5, 1.0]:
        scene_node.set_progress(t)
        await session.take_screenshot("t%03d" % int(t * 100))
```

**ポイント:** `delay_ms` によるアニメーション待ちと異なり、
値を直接指定するためレンダリング速度に依存せず再現性が高い。

詳細は `delay_ms` と `script` の使い分けを参照してください（[stories_config.md](stories_config.md)）。

サンプル実装: [`tests/timing_test.gd`](../../tests/timing_test.gd) /
[`tests/timing_test_capture.vrt.gd`](../../tests/timing_test_capture.vrt.gd)

---

## パターン 4: コマンド入力で特殊演出

テキスト入力やキーシーケンスに反応して **特殊な視覚演出が表示される**操作を記録します。
正解/不正解の両方をキャプチャすることで、演出の有無を視覚的に比較できます。

### シーン側の実装

コマンド入力と演出表示を担うメソッドを公開します。

```gdscript
# command_test.gd（抜粋）
const CORRECT_COMMAND := "GODOT"

func input_command(text: String) -> void:
    _input_label.text = "> " + text

    if text == CORRECT_COMMAND:
        _status_label.text = "SUCCESS!"
        for r: ColorRect in _effect_rects:
            r.visible = true      # 虹色ボーダーを表示
    else:
        _status_label.text = "Command not found"
        for r: ColorRect in _effect_rects:
            r.visible = false
```

### `.vrt.gd` 側の実装

```gdscript
# command_test_capture.vrt.gd
extends RefCounted

func run(scene_node: Node, session: Object) -> void:
    # 初期状態
    await session.take_screenshot("01_initial")

    # 不正解コマンド → エラー表示・演出なし
    scene_node.input_command("HELLO")
    await session.take_screenshot("02_wrong_command")

    # 正解コマンド → 成功演出（虹色ボーダー）が表示される
    scene_node.input_command("GODOT")
    await session.take_screenshot("03_success_effect")
```

### 出力ファイル

```text
vr_screenshots/
├── command_test_interaction_01_initial.png        ← 入力前の初期状態
├── command_test_interaction_02_wrong_command.png  ← 不正解入力後
└── command_test_interaction_03_success_effect.png ← 正解入力後（演出表示）
```

サンプル実装: [`tests/command_test.gd`](../../tests/command_test.gd) /
[`tests/command_test_capture.vrt.gd`](../../tests/command_test_capture.vrt.gd)

---

## メソッド設計のガイドライン

`.vrt.gd` から呼び出す public メソッドを設計するときの指針:

| 指針 | 理由 |
| --- | --- |
| メソッド名は操作の意図を表す（`click_button` / `select_card`） | VRT スクリプトを読んだときに操作の内容がわかる |
| 境界チェックを入れる（範囲外 idx は無視） | 誤った引数でシーンがクラッシュしないようにする |
| `disabled` 状態のボタンは操作しない | 実際の UI と同じ制約を反映する |
| アニメーションが絡む場合は停止してから値を設定する | 環境依存のタイミングを排除して再現性を高める |
