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

## タイミングテストシーン（timing_test）

バーが左端から右端へ 2 秒かけて移動するアニメーションを持つシーン。
撮影タイミングを変えることで、異なる位置のバーが記録される。

### delay_ms を使ったバリエーション

各ストーリーはシーンを独立してロードし直す。
`delay_ms` に応じてバーの位置が変わることを確認できる。

| story name | delay_ms | 期待されるバー位置 |
| --- | --- | --- |
| `delay_t0` | 0 | 左端付近 |
| `delay_t500` | 500 | 約 25% |
| `delay_t1000` | 1000 | 約 50% |
| `delay_t2000` | 2000 | 右端 |

出力:

```text
vr_screenshots/
├── timing_test_delay_t0.png
├── timing_test_delay_t500.png
├── timing_test_delay_t1000.png
└── timing_test_delay_t2000.png
```

### script を使った複数枚撮影

`timing_test_capture.vrt.gd` が 1 回のシーンロードから 3 枚を連続撮影する。

出力:

```text
vr_screenshots/
├── timing_test_multi_100ms.png
├── timing_test_multi_500ms.png
└── timing_test_multi_2000ms.png
```

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
