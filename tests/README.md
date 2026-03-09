# godot-vrt 開発用テストプロジェクト

`capture.gd` の動作検証に使うサンプルシーン群。
このディレクトリ自体が Godot プロジェクト（`project.godot` を含む）として実行可能。

## ディレクトリ構成

```text
tests/
  project.godot          # Godot プロジェクト設定
  random_test.gd         # 乱数テスト用スクリプト
  random_test.tscn       # 乱数テスト用シーン（randf/randi を使用）
  vr_screenshots/        # capture.gd の出力先
```

## テストシーン一覧

| シーン | 内容 | 検証項目 |
| --- | --- | --- |
| `random_test.tscn` | ランダムな位置・色・サイズの矩形 20 個 | Pattern 1（グローバル seed 固定） |

## 実行方法

**macOS:**

```bash
GODOT_MTL_OFF_SCREEN=1 /Applications/Godot.app/Contents/MacOS/Godot \
  --path misc/visual_regression/godot-vrt/tests \
  --rendering-driver metal \
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
  --script /path/to/capture.gd
```

出力: `tests/vr_screenshots/random_test_s12345.png`, `random_test_s99999.png`, `random_test_s42.png`

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
