extends Control

## Web プラットフォーム向け UI テストシーン
##
## ブラウザ固有の UI パターンを VRT で確認する例:
##   - ブラウザ風タブバー（上部）
##   - Cookie 同意バナー（下部固定）
##   - タッチフレンドリーな大型ボタン
##   - レスポンシブ対応コンテンツカード
##
## `set_active_tab(idx)` でタブを切り替え、`dismiss_banner()` でバナーを非表示にする。

const BG_COLOR := Color(0.96, 0.96, 0.98)
const TAB_BG := Color(0.22, 0.22, 0.28)
const TAB_ACTIVE := Color(0.30, 0.60, 1.00)
const TAB_INACTIVE := Color(0.50, 0.50, 0.60)
const BANNER_BG := Color(0.12, 0.12, 0.18, 0.96)
const CARD_BG := Color(1.00, 1.00, 1.00)
const CARD_SHADOW := Color(0.00, 0.00, 0.00, 0.10)
const TEXT_MAIN := Color(0.10, 0.10, 0.14)
const TEXT_SUB := Color(0.45, 0.45, 0.55)
const ACCENT := Color(0.30, 0.60, 1.00)

var _active_tab := 0
var _tab_labels: Array[Label] = []
var _tab_indicators: Array[ColorRect] = []
var _banner: Control


func _ready() -> void:
	custom_minimum_size = Vector2(1280, 720)

	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.size = Vector2(1280, 720)
	add_child(bg)

	_build_tab_bar()
	_build_content()
	_build_cookie_banner()
	_update_tabs()


func _build_tab_bar() -> void:
	var bar := ColorRect.new()
	bar.color = TAB_BG
	bar.size = Vector2(1280, 52)
	bar.position = Vector2(0, 0)
	add_child(bar)

	# ブラウザアドレスバー風
	var addr_bar := ColorRect.new()
	addr_bar.color = Color(0.32, 0.32, 0.40)
	addr_bar.size = Vector2(600, 30)
	addr_bar.position = Vector2(340, 11)
	add_child(addr_bar)

	var addr_label := Label.new()
	addr_label.text = "https://example.com"
	addr_label.add_theme_font_size_override("font_size", 13)
	addr_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.90))
	addr_label.position = Vector2(360, 17)
	add_child(addr_label)

	# タブ（3 つ）
	var tab_names: Array[String] = ["Home", "Search", "Settings"]
	var tab_w := 140.0
	var start_x := 16.0

	for i: int in tab_names.size():
		var x := start_x + i * (tab_w + 4.0)

		var tab_bg := ColorRect.new()
		tab_bg.color = TAB_BG if i != _active_tab else Color(0.28, 0.28, 0.36)
		tab_bg.size = Vector2(tab_w, 52)
		tab_bg.position = Vector2(x, 0)
		add_child(tab_bg)

		var indicator := ColorRect.new()
		indicator.color = TAB_ACTIVE if i == _active_tab else Color.TRANSPARENT
		indicator.size = Vector2(tab_w, 3)
		indicator.position = Vector2(x, 0)
		add_child(indicator)
		_tab_indicators.append(indicator)

		var label := Label.new()
		label.text = tab_names[i]
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override(
			"font_color",
			Color(1.0, 1.0, 1.0) if i == _active_tab else Color(0.65, 0.65, 0.75)
		)
		label.position = Vector2(x + (tab_w - label.get_minimum_size().x) / 2.0 + 5.0, 16)
		add_child(label)
		_tab_labels.append(label)


func _build_content() -> void:
	var title := Label.new()
	title.text = "Web UI Test"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", TEXT_SUB)
	title.position = Vector2(40, 72)
	add_child(title)

	var cards_data: Array[Dictionary] = [
		{"title": "Touch Target", "body": "Buttons meet 44×44 px minimum touch target guidelines.", "accent": ACCENT},
		{"title": "Responsive Grid", "body": "Layout adapts to 375 px (mobile) / 768 px (tablet) / 1280 px (desktop).", "accent": Color(0.20, 0.75, 0.55)},
		{"title": "Web Notification", "body": "In-browser banners use ARIA live regions for accessibility.", "accent": Color(0.90, 0.45, 0.20)},
	]

	var card_w := 340.0
	var card_h := 180.0
	var gap := 32.0
	var total_w := card_w * 3.0 + gap * 2.0
	var start_x := (1280.0 - total_w) / 2.0
	var y := 112.0

	for i: int in cards_data.size():
		var d := cards_data[i]
		var x := start_x + i * (card_w + gap)

		# カード影
		var shadow := ColorRect.new()
		shadow.color = CARD_SHADOW
		shadow.size = Vector2(card_w, card_h)
		shadow.position = Vector2(x + 3, y + 4)
		add_child(shadow)

		var card := ColorRect.new()
		card.color = CARD_BG
		card.size = Vector2(card_w, card_h)
		card.position = Vector2(x, y)
		add_child(card)

		var accent_bar := ColorRect.new()
		accent_bar.color = d["accent"]
		accent_bar.size = Vector2(6, card_h)
		accent_bar.position = Vector2(x, y)
		add_child(accent_bar)

		var t := Label.new()
		t.text = d["title"]
		t.add_theme_font_size_override("font_size", 17)
		t.add_theme_color_override("font_color", TEXT_MAIN)
		t.position = Vector2(x + 22, y + 24)
		add_child(t)

		var b := Label.new()
		b.text = d["body"]
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_color_override("font_color", TEXT_SUB)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.size = Vector2(card_w - 32, 80)
		b.position = Vector2(x + 22, y + 60)
		add_child(b)

	# 大型タッチボタン
	_build_touch_buttons(start_x, y + card_h + 36.0, card_w, card_h)


func _build_touch_buttons(start_x: float, y: float, card_w: float, _card_h: float) -> void:
	var btn_data: Array[Dictionary] = [
		{"text": "Primary Action", "bg": ACCENT},
		{"text": "Secondary", "bg": Color(0.85, 0.85, 0.92)},
		{"text": "Danger", "bg": Color(0.90, 0.25, 0.25)},
	]
	var gap := 32.0
	for i: int in btn_data.size():
		var d := btn_data[i]
		var x := start_x + i * (card_w + gap)
		var btn_h := 56.0

		var bg := ColorRect.new()
		bg.color = d["bg"]
		bg.size = Vector2(card_w, btn_h)
		bg.position = Vector2(x, y)
		add_child(bg)

		var lbl := Label.new()
		lbl.text = d["text"]
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override(
			"font_color",
			Color(1, 1, 1) if i != 1 else TEXT_MAIN
		)
		lbl.position = Vector2(x + (card_w - lbl.get_minimum_size().x) / 2.0 + 5.0, y + 16)
		add_child(lbl)


func _build_cookie_banner() -> void:
	var banner := ColorRect.new()
	banner.color = BANNER_BG
	banner.size = Vector2(1280, 72)
	banner.position = Vector2(0, 648)
	add_child(banner)
	_banner = banner

	var msg := Label.new()
	msg.text = "This site uses cookies to improve your experience."
	msg.add_theme_font_size_override("font_size", 14)
	msg.add_theme_color_override("font_color", Color(0.85, 0.85, 0.90))
	msg.position = Vector2(40, 26)
	add_child(msg)

	var accept_bg := ColorRect.new()
	accept_bg.color = ACCENT
	accept_bg.size = Vector2(130, 36)
	accept_bg.position = Vector2(1060, 18)
	add_child(accept_bg)

	var accept_lbl := Label.new()
	accept_lbl.text = "Accept All"
	accept_lbl.add_theme_font_size_override("font_size", 13)
	accept_lbl.add_theme_color_override("font_color", Color.WHITE)
	accept_lbl.position = Vector2(1078, 28)
	add_child(accept_lbl)

	var reject_bg := ColorRect.new()
	reject_bg.color = Color(0.40, 0.40, 0.50)
	reject_bg.size = Vector2(130, 36)
	reject_bg.position = Vector2(1112 - 148, 18)
	add_child(reject_bg)

	var reject_lbl := Label.new()
	reject_lbl.text = "Reject"
	reject_lbl.add_theme_font_size_override("font_size", 13)
	reject_lbl.add_theme_color_override("font_color", Color.WHITE)
	reject_lbl.position = Vector2(1112 - 148 + 40, 28)
	add_child(reject_lbl)


func _update_tabs() -> void:
	for i: int in _tab_labels.size():
		var is_active := i == _active_tab
		_tab_labels[i].add_theme_color_override(
			"font_color",
			Color(1.0, 1.0, 1.0) if is_active else Color(0.65, 0.65, 0.75)
		)
		_tab_indicators[i].color = TAB_ACTIVE if is_active else Color.TRANSPARENT


## アクティブなタブを切り替える（VRT スクリプトから呼び出す）。
## idx: 0 = Home、1 = Search、2 = Settings
func set_active_tab(idx: int) -> void:
	if idx < 0 or idx >= _tab_labels.size():
		return
	_active_tab = idx
	_update_tabs()


## Cookie バナーを非表示にする（VRT スクリプトから呼び出す）。
func dismiss_banner() -> void:
	if _banner != null:
		_banner.visible = false
		for child in get_children():
			if child is Label or child is ColorRect:
				if child.position.y >= 648:
					child.visible = false
