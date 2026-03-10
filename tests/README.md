# godot-vrt 開発用テストプロジェクト

`capture.gd` の動作検証に使うサンプルシーン群。
このディレクトリ自体が Godot プロジェクト（`project.godot` を含む）として実行可能。

## ディレクトリ構成

```text
tests/
  project.godot                    # Godot プロジェクト設定
  random_test.gd                   # 乱数テスト用スクリプト
  random_test.tscn                 # 乱数テスト用シーン（randf/randi を使用）
  random_test.stories.json         # seed バリエーション設定
  random_dots_test.gd              # 円描画テスト用スクリプト
  random_dots_test.tscn            # 円描画テスト用シーン
  timing_test.gd                   # タイミングテスト用スクリプト
  timing_test.tscn                 # タイミングテスト用シーン（スライドアニメーション）
  timing_test.stories.json         # delay_ms / script 設定
  timing_test_capture.vrt.gd       # timing_test 用外部キャプチャスクリプト
  vr_screenshots/                  # capture.gd の出力先
```

## テストシーン一覧

| シーン | 内容 | 検証項目 |
| --- | --- | --- |
| `random_test.tscn` | ランダムな位置・色・サイズの矩形 20 個 | Pattern 1（グローバル seed 固定） |
| `random_dots_test.tscn` | ランダムな位置・半径・色の円 40 個 | stories 設定なし・デフォルト seed |
| `timing_test.tscn` | 2 秒かけてスライドするバー | `delay_ms`・`script` によるタイミング制御 |
| `button_test.tscn` | カウンターボタン + disabled ボタン | ボタン押下前後の状態変化 |
| `click_test.tscn` | 4×2 カードグリッド | クリックによる選択状態切り替え |
| `command_test.tscn` | コマンド入力エリア + 成功エフェクト | コマンド入力成功時の特殊演出 |

インタラクション操作テスト（`button_test`・`click_test`・`command_test`）の詳細は
[`docs/interaction_testing.md`](../docs/interaction_testing.md) を参照してください。

## タイミングテストシーン（timing_test）

バーが左端から右端へ 2 秒かけて移動するアニメーションを持つシーン。
`delay_ms` と `direct` の 2 種類のアプローチで撮影タイミングを制御する。

### delay_ms を使ったバリエーション

各ストーリーはシーンを独立してロードし直す。
`delay_ms` に応じてバーの位置が変わることを確認できる。

| story name | delay_ms | 期待されるバー位置 |
| --- | --- | --- |
| `delay_t0000` | 0 | 左端付近 |
| `delay_t0500` | 500 | 約 25% |
| `delay_t1000` | 1000 | 約 50% |
| `delay_t2000` | 2000 | 右端 |

出力:

```text
vr_screenshots/
├── timing_test_delay_t0000.png
├── timing_test_delay_t0500.png
├── timing_test_delay_t1000.png
└── timing_test_delay_t2000.png
```

### direct アプローチ（直接位置指定）

`timing_test_capture.vrt.gd` が `scene_node.set_progress(t)` を呼び出し、
バーの位置を直接セットして 4 枚撮影する。アニメーション待ちを一切行わないため、
`delay_ms` と異なり実行環境の速度に依存しない。

`set_progress(t)` を呼び出すとアニメーションが停止し、次のフレームでも位置が維持される。

| story name | t | 期待されるバー位置 |
| --- | --- | --- |
| `direct` | 0.00 | 左端（0%） |
| `direct` | 0.25 | 25% 地点 |
| `direct` | 0.50 | 50% 地点 |
| `direct` | 1.00 | 右端（100%） |

出力:

```text
vr_screenshots/
├── timing_test_direct_t000.png
├── timing_test_direct_t025.png
├── timing_test_direct_t050.png
└── timing_test_direct_t100.png
```

## ボタン操作テストシーン（button_test）

カウンターとボタン 3 つ（Count Up / Reset / Disabled）を持つシーン。
`click_button(idx)` を呼び出してボタン押下を再現し、状態変化を記録する。

| 出力ファイル | 説明 |
| --- | --- |
| `button_test_interaction_01_initial.png` | 初期状態（Count: 0） |
| `button_test_interaction_02_after_click1.png` | Count Up を 1 回押した後（Count: 1） |
| `button_test_interaction_03_after_click3.png` | Count Up を計 3 回押した後（Count: 3） |
| `button_test_interaction_04_after_reset.png` | Reset を押した後（Count: 0） |

## クリック操作テストシーン（click_test）

4×2 グリッドのカードを持つシーン。
`select_card(idx)` でクリック選択を再現し、複数選択・選択解除の状態変化を記録する。

| 出力ファイル | 説明 |
| --- | --- |
| `click_test_interaction_01_initial.png` | 初期状態（全カード未選択） |
| `click_test_interaction_02_card0_selected.png` | カード 0 を選択 |
| `click_test_interaction_03_multi_selected.png` | カード 0・3・5 を選択 |
| `click_test_interaction_04_card0_deselected.png` | カード 0 を再クリックして解除 |

## コマンド入力テストシーン（command_test）

コマンド入力欄と成功エフェクト（画面端の虹色ボーダー）を持つシーン。
`input_command(text)` でコマンド入力を再現する。
正解コマンドは `"GODOT"`。

| 出力ファイル | 説明 |
| --- | --- |
| `command_test_interaction_01_initial.png` | 初期状態（入力なし） |
| `command_test_interaction_02_wrong_command.png` | 不正解コマンド（`"HELLO"`）入力後 |
| `command_test_interaction_03_success_effect.png` | 正解コマンド（`"GODOT"`）入力後（演出表示） |

## 実行方法

**macOS:**

```bash
GODOT_MTL_OFF_SCREEN=1 /Applications/Godot.app/Contents/MacOS/Godot \
  --path misc/visual_regression/godot-vrt/tests \
  --rendering-driver metal \
  --fixed-fps 60 \
  --script /path/to/capture.gd \
  -- res://random_test.tscn
```

**Linux (Xvfb + OpenGL3 ソフトウェアレンダリング):**

```bash
# 依存パッケージ（未インストールの場合）
sudo apt-get install -y xvfb libgl1-mesa-dri

xvfb-run godot \
  --path /path/to/godot-vrt/tests \
  --rendering-driver opengl3 \
  --fixed-fps 60 \
  --script /path/to/capture.gd
```

**タイミングテストのみ実行:**

```bash
xvfb-run godot \
  --path /path/to/godot-vrt/tests \
  --rendering-driver opengl3 \
  --fixed-fps 60 \
  --script /path/to/capture.gd \
  -- res://timing_test.tscn
```

## 同一性検証（seed 固定の確認）

同じ seed は再実行しても同一ファイルになることを確認する。

```bash
# 1回目
cp tests/vr_screenshots/random_test_s12345.png /tmp/run1_s12345.png

# 2回目（再実行後）
cmp /tmp/run1_s12345.png tests/vr_screenshots/random_test_s12345.png && echo "IDENTICAL"
```

## seed による差異確認

3 つの seed で出力が異なることを確認する。

```bash
cmp tests/vr_screenshots/random_test_s12345.png \
    tests/vr_screenshots/random_test_s99999.png \
    && echo "SAME (unexpected)" || echo "DIFFERENT (expected)"
```
