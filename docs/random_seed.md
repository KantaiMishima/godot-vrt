# 乱数固定化の設計

## 背景

VRT（Visual Regression Test）でスクリーンショットを安定的に比較するには、
**毎回同じ画像が生成される**ことが必要。
乱数を使っているシーンは実行ごとに見た目が変わるため、固定化の仕組みが必要になる。

---

## Godot の乱数の種類

| 種類 | 使い方 | seed 固定方法 |
| --- | --- | --- |
| グローバル乱数 | `randf()`, `randi()`, `randfn()` 等 | `seed(n)` |
| `RandomNumberGenerator` | `rng.randf()` 等 | `rng.seed = n` |
| `noise` (FastNoiseLite 等) | シェーダー・テクスチャ | `noise.seed = n` |

---

## 3つのパターン

### Pattern 1: capture.gd 側でグローバル seed を固定する

`capture.gd` がシーンをロードする**直前**にグローバル seed を固定する。

```gdscript
# capture.gd 内
seed(12345)
var scene_node := packed.instantiate()
vp.add_child(scene_node)
```

**メリット:** シーン側を一切修正しなくてよい。導入コストがゼロ。

**デメリット:** シーン内で `randomize()` を呼んでいると seed がリセットされて無効になる。
`RandomNumberGenerator` インスタンスや `noise.seed` には効かない。

**適用場面:** `randf()` / `randi()` をそのまま使っている小さなシーン。

---

### Pattern 2: シーン側に VRT フックメソッドを実装する

シーンに `_vrt_setup(seed: int)` メソッドを追加し、
`capture.gd` がシーンをロード後にそのメソッドを呼ぶ。

```gdscript
# シーン側（例: particle_scene.gd）
func _vrt_setup(p_seed: int) -> void:
    rng.seed = p_seed
    noise.seed = p_seed
    $AnimationPlayer.stop()  # アニメーションも止める
```

```gdscript
# capture.gd 側
var scene_node := packed.instantiate()
vp.add_child(scene_node)
if scene_node.has_method("_vrt_setup"):
    scene_node._vrt_setup(12345)
```

**メリット:** `RandomNumberGenerator` / noise / アニメーションなど何でも固定できる。
シーンごとに固定内容を柔軟にカスタマイズできる。

**デメリット:** シーン側に実装が必要（既存シーンへの追加作業が発生）。
`_vrt_setup` を持たないシーンには効かない（Pattern 1 と組み合わせ可）。

**適用場面:** パーティクル・noise テクスチャ・独自 RNG を使うシーン。

---

### Pattern 3: autoload 経由で randomize() を無効化する

autoload スクリプトで `randomize()` をオーバーライドし、
VRT 実行中は seed 固定状態を維持する。

```gdscript
# autoload: VRTContext.gd
var _vrt_mode := false

func enable_vrt_mode(p_seed: int = 12345) -> void:
    _vrt_mode = true
    seed(p_seed)

func randomize() -> void:
    if _vrt_mode:
        return  # 何もしない（seed を上書きさせない）
    super.randomize()
```

```gdscript
# capture.gd 側
VRTContext.enable_vrt_mode(12345)
var scene_node := packed.instantiate()
```

**メリット:** シーン内の `randomize()` 呼び出しを無効化できる。
既存シーンを修正せずに seed を守れる可能性が高い。

**デメリット:** `randomize()` が組み込み関数のため GDScript からの完全なオーバーライドは不可
（`RandomNumberGenerator` インスタンスの `.randomize()` には効かない）。
autoload の追加がプロジェクト側に必要で、実装コストが高い割に効果が限定的。

**適用場面:** `randomize()` のみを使っている既存シーンが多い場合の補助手段。

---

## 推奨アプローチ

**Pattern 1 + Pattern 2 の組み合わせ**が現実的。

```text
capture.gd の処理順序:
  1. seed(12345)                    ← Pattern 1: グローバル seed 固定
  2. scene_node = instantiate()
  3. vp.add_child(scene_node)
  4. if has_method("_vrt_setup"):
       _vrt_setup(12345)            ← Pattern 2: シーン側フック
  5. フレーム待機
  6. get_image()
```

- **既存シーンはそのまま** Pattern 1 でカバー
- **乱数が問題になったシーンだけ** `_vrt_setup` を追加して Pattern 2 で対処

Pattern 2 は `RandomNumberGenerator` インスタンスや noise など Pattern 1 で対処できない
ケースが実際に発生してから導入する。現時点では不要。

Pattern 3 は効果が限定的なため、今回は見送る。

---

## シーンごとの seed カスタマイズ（stories 設定）

シーンファイルの横に `.stories.json` を置くと、そのシーン専用の seed・ストーリー名を設定できます。
seed の選択は `capture.gd` が stories 設定を優先し、デフォルトの `VRT_SEEDS` は使われません。

```text
res://ui/
├── title.tscn
└── title.stories.json   ← このシーン専用の seed 定義
```

stories 設定と Pattern 1/2 の関係:

- stories 設定の各 `seed` が Pattern 1 の seed として使われる
- Pattern 2 の `_vrt_setup(seed)` にも同じ seed が渡される（Pattern 2 実装時）

詳細は [stories_config.md](stories_config.md) を参照。

---

## 現在の実装状況

| Pattern | 状態 | 備考 |
| --- | --- | --- |
| Pattern 1 | **実装済み** | `capture.gd` の `seed(vrt_seed)` で対応 |
| Pattern 2 | 未実装（将来の拡張候補） | 問題が発生したシーンに限り導入を検討 |
| Pattern 3 | 見送り | 効果が限定的 |

`capture.gd` は `VRT_SEEDS: Array[int] = [12345, 99999, 42]` を持ち、
シーンごとに全 seed でキャプチャする。出力ファイルは `{scene}_s{seed}.png`。

シーンの横に `.stories.json` を配置すると、その seed・名前が優先される。
出力ファイルは `{scene}_{story_name}.png`（詳細: [stories_config.md](stories_config.md)）。

---

## 進め方

1. `capture.gd` に `seed(vrt_seed)` を追加（Pattern 1 の実装） ← **完了**
2. 3 seed で実行し、再現性と seed 間の差異を確認 ← **完了**
3. Pattern 2 は問題が起きたシーンが出た時点で対応する
