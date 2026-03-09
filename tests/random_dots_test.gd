extends Control

## stories 設定なし・デフォルト seed テスト用シーン
## ランダムな位置・半径・色の円を Canvas に描画する
## seed が固定されていれば毎回同じ見た目になる

const DOT_COUNT := 40
const BG_COLOR := Color(0.1, 0.1, 0.15)

var _dots: Array[Dictionary] = []


func _ready() -> void:
	custom_minimum_size = Vector2(1280, 720)
	for i in DOT_COUNT:
		_dots.append({
			"pos":    Vector2(randf_range(40.0, 1240.0), randf_range(40.0, 680.0)),
			"radius": randf_range(10.0, 60.0),
			"color":  Color(randf(), randf(), randf(), randf_range(0.6, 1.0)),
		})
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), BG_COLOR)
	for dot: Dictionary in _dots:
		draw_circle(dot["pos"], dot["radius"], dot["color"])
