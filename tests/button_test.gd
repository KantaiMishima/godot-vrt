extends Control

## ボタン操作テスト用シーン
##
## ボタン押下によって UI の状態が変わることを VRT で確認する例。
## `click_button(idx)` を呼び出すとカウンターが増減し、ボタンの状態変化が記録される。
##
## ボタン一覧:
##   0: Count Up   ← 押すたびにカウンターを +1 する
##   1: Reset      ← カウンターを 0 に戻す
##   2: Disabled   ← 無効状態のボタン（操作不可）

const BG_COLOR := Color(0.10, 0.10, 0.14)
const PANEL_COLOR := Color(0.16, 0.16, 0.22)
const LABEL_COLOR := Color(0.90, 0.90, 0.95)
const COUNT_FONT_SIZE := 56
const TITLE_FONT_SIZE := 20

var _counter := 0
var _count_label: Label
var _buttons: Array[Button] = []


func _ready() -> void:
	custom_minimum_size = Vector2(1280, 720)

	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.size = Vector2(1280, 720)
	add_child(bg)

	_build_title()
	_build_counter_panel()
	_build_buttons()


func _build_title() -> void:
	var title := Label.new()
	title.text = "Button Interaction Test"
	title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	title.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	title.position = Vector2(40, 32)
	add_child(title)


func _build_counter_panel() -> void:
	var panel := ColorRect.new()
	panel.color = PANEL_COLOR
	panel.size = Vector2(480, 180)
	panel.position = Vector2(400, 200)
	add_child(panel)

	var hint := Label.new()
	hint.text = "CLICK COUNT"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.50, 0.50, 0.60))
	hint.position = Vector2(400 + 185, 215)
	add_child(hint)

	_count_label = Label.new()
	_count_label.text = "0"
	_count_label.add_theme_font_size_override("font_size", COUNT_FONT_SIZE)
	_count_label.add_theme_color_override("font_color", LABEL_COLOR)
	_count_label.position = Vector2(400 + 208, 252)
	add_child(_count_label)


func _build_buttons() -> void:
	var labels: Array[String] = ["Count Up", "Reset", "Disabled"]
	var btn_w := 200.0
	var btn_h := 56.0
	var gap := 24.0
	var total_w := btn_w * labels.size() + gap * (labels.size() - 1)
	var start_x := (1280.0 - total_w) / 2.0
	var y := 450.0

	for i: int in labels.size():
		var btn := Button.new()
		btn.text = labels[i]
		btn.size = Vector2(btn_w, btn_h)
		btn.position = Vector2(start_x + i * (btn_w + gap), y)
		if i == 2:
			btn.disabled = true
		add_child(btn)
		_buttons.append(btn)

	_buttons[0].pressed.connect(_on_count_up)
	_buttons[1].pressed.connect(_on_reset)


func _on_count_up() -> void:
	_counter += 1
	_count_label.text = str(_counter)


func _on_reset() -> void:
	_counter = 0
	_count_label.text = "0"


## ボタンをプログラム的に押す（VRT スクリプトから呼び出す）。
## idx: 0 = Count Up、1 = Reset、2 = Disabled（押下不可のため無視）
func click_button(idx: int) -> void:
	if idx < 0 or idx >= _buttons.size():
		return
	if _buttons[idx].disabled:
		return
	_buttons[idx].emit_signal("pressed")
