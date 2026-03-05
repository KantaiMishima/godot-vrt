# godot-vrt

Godot アドオン — **visual regression test** の仕組みを Godot エンジンに追加します。**interaction test** サポートも今後追加予定です。

シーンのスクリーンショットをキャプチャし、基準画像と比較することで、意図しない見た目の変化を検出します。

---

## 概要

`godot-vrt` は Godot エンジン向けのアドオンです。

- シーン（`.tscn`）のスクリーンショットを自動でキャプチャする
- キャプチャした画像を基準画像と比較することで、意図しない UI/レイアウトの変化を検出できる（**visual regression test**）
- CI 環境（Linux/macOS）での実行に対応

> **比較・差分管理** は利用者側に委ねており、Argos CI / reg-suit / pixelmatch などの任意のツールと組み合わせて使います。

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

# Linux CI (Xvfb 経由)
xvfb-run godot --headless --rendering-driver vulkan --script addons/godot-vrt/capture.gd
```

キャプチャ画像は `{project}/vr_screenshots/{scene_name}.png` に保存されます（`vr` = visual regression）。

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
    │    └─ xvfb-run --rendering-driver vulkan               (Linux CI)
    │
    ├─ シーンロード → N フレーム待機（レイアウト安定化）
    │
    ├─ SubViewport::get_image() でキャプチャ
    │    └─ ビューポートサイズ固定（1280×720）
    │
    └─ PNG 保存 → {project}/vr_screenshots/{scene_name}.png

【利用者側の責務】
  任意の VRT ツールで比較
    ├─ Argos CI（OSS 無料枠あり・PR コメント自動投稿）
    ├─ reg-suit（S3/GCS に保管）
    ├─ pixelmatch（自前スクリプト）
    └─ その他
```

---

## ライセンス

[LICENSE](LICENSE) を参照してください。
