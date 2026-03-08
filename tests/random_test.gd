extends Control

## 乱数テスト用シーン
## ランダムな位置・サイズ・色の矩形を描画する
## seed 固定されていれば毎回同じ見た目になる

func _ready() -> void:
	custom_minimum_size = Vector2(1280, 720)

	for i in 20:
		var rect := ColorRect.new()
		rect.color = Color(randf(), randf(), randf())
		rect.size = Vector2(randf_range(40, 300), randf_range(40, 200))
		rect.position = Vector2(randf_range(0, 1000), randf_range(0, 600))
		add_child(rect)
