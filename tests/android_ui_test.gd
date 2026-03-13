extends Control

## Android プラットフォーム向け UI テストシーン
##
## Material Design 3 パターンを VRT で確認する例:
##   - ステータスバー（バッテリー・WiFi・時刻）
##   - マテリアルカード（コンテンツエリア）
##   - ボトムナビゲーションバー（4 アイコン）
##   - フローティングアクションボタン（FAB）
##
## `set_active_nav(idx)` でナビを切り替え、`show_fab_badge()` で通知バッジを表示する。

const STATUS_BAR_H := 28.0
const NAV_BAR_H := 64.0
const VIEWPORT_W := 1280.0
const VIEWPORT_H := 720.0

const BG_COLOR := Color(0.95, 0.95, 0.97)
const STATUS_BG := Color(0.10, 0.10, 0.14)
const NAV_BG := Color(0.98, 0.98, 1.00)
const NAV_DIVIDER := Color(0.85, 0.85, 0.90)
const ACTIVE_COLOR := Color(0.25, 0.55, 0.95)
const INACTIVE_COLOR := Color(0.55, 0.55, 0.65)
const CARD_BG := Color(1.00, 1.00, 1.00)
const FAB_COLOR := Color(0.25, 0.55, 0.95)
const TEXT_MAIN := Color(0.08, 0.08, 0.12)
const TEXT_SUB := Color(0.45, 0.45, 0.55)

var _nav_labels: Array[Label] = []
var _nav_dots: Array[ColorRect] = []
var _active_nav := 0
var _fab_badge: ColorRect


func _ready() -> void:
	custom_minimum_size = Vector2(VIEWPORT_W, VIEWPORT_H)

	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.size = Vector2(VIEWPORT_W, VIEWPORT_H)
	add_child(bg)

	_build_status_bar()
	_build_content()
	_build_bottom_nav()
	_build_fab()
	_update_nav()


func _build_status_bar() -> void:
	var bar := ColorRect.new()
	bar.color = STATUS_BG
	bar.size = Vector2(VIEWPORT_W, STATUS_BAR_H)
	add_child(bar)

	var time_lbl := Label.new()
	time_lbl.text = "9:41"
	time_lbl.add_theme_font_size_override("font_size", 14)
	time_lbl.add_theme_color_override("font_color", Color.WHITE)
	time_lbl.position = Vector2(20, 5)
	add_child(time_lbl)

	var icons_lbl := Label.new()
	icons_lbl.text = "WiFi  BT  88%"
	icons_lbl.add_theme_font_size_override("font_size", 12)
	icons_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.90))
	icons_lbl.position = Vector2(VIEWPORT_W - 140, 6)
	add_child(icons_lbl)


func _build_content() -> void:
	var content_y := STATUS_BAR_H + 16.0
	var content_h := VIEWPORT_H - STATUS_BAR_H - NAV_BAR_H - 32.0

	var title := Label.new()
	title.text = "Android UI Test"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", TEXT_MAIN)
	title.position = Vector2(32, content_y)
	add_child(title)

	var cards_data: Array[Dictionary] = [
		{
			"title": "Material Card",
			"body": "Elevation with shadow, rounded corners, ripple on tap.",
			"tag": "Enabled",
			"tag_color": Color(0.20, 0.70, 0.40),
		},
		{
			"title": "List Item",
			"body": "Leading icon, primary text, secondary text, trailing chevron.",
			"tag": "New",
			"tag_color": ACTIVE_COLOR,
		},
		{
			"title": "Chip Group",
			"body": "Filter chips with active/inactive states and close icon.",
			"tag": "Beta",
			"tag_color": Color(0.80, 0.45, 0.10),
		},
	]

	var card_w := 340.0
	var card_h := content_h - 56.0
	var gap := 32.0
	var total_w := card_w * 3.0 + gap * 2.0
	var start_x := (VIEWPORT_W - total_w) / 2.0
	var card_y := content_y + 56.0

	for i: int in cards_data.size():
		var d := cards_data[i]
		var x := start_x + i * (card_w + gap)
		_build_card(x, card_y, card_w, card_h, d)


func _build_card(x: float, y: float, w: float, h: float, d: Dictionary) -> void:
	# 影
	var shadow := ColorRect.new()
	shadow.color = Color(0.00, 0.00, 0.00, 0.08)
	shadow.size = Vector2(w, h)
	shadow.position = Vector2(x + 4, y + 4)
	add_child(shadow)

	var card := ColorRect.new()
	card.color = CARD_BG
	card.size = Vector2(w, h)
	card.position = Vector2(x, y)
	add_child(card)

	# タグ
	var tag_bg := ColorRect.new()
	tag_bg.color = d["tag_color"]
	tag_bg.size = Vector2(72, 24)
	tag_bg.position = Vector2(x + 20, y + 16)
	add_child(tag_bg)

	var tag_lbl := Label.new()
	tag_lbl.text = d["tag"]
	tag_lbl.add_theme_font_size_override("font_size", 11)
	tag_lbl.add_theme_color_override("font_color", Color.WHITE)
	tag_lbl.position = Vector2(x + 28, y + 19)
	add_child(tag_lbl)

	var t := Label.new()
	t.text = d["title"]
	t.add_theme_font_size_override("font_size", 18)
	t.add_theme_color_override("font_color", TEXT_MAIN)
	t.position = Vector2(x + 20, y + 56)
	add_child(t)

	var b := Label.new()
	b.text = d["body"]
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", TEXT_SUB)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.size = Vector2(w - 40, 100)
	b.position = Vector2(x + 20, y + 92)
	add_child(b)

	# 区切り線
	var divider := ColorRect.new()
	divider.color = Color(0.90, 0.90, 0.94)
	divider.size = Vector2(w - 40, 1)
	divider.position = Vector2(x + 20, y + h - 56)
	add_child(divider)

	# アクションボタン
	var btn_lbl := Label.new()
	btn_lbl.text = "LEARN MORE  →"
	btn_lbl.add_theme_font_size_override("font_size", 13)
	btn_lbl.add_theme_color_override("font_color", ACTIVE_COLOR)
	btn_lbl.position = Vector2(x + 20, y + h - 40)
	add_child(btn_lbl)


func _build_bottom_nav() -> void:
	var divider := ColorRect.new()
	divider.color = NAV_DIVIDER
	divider.size = Vector2(VIEWPORT_W, 1)
	divider.position = Vector2(0, VIEWPORT_H - NAV_BAR_H)
	add_child(divider)

	var bar := ColorRect.new()
	bar.color = NAV_BG
	bar.size = Vector2(VIEWPORT_W, NAV_BAR_H)
	bar.position = Vector2(0, VIEWPORT_H - NAV_BAR_H)
	add_child(bar)

	var nav_items: Array[String] = ["Home", "Search", "Notif", "Profile"]
	var item_w := VIEWPORT_W / nav_items.size()

	for i: int in nav_items.size():
		var x := i * item_w + item_w / 2.0

		var dot := ColorRect.new()
		dot.size = Vector2(64, 32)
		dot.position = Vector2(x - 32, VIEWPORT_H - NAV_BAR_H + 6)
		dot.color = Color(ACTIVE_COLOR, 0.15)
		add_child(dot)
		_nav_dots.append(dot)

		var lbl := Label.new()
		lbl.text = nav_items[i]
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", INACTIVE_COLOR)
		lbl.position = Vector2(x - 20, VIEWPORT_H - NAV_BAR_H + 42)
		add_child(lbl)
		_nav_labels.append(lbl)


func _build_fab() -> void:
	var fab := ColorRect.new()
	fab.color = FAB_COLOR
	fab.size = Vector2(56, 56)
	fab.position = Vector2(VIEWPORT_W - 80, VIEWPORT_H - NAV_BAR_H - 72)
	add_child(fab)

	var fab_lbl := Label.new()
	fab_lbl.text = "+"
	fab_lbl.add_theme_font_size_override("font_size", 28)
	fab_lbl.add_theme_color_override("font_color", Color.WHITE)
	fab_lbl.position = Vector2(VIEWPORT_W - 80 + 14, VIEWPORT_H - NAV_BAR_H - 72 + 8)
	add_child(fab_lbl)

	_fab_badge = ColorRect.new()
	_fab_badge.color = Color(0.95, 0.20, 0.20)
	_fab_badge.size = Vector2(18, 18)
	_fab_badge.position = Vector2(VIEWPORT_W - 80 + 44, VIEWPORT_H - NAV_BAR_H - 72 - 4)
	_fab_badge.visible = false
	add_child(_fab_badge)

	var badge_num := Label.new()
	badge_num.text = "3"
	badge_num.add_theme_font_size_override("font_size", 11)
	badge_num.add_theme_color_override("font_color", Color.WHITE)
	badge_num.position = Vector2(VIEWPORT_W - 80 + 49, VIEWPORT_H - NAV_BAR_H - 72 - 1)
	_fab_badge.add_child(badge_num)


func _update_nav() -> void:
	for i: int in _nav_labels.size():
		var is_active := i == _active_nav
		_nav_labels[i].add_theme_color_override(
			"font_color",
			ACTIVE_COLOR if is_active else INACTIVE_COLOR
		)
		_nav_dots[i].visible = is_active


## ボトムナビのアクティブ項目を切り替える（VRT スクリプトから呼び出す）。
## idx: 0 = Home、1 = Search、2 = Notifications、3 = Profile
func set_active_nav(idx: int) -> void:
	if idx < 0 or idx >= _nav_labels.size():
		return
	_active_nav = idx
	_update_nav()


## FAB に通知バッジを表示する（VRT スクリプトから呼び出す）。
func show_fab_badge() -> void:
	_fab_badge.visible = true
