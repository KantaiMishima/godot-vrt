# Stories 設定ファイル

## 概要

`.stories.json` はシーンごとのスクリーンショット設定を記述するファイルです。
シーンファイル（`.tscn`）と同じディレクトリに、同じファイル名ベースで配置します。

```text
res://
├── ui/
│   ├── title.tscn
│   └── title.stories.json   ← title.tscn に対応する stories 設定
└── game/
    ├── gameplay.tscn
    └── gameplay.stories.json
```

設定ファイルが存在するシーンは、ファイルに定義された seed・名前でスクリーンショットを撮影します。
設定ファイルがない場合は、seed `12345` の 1 枚だけキャプチャします。

---

## ファイル形式

```json
{
  "stories": [
    { "name": "ストーリー名", "seed": 乱数seed },
    { "name": "ストーリー名", "seed": 乱数seed }
  ]
}
```

**`stories`**: 必須。撮影するスクリーンショットの配列。

各要素のフィールド:

| フィールド | 型 | 必須 | 説明 |
| --- | --- | --- | --- |
| `name` | string | ✓ | スクリーンショットの識別名。出力ファイル名に使われる |
| `seed` | number (int) | ✓ | グローバル乱数 seed。`seed(n)` に渡す整数 |
| `delay_ms` | number (int) | - | SETTLE_FRAMES 後、撮影までの追加待機時間（ミリ秒）。省略時は 0 |
| `script` | string | - | 撮影を委任する外部 GDScript のパス（`res://` 形式）。省略時は通常キャプチャ |

---

## 出力ファイル名

| 設定 | 出力形式 |
| --- | --- |
| stories 設定なし | `{scene_name}.png` |
| stories 設定あり | `{scene_name}_{story_name}.png` |
| `script` 使用・suffix あり | `{scene_name}_{story_name}_{suffix}.png` |
| `script` 使用・suffix なし | `{scene_name}_{story_name}.png` |

---

## 記述例

### 基本例

```json
{
  "stories": [
    { "name": "default",     "seed": 12345 },
    { "name": "alternative", "seed": 99999 },
    { "name": "minimal",     "seed": 42    }
  ]
}
```

出力:

```text
vr_screenshots/
├── title_default.png
├── title_alternative.png
└── title_minimal.png
```

### delay_ms: アニメーション途中を記録する

同じ seed でシーンを繰り返しロードし、異なる待機時間で撮影します。
アニメーションが自動再生されるシーンの途中経過を記録するのに適しています。

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

出力:

```text
vr_screenshots/
├── title_t0.png
├── title_t100.png
├── title_t500.png
└── title_t2000.png
```

### script: 外部スクリプトで複数枚撮影する

1 ストーリーから複数のスクリーンショットを撮りたい場合や、
シーンへの操作（ボタン押下・状態変化など）を挟みたい場合に使います。

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

外部スクリプト（`animation_capture.vrt.gd`）の例:

```gdscript
extends RefCounted

func run(scene_node: Node, session: Object) -> void:
    # 100ms 後にスクリーンショット
    await session.wait_ms(100)
    await session.take_screenshot("100ms")

    # 合計 500ms
    await session.wait_ms(400)
    await session.take_screenshot("500ms")

    # 合計 2000ms
    await session.wait_ms(1500)
    await session.take_screenshot("2000ms")
```

出力:

```text
vr_screenshots/
├── title_animation_100ms.png
├── title_animation_500ms.png
└── title_animation_2000ms.png
```

#### VRTSession API

外部スクリプトの `run(scene_node, session)` に渡される `session` オブジェクトのメソッド:

| メソッド | 説明 |
| --- | --- |
| `await session.wait_ms(ms: float)` | 指定ミリ秒待機する |
| `await session.take_screenshot(suffix: String = "")` | スクリーンショットを保存する。suffix を省略すると `{story_name}.png` |

### UI テーマのバリエーション

```json
{
  "stories": [
    { "name": "light", "seed": 1000 },
    { "name": "dark",  "seed": 2000 }
  ]
}
```

### 単一シーン・単一 seed

1 種類だけ撮影したい場合は要素を 1 つにします。

```json
{
  "stories": [
    { "name": "fixed", "seed": 0 }
  ]
}
```

---

## delay_ms と script の使い分け

| 用途 | 推奨方法 |
| --- | --- |
| アニメーション途中の状態を複数タイミングで記録したい | `delay_ms`（シーンを毎回ロードし直す） |
| 1 回のロードで複数枚撮りたい・操作を挟みたい | `script` |
| `delay_ms` と `script` を同時指定した場合 | `script` が優先される |

---

## デフォルト挙動との使い分け

| 状況 | 推奨 |
| --- | --- |
| 乱数を使わないシーン | 設定ファイル不要（デフォルトの 1 seed でキャプチャ） |
| 乱数を使うが特定バリエーションを見たい | stories 設定でバリエーションを定義 |
| seed ではなくシーン名でスクリーンショットを管理したい | stories 設定の `name` で意味のある名前を付ける |

---

## 既存ベースライン画像との互換性

stories 設定を追加すると、出力ファイル名が変わります。

- **変更前**: `scene_name.png`
- **変更後**: `scene_name_{story_name}.png`

既存のベースライン画像と名前が一致しなくなるため、**設定追加後は基準画像を撮り直して登録し直す**必要があります。

---

## 乱数の固定範囲

`seed` で固定されるのは Godot のグローバル乱数（`randf()`, `randi()`, `randf_range()` など）です。
`RandomNumberGenerator` インスタンスや `FastNoiseLite` の seed には効きません。

それらを固定するには、シーン側に `_vrt_setup(seed: int)` フックを実装してください（詳細は [random_seed.md](random_seed.md)）。
