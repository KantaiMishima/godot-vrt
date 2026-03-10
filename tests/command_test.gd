extends Control

## コマンド入力テスト用シーン
##
## コマンド入力欄に正解コマンドを入力すると画面端に虹色ボーダーが表示される例。
## `input_command(text)` でコマンドを入力できる。
##
## 正解コマンド: "GODOT"
##   正解 → 画面端に虹色ボーダー + "SUCCESS!" ラベル
##   不正解 → ボーダーなし + "Command not found" ラベル

const CORRECT_COMMAND := "GODOT"

const BG_COLOR := Color(0.08, 0.08, 0.12)
const PANEL_COLOR := Color(0.14, 0.14, 0.20)
const INPUT_COLOR := Color(0.20, 0.20, 0.28)
const SUCCESS_COLOR := Color(0.25, 0.90, 0.55)
const ERROR_COLOR := Color(0.90, 0.35, 0.35)
const BORDER_THICKNESS := 18.0

const PANEL_W := 640.0
const PANEL_H := 260.0

var _input_label: Label
var _status_label: Label
var _effect_rects: Array[ColorRect] = []


func _ready() -> void:
	custom_minimum_size = Vector2(1280, 720)

	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.size = Vector2(1280, 720)
	add_child(bg)

	_build_title()
	_build_input_panel()
	_build_border_effect()


func _build_title() -> void:
	var title := Label.new()
	title.text = "Command Input Test"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	title.position = Vector2(40, 32)
	add_child(title)

	var hint := Label.new()
	hint.text = 'Hint: enter the correct command to trigger a special effect.'
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.45, 0.45, 0.55))
	hint.position = Vector2(40, 62)
	add_child(hint)


func _build_input_panel() -> void:
	var panel_x := (1280.0 - PANEL_W) / 2.0
	var panel_y := (720.0 - PANEL_H) / 2.0

	var panel := ColorRect.new()
	panel.color = PANEL_COLOR
	panel.size = Vector2(PANEL_W, PANEL_H)
	panel.position = Vector2(panel_x, panel_y)
	add_child(panel)

	var prompt_label := Label.new()
	prompt_label.text = "COMMAND:"
	prompt_label.add_theme_font_size_override("font_size", 13)
	prompt_label.add_theme_color_override("font_color", Color(0.50, 0.50, 0.60))
	prompt_label.position = Vector2(panel_x + 28.0, panel_y + 28.0)
	add_child(prompt_label)

	var input_bg := ColorRect.new()
	input_bg.color = INPUT_COLOR
	input_bg.size = Vector2(PANEL_W - 56.0, 52.0)
	input_bg.position = Vector2(panel_x + 28.0, panel_y + 52.0)
	add_child(input_bg)

	_input_label = Label.new()
	_input_label.text = "> _"
	_input_label.add_theme_font_size_override("font_size", 28)
	_input_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.92))
	_input_label.position = Vector2(panel_x + 40.0, panel_y + 60.0)
	add_child(_input_label)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_font_size_override("font_size", 22)
	_status_label.position = Vector2(panel_x + 28.0, panel_y + 130.0)
	add_child(_status_label)


func _build_border_effect() -> void:
	# 画面四辺を囲む虹色ボーダー（初期は非表示）
	var colors: Array[Color] = [
		Color(1.00, 0.75, 0.10),  # top: 黄
		Color(0.30, 0.90, 0.55),  # right: 緑
		Color(0.30, 0.55, 1.00),  # bottom: 青
		Color(1.00, 0.30, 0.60),  # left: ピンク
	]
	# [position, size] for top / right / bottom / left
	var rects: Array[Array] = [
		[Vector2(0.0, 0.0),                    Vector2(1280.0, BORDER_THICKNESS)],
		[Vector2(1280.0 - BORDER_THICKNESS, 0.0), Vector2(BORDER_THICKNESS, 720.0)],
		[Vector2(0.0, 720.0 - BORDER_THICKNESS), Vector2(1280.0, BORDER_THICKNESS)],
		[Vector2(0.0, 0.0),                    Vector2(BORDER_THICKNESS, 720.0)],
	]
	for i: int in 4:
		var r := ColorRect.new()
		r.color = colors[i]
		r.position = rects[i][0]
		r.size = rects[i][1]
		r.visible = false
		add_child(r)
		_effect_rects.append(r)


## コマンドを入力する（VRT スクリプトから呼び出す）。
## text が CORRECT_COMMAND（"GODOT"）と一致すると成功演出を表示する。
func input_command(text: String) -> void:
	_input_label.text = "> " + text

	if text == CORRECT_COMMAND:
		_status_label.text = "SUCCESS!"
		_status_label.add_theme_color_override("font_color", SUCCESS_COLOR)
		for r: ColorRect in _effect_rects:
			r.visible = true
	else:
		_status_label.text = "Command not found"
		_status_label.add_theme_color_override("font_color", ERROR_COLOR)
		for r: ColorRect in _effect_rects:
			r.visible = false
