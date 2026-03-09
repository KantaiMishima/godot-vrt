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
設定ファイルがない場合は、デフォルトの `VRT_SEEDS`（`[12345, 99999, 42]`）でキャプチャします。

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

| フィールド | 型 | 説明 |
| --- | --- | --- |
| `name` | string | スクリーンショットの識別名。出力ファイル名に使われる |
| `seed` | number (int) | グローバル乱数 seed。`seed(n)` に渡す整数 |

---

## 出力ファイル名

stories 設定を使う場合、出力ファイル名は以下の形式になります。

```text
{scene_name}_{story_name}.png
```

設定なし（デフォルト）の場合は次の形式です。

```text
{scene_name}_s{seed}.png
```

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

## デフォルト挙動との使い分け

| 状況 | 推奨 |
| --- | --- |
| 乱数を使わないシーン | 設定ファイル不要（デフォルトの 3 種 seed でキャプチャ） |
| 乱数を使うが特定バリエーションを見たい | stories 設定でバリエーションを定義 |
| seed ではなくシーン名でスクリーンショットを管理したい | stories 設定の `name` で意味のある名前を付ける |

---

## 既存ベースライン画像との互換性

stories 設定を追加すると、出力ファイル名が変わります。

- **変更前**: `scene_name_s12345.png`, `scene_name_s99999.png`, `scene_name_s42.png`
- **変更後**: `scene_name_{story_name}.png`

既存のベースライン画像と名前が一致しなくなるため、**設定追加後は基準画像を撮り直して登録し直す**必要があります。

---

## 乱数の固定範囲

`seed` で固定されるのは Godot のグローバル乱数（`randf()`, `randi()`, `randf_range()` など）です。
`RandomNumberGenerator` インスタンスや `FastNoiseLite` の seed には効きません。

それらを固定するには、シーン側に `_vrt_setup(seed: int)` フックを実装してください（詳細は [random_seed.md](random_seed.md)）。
