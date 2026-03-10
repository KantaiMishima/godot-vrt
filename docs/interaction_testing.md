# インタラクション操作のテスト

## godot-vrt はインテグレーションテストである

godot-vrt を使うにあたって、まず「このツールがテストとして何を担うのか」を
**テスティングトロフィー**の観点で理解しておくことが重要です。

テスティングトロフィー（Kent C. Dodds が提唱）は、
信頼性とコストのバランスを重視したテスト構成の考え方です。

```text
        /\
       /E2\        E2E テスト
      /----\       実機・実プレイヤー入力によるシナリオ検証
     / Integ\
    /--------\     インテグレーションテスト ← godot-vrt はここ
   /  Unit    \
  /------------\   ユニットテスト
 /   Static     \
/----------------\  静的解析
```

godot-vrt は**インテグレーションテスト**の層に位置します。
実際の Godot シーンを実レンダラで描画し、その **視覚的な出力** を比較します。

### godot-vrt が得意なこと

- UI レイアウトの崩れ（ノード位置・サイズの変化）の検出
- シーン全体のレンダリング結果の変化の検出
- 複数ノード・シェーダーが組み合わさった見た目の変化の検出
- アニメーション途中の状態や UI 操作後の状態の記録

### godot-vrt では検出できないこと

godot-vrt はスクリーンショットの比較しか行いません。
以下の問題は **他のテスト層で別途検出する**必要があります。

| 検出したい問題 | 適切なテスト層 | Godot での手段例 |
| --- | --- | --- |
| 型エラー・未定義変数・構文エラー | 静的解析 | `godot --check-only`・gdlint |
| スコア計算・当たり判定などのロジックのバグ | ユニットテスト | GUT (Godot Unit Test) |
| 実際のプレイヤー入力で正しく動くか | E2E テスト | 実機 + 入力マクロ・録画再生 |
| UI の見た目が意図せず変わっていないか | **インテグレーション（VRT）** | godot-vrt |

#### 具体例: ボタン押下でスコアが +1 される機能

```text
「ボタンを押したらスコアが増える」という機能には 3 つの側面がある:

  1. _on_button_pressed() 関数の実装が正しいか  → ユニットテスト（GUT）
  2. ボタン押下後にスコア表示が更新されているか → インテグレーション（godot-vrt）
  3. 実際のプレイヤーがクリックしても動くか      → E2E テスト
```

godot-vrt は「スコアの数字が画面に正しく表示されているか」は確認できますが、
「スコアの値が仕様通りに増えているか」はピクセル比較だけからは判断できません。
**ロジックの正しさはユニットテストで、見た目の正しさは VRT で**、と役割を分担するのが
堅牢なテスト戦略です。

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
    await session.take_screenshot("initial")

    # ボタンを押す
    scene_node.click_button(0)
    await session.take_screenshot("after_click1")

    # さらに押す
    scene_node.click_button(0)
    scene_node.click_button(0)
    await session.take_screenshot("after_click3")

    # リセットボタンを押す
    scene_node.click_button(1)
    await session.take_screenshot("after_reset")
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
├── button_test_interaction_initial.png      ← 初期状態（Count: 0）
├── button_test_interaction_after_click1.png ← 1 回押した後（Count: 1）
├── button_test_interaction_after_click3.png ← 3 回押した後（Count: 3）
└── button_test_interaction_after_reset.png  ← リセット後（Count: 0）
```

サンプル実装: [`tests/button_test.gd`](../tests/button_test.gd) /
[`tests/button_test_capture.vrt.gd`](../tests/button_test_capture.vrt.gd)

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
    await session.take_screenshot("initial")

    # 1 枚選択
    scene_node.select_card(0)
    await session.take_screenshot("card0_selected")

    # 複数選択
    scene_node.select_card(3)
    scene_node.select_card(5)
    await session.take_screenshot("multi_selected")

    # 再クリックで選択解除
    scene_node.select_card(0)
    await session.take_screenshot("card0_deselected")
```

### 出力ファイル

```text
vr_screenshots/
├── click_test_interaction_initial.png         ← 全カード未選択
├── click_test_interaction_card0_selected.png  ← カード 0 のみ選択
├── click_test_interaction_multi_selected.png  ← カード 0・3・5 を選択
└── click_test_interaction_card0_deselected.png ← カード 0 を解除（3・5 のみ）
```

サンプル実装: [`tests/click_test.gd`](../tests/click_test.gd) /
[`tests/click_test_capture.vrt.gd`](../tests/click_test_capture.vrt.gd)

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

サンプル実装: [`tests/timing_test.gd`](../tests/timing_test.gd) /
[`tests/timing_test_capture.vrt.gd`](../tests/timing_test_capture.vrt.gd)

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
    await session.take_screenshot("initial")

    # 不正解コマンド → エラー表示・演出なし
    scene_node.input_command("HELLO")
    await session.take_screenshot("wrong_command")

    # 正解コマンド → 成功演出（虹色ボーダー）が表示される
    scene_node.input_command("GODOT")
    await session.take_screenshot("success_effect")
```

### 出力ファイル

```text
vr_screenshots/
├── command_test_interaction_initial.png       ← 入力前の初期状態
├── command_test_interaction_wrong_command.png ← 不正解入力後
└── command_test_interaction_success_effect.png ← 正解入力後（演出表示）
```

サンプル実装: [`tests/command_test.gd`](../tests/command_test.gd) /
[`tests/command_test_capture.vrt.gd`](../tests/command_test_capture.vrt.gd)

---

## メソッド設計のガイドライン

`.vrt.gd` から呼び出す public メソッドを設計するときの指針:

| 指針 | 理由 |
| --- | --- |
| メソッド名は操作の意図を表す（`click_button` / `select_card`） | VRT スクリプトを読んだときに操作の内容がわかる |
| 境界チェックを入れる（範囲外 idx は無視） | 誤った引数でシーンがクラッシュしないようにする |
| `disabled` 状態のボタンは操作しない | 実際の UI と同じ制約を反映する |
| アニメーションが絡む場合は停止してから値を設定する | 環境依存のタイミングを排除して再現性を高める |
