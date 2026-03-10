extends Control

## クリック操作テスト用シーン
##
## 4×2 グリッドのカードをクリックすると選択状態が切り替わる UI の例。
## `select_card(idx)` で選択状態を変更できる（複数同時選択に対応）。
##
## カードインデックス（左上から右へ、次の行へ）:
##   0  1  2  3
##   4  5  6  7

const COLS := 4
const ROWS := 2
const CARD_W := 255.0
const CARD_H := 220.0
const GAP := 20.0

const BG_COLOR := Color(0.10, 0.10, 0.14)
const CARD_DEFAULT_COLOR := Color(0.20, 0.20, 0.28)
const CARD_SELECTED_COLOR := Color(0.25, 0.65, 0.50)
const CARD_BORDER_COLOR := Color(0.35, 0.80, 0.62)
const LABEL_FONT_SIZE := 18
const TITLE_FONT_SIZE := 20

const CARD_NAMES: Array[String] = [
	"Alpha", "Beta", "Gamma", "Delta",
	"Epsilon", "Zeta", "Eta", "Theta",
]

var _cards: Array[ColorRect] = []
var _selected: Array[bool] = []


func _ready() -> void:
	custom_minimum_size = Vector2(1280, 720)

	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.size = Vector2(1280, 720)
	add_child(bg)

	_build_title()
	_build_grid()


func _build_title() -> void:
	var title := Label.new()
	title.text = "Click Interaction Test"
	title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	title.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	title.position = Vector2(40, 32)
	add_child(title)


func _build_grid() -> void:
	var total_w := CARD_W * COLS + GAP * (COLS - 1)
	var total_h := CARD_H * ROWS + GAP * (ROWS - 1)
	var start_x := (1280.0 - total_w) / 2.0
	var start_y := (720.0 - total_h) / 2.0

	for i: int in COLS * ROWS:
		var col := i % COLS
		var row := i / COLS
		var pos := Vector2(start_x + col * (CARD_W + GAP), start_y + row * (CARD_H + GAP))

		var card := ColorRect.new()
		card.color = CARD_DEFAULT_COLOR
		card.size = Vector2(CARD_W, CARD_H)
		card.position = pos
		add_child(card)
		_cards.append(card)
		_selected.append(false)

		var label := Label.new()
		label.text = CARD_NAMES[i]
		label.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
		label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.90))
		label.position = pos + Vector2(16.0, CARD_H / 2.0 - 14.0)
		add_child(label)


## カードの選択状態をトグルする（VRT スクリプトから呼び出す）。
## 選択中のカードをもう一度指定すると選択解除になる。
## idx: 0〜7（左上から右方向、次の行へ）
func select_card(idx: int) -> void:
	if idx < 0 or idx >= _cards.size():
		return
	_selected[idx] = not _selected[idx]
	_cards[idx].color = CARD_SELECTED_COLOR if _selected[idx] else CARD_DEFAULT_COLOR
