# godot-vrt - Claude Code Instructions

## Markdown

Markdown ファイルを作成・編集するときは markdownlint のルールに従うこと。

- **MD024**: 同じ内容の見出しを複数使わない。繰り返す場合はインライン bold に変更する
- **MD036**: 見出しの代わりに emphasis (`**text**`) を単独行で使わない。
  見出しが必要なら `##`〜`######` を使う。
  小見出し相当の内容は `**label:** 説明文` のようにインラインで書く
- **MD040**: コードフェンスには必ず言語を指定する（例: `bash`, `gdscript`, `text`）
- **MD060**: テーブルの各セルはパイプの両側にスペースを入れる（`| content |`）。
  セパレーターも `| --- | --- |` とする
- spell checker の `Information` レベルは技術用語の誤検知が多いため無視してよい

## GDScript

- Godot 4.x の GDScript を使う
- 型アノテーションを付ける（`: Type`, `-> Type`）
