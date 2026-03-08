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

```bash
GODOT_MTL_OFF_SCREEN=1 /Applications/Godot.app/Contents/MacOS/Godot \
  --path misc/visual_regression/godot-vrt/tests \
  --rendering-driver metal \
  --script /path/to/capture.gd \
  -- res://random_test.tscn
```

出力: `tests/vr_screenshots/random_test.png`

## 同一性検証（seed 固定の確認）

```bash
# 1回目
cp tests/vr_screenshots/random_test.png /tmp/run1.png

# 2回目（再実行後）
cmp /tmp/run1.png tests/vr_screenshots/random_test.png && echo "IDENTICAL"
```
