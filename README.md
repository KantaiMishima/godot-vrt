# godot-vrt

Godot アドオン — **visual regression test** の仕組みを Godot エンジンに追加します。

シーンのスクリーンショットをキャプチャし、基準画像と比較することで、意図しない見た目の変化を検出します。

---

## 概要

`godot-vrt` は Godot エンジン向けのアドオンです。

- シーン（`.tscn`）のスクリーンショットを自動でキャプチャする
- キャプチャした画像を基準画像と比較することで、意図しない UI/レイアウトの変化を検出できる（**visual regression test**）
- CI 環境（Linux/macOS）での実行に対応

> **比較・差分管理** は利用者側に委ねており、Argos CI / reg-suit / pixelmatch などの任意のツールと組み合わせて使います。

---

## テスティングトロフィーにおける位置づけ

godot-vrt は**テスティングトロフィー**（Kent C. Dodds が提唱）の
**インテグレーションテスト**層に相当します。

```text
           /\
          /E2\          E2E テスト（実機・実プレイヤー操作）
         /----\
        /      \
       / Integr \  ← ★ godot-vrt はここ
      / -ation   \      実際のシーンを実レンダラで描画して視覚的な出力を比較する
     /____________\     （カップ部分 = テスト戦略の中で最も比重が大きい層）
         |    |
         |Unit|         ユニットテスト（ロジック単体）← 茎（比重小）
         |____|
     ____________
    |   Static   |      静的解析（型チェック・lint）← 台座
    |____________|
```

この位置づけから、以下のことがわかります:

| 検出したい問題 | 適切な層 | Godot での手段例 |
| --- | --- | --- |
| 型エラー・未定義変数 | 静的解析 | `godot --check-only`・gdlint |
| スコア計算・当たり判定のロジックバグ | ユニットテスト | GUT (Godot Unit Test) |
| 実際のプレイヤー入力で正しく動くか | E2E テスト | 実機 + 入力マクロ |
| UI の見た目が意図せず変わっていないか | **インテグレーション（VRT）** | godot-vrt |

> **godot-vrt を入れれば全部 OK ではありません。**
> 静的解析・ユニットテスト・E2E テストと組み合わせることがベストプラクティスです。

---

## インストール

```bash
# プロジェクトの addons/ 配下にクローン
git clone https://github.com/KantaiMishima/godot-vrt.git addons/godot-vrt
```

---

## 使い方

```bash
# macOS (Metal オフスクリーン)
GODOT_MTL_OFF_SCREEN=1 godot --headless --rendering-driver metal --script addons/godot-vrt/capture.gd

# Linux CI (Xvfb + OpenGL3 ソフトウェアレンダリング)
xvfb-run godot --rendering-driver opengl3 --script addons/godot-vrt/capture.gd
```

キャプチャ画像は `{project}/vr_screenshots/` に保存されます（`vr` = visual regression）。

| 条件 | ファイル名 |
| --- | --- |
| stories 設定なし（デフォルト） | `{scene_name}.png` |
| stories 設定あり | `{scene_name}_{story_name}.png` |

デフォルトは seed `12345` の 1 枚を撮影します。
シーンファイルの横に `{scene_name}.stories.json` を置くと、seed・ストーリー名をシーンごとに設定できます（詳細: [docs/stories_config.md](docs/stories_config.md)）。

---

## 現状の方針

### 責務の分離

| 責務                           | 担当                                    |
| ------------------------------ | --------------------------------------- |
| シーンのスクリーンショット撮影 | **このリポジトリ**（`capture.gd`）      |
| 基準画像との差分比較・管理     | **利用者側**（任意の VRT ツール）       |

**配布形態:** 独立した addon リポジトリとして配布。ユーザーは `addons/` 配下にクローンして使います。

---

## アーキテクチャ

```text
【このリポジトリの責務】
  capture.gd
    │
    ├─ シーン列挙（.tscn を再帰探索 or 引数指定）
    │
    ├─ Godot 起動（実レンダラ付きオフスクリーン）
    │    └─ GODOT_MTL_OFF_SCREEN=1 --rendering-driver metal  (macOS)
    │    └─ xvfb-run --rendering-driver opengl3              (Linux CI)
    │
    ├─ シーンロード → N フレーム待機（レイアウト安定化）
    │
    ├─ SubViewport::get_image() でキャプチャ
    │    └─ ビューポートサイズ固定（1280×720）
    │
    ├─ .stories.json があれば読み込み（seed・ストーリー名をシーンごとに設定）
    │
    └─ PNG 保存 → {project}/vr_screenshots/{scene_name}.png
                                         or {scene_name}_{story_name}.png

【利用者側の責務】
  任意の VRT ツールで比較
    ├─ Argos CI（OSS 無料枠あり・PR コメント自動投稿）
    ├─ reg-suit（S3/GCS に保管）
    ├─ pixelmatch（自前スクリプト）
    └─ その他
```

---

## ドキュメント

| ドキュメント | 内容 |
| --- | --- |
| [docs/stories_config.md](docs/stories_config.md) | Stories 設定ファイルのフォーマットと使い方 |
| [docs/random_seed.md](docs/random_seed.md) | 乱数固定化の設計と各パターンの解説 |
| [docs/interaction_testing.md](docs/interaction_testing.md) | インタラクション操作テストのパターンと実装例 |

---

## ライセンス

[LICENSE](LICENSE) を参照してください。
