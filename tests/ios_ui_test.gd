extends Control

## iOS プラットフォーム向け UI テストシーン
##
## iOS Human Interface Guidelines (HIG) パターンを VRT で確認する例:
##   - ダイナミックアイランド / ノッチ付きセーフエリア（上部）
##   - iOS スタイルのナビゲーションバー（< Back | Title | Done）
##   - リストセル（左アイコン・プライマリ・セカンダリ・シェブロン）
##   - ボトムタブバー（5 アイコン、iOS 標準レイアウト）
##   - ホームインジケーターエリア（下部）
##
## `set_active_tab(idx)` でタブを切り替え、`push_nav(title)` でナビ階層を追加する。

const VIEWPORT_W := 1280.0
const VIEWPORT_H := 720.0
const SAFE_AREA_TOP := 44.0   # ノッチ相当の高さ
const NAV_BAR_H := 44.0
const TAB_BAR_H := 49.0
const HOME_IND_H := 20.0      # ホームインジケーターエリア

const BG_COLOR := Color(0.95, 0.95, 0.97)
const NAV_BG := Color(0.97, 0.97, 0.99, 0.92)
const NAV_BORDER := Color(0.80, 0.80, 0.85)
const TAB_BG := Color(0.97, 0.97, 0.99, 0.95)
const ACTIVE_BLUE := Color(0.00, 0.48, 1.00)
const INACTIVE_GRAY := Color(0.56, 0.56, 0.58)
const LIST_BG := Color(1.00, 1.00, 1.00)
const LIST_DIVIDER := Color(0.88, 0.88, 0.90)
const TEXT_MAIN := Color(0.00, 0.00, 0.00)
const TEXT_SUB := Color(0.42, 0.42, 0.45)
const HOME_IND_COLOR := Color(0.10, 0.10, 0.10)

var _tab_labels: Array[Label] = []
var _active_tab := 0
var _nav_title_label: Label
var _nav_back_label: Label
var _nav_stack: Array[String] = ["Home"]


func _ready() -> void:
	custom_minimum_size = Vector2(VIEWPORT_W, VIEWPORT_H)

	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.size = Vector2(VIEWPORT_W, VIEWPORT_H)
	add_child(bg)

	_build_dynamic_island()
	_build_nav_bar()
	_build_list_content()
	_build_tab_bar()
	_build_home_indicator()
	_update_tabs()


func _build_dynamic_island() -> void:
	# セーフエリア（ノッチ相当）背景
	var safe_bg := ColorRect.new()
	safe_bg.color = Color(0.08, 0.08, 0.10)
	safe_bg.size = Vector2(VIEWPORT_W, SAFE_AREA_TOP)
	add_child(safe_bg)

	# ダイナミックアイランド（中央の丸い切り欠き）
	var island := ColorRect.new()
	island.color = Color(0.04, 0.04, 0.06)
	island.size = Vector2(120, 28)
	island.position = Vector2((VIEWPORT_W - 120) / 2.0, 8)
	add_child(island)

	# ステータスバーの時刻とアイコン
	var time_lbl := Label.new()
	time_lbl.text = "9:41"
	time_lbl.add_theme_font_size_override("font_size", 14)
	time_lbl.add_theme_color_override("font_color", Color.WHITE)
	time_lbl.position = Vector2(28, 13)
	add_child(time_lbl)

	var status_lbl := Label.new()
	status_lbl.text = "●●●  WiFi  100%"
	status_lbl.add_theme_font_size_override("font_size", 12)
	status_lbl.add_theme_color_override("font_color", Color.WHITE)
	status_lbl.position = Vector2(VIEWPORT_W - 160, 14)
	add_child(status_lbl)


func _build_nav_bar() -> void:
	var nav_y := SAFE_AREA_TOP

	var nav_bg := ColorRect.new()
	nav_bg.color = NAV_BG
	nav_bg.size = Vector2(VIEWPORT_W, NAV_BAR_H)
	nav_bg.position = Vector2(0, nav_y)
	add_child(nav_bg)

	var nav_border := ColorRect.new()
	nav_border.color = NAV_BORDER
	nav_border.size = Vector2(VIEWPORT_W, 1)
	nav_border.position = Vector2(0, nav_y + NAV_BAR_H)
	add_child(nav_border)

	_nav_back_label = Label.new()
	_nav_back_label.text = "< Back"
	_nav_back_label.add_theme_font_size_override("font_size", 16)
	_nav_back_label.add_theme_color_override("font_color", ACTIVE_BLUE)
	_nav_back_label.position = Vector2(16, nav_y + 12)
	_nav_back_label.visible = _nav_stack.size() > 1
	add_child(_nav_back_label)

	_nav_title_label = Label.new()
	_nav_title_label.text = _nav_stack.back()
	_nav_title_label.add_theme_font_size_override("font_size", 17)
	_nav_title_label.add_theme_color_override("font_color", TEXT_MAIN)
	_nav_title_label.position = Vector2(VIEWPORT_W / 2.0 - 30, nav_y + 12)
	add_child(_nav_title_label)

	var done_lbl := Label.new()
	done_lbl.text = "Done"
	done_lbl.add_theme_font_size_override("font_size", 16)
	done_lbl.add_theme_color_override("font_color", ACTIVE_BLUE)
	done_lbl.position = Vector2(VIEWPORT_W - 60, nav_y + 12)
	add_child(done_lbl)


func _build_list_content() -> void:
	var content_y := SAFE_AREA_TOP + NAV_BAR_H + 16.0
	var content_w := 800.0
	var content_x := (VIEWPORT_W - content_w) / 2.0

	var section_lbl := Label.new()
	section_lbl.text = "SECTION HEADER"
	section_lbl.add_theme_font_size_override("font_size", 12)
	section_lbl.add_theme_color_override("font_color", TEXT_SUB)
	section_lbl.position = Vector2(content_x + 16, content_y)
	add_child(section_lbl)

	var items: Array[Dictionary] = [
		{"icon": "◉", "primary": "Notifications", "secondary": "Badges, Sounds, Banners"},
		{"icon": "◈", "primary": "Privacy & Security", "secondary": "Location, Contacts, Camera"},
		{"icon": "◆", "primary": "General", "secondary": "About, Software Update"},
		{"icon": "◇", "primary": "Display & Brightness", "secondary": "Dark Mode, Text Size"},
		{"icon": "◎", "primary": "Accessibility", "secondary": "VoiceOver, Display & Text Size"},
	]

	var item_h := 56.0
	var list_y := content_y + 24.0

	# リスト背景
	var list_bg := ColorRect.new()
	list_bg.color = LIST_BG
	list_bg.size = Vector2(content_w, item_h * items.size())
	list_bg.position = Vector2(content_x, list_y)
	add_child(list_bg)

	for i: int in items.size():
		var d := items[i]
		var iy := list_y + i * item_h

		if i > 0:
			var div := ColorRect.new()
			div.color = LIST_DIVIDER
			div.size = Vector2(content_w - 56, 1)
			div.position = Vector2(content_x + 56, iy)
			add_child(div)

		var icon_lbl := Label.new()
		icon_lbl.text = d["icon"]
		icon_lbl.add_theme_font_size_override("font_size", 22)
		icon_lbl.add_theme_color_override("font_color", ACTIVE_BLUE)
		icon_lbl.position = Vector2(content_x + 14, iy + 14)
		add_child(icon_lbl)

		var primary := Label.new()
		primary.text = d["primary"]
		primary.add_theme_font_size_override("font_size", 16)
		primary.add_theme_color_override("font_color", TEXT_MAIN)
		primary.position = Vector2(content_x + 56, iy + 8)
		add_child(primary)

		var secondary := Label.new()
		secondary.text = d["secondary"]
		secondary.add_theme_font_size_override("font_size", 12)
		secondary.add_theme_color_override("font_color", TEXT_SUB)
		secondary.position = Vector2(content_x + 56, iy + 32)
		add_child(secondary)

		var chevron := Label.new()
		chevron.text = "›"
		chevron.add_theme_font_size_override("font_size", 20)
		chevron.add_theme_color_override("font_color", Color(0.78, 0.78, 0.80))
		chevron.position = Vector2(content_x + content_w - 24, iy + 16)
		add_child(chevron)


func _build_tab_bar() -> void:
	var tab_y := VIEWPORT_H - HOME_IND_H - TAB_BAR_H

	var border := ColorRect.new()
	border.color = NAV_BORDER
	border.size = Vector2(VIEWPORT_W, 1)
	border.position = Vector2(0, tab_y)
	add_child(border)

	var tab_bg := ColorRect.new()
	tab_bg.color = TAB_BG
	tab_bg.size = Vector2(VIEWPORT_W, TAB_BAR_H)
	tab_bg.position = Vector2(0, tab_y)
	add_child(tab_bg)

	var tabs: Array[String] = ["Home", "Search", "＋", "Bell", "Profile"]
	var tab_w := VIEWPORT_W / tabs.size()

	for i: int in tabs.size():
		var x := i * tab_w + tab_w / 2.0

		var lbl := Label.new()
		lbl.text = tabs[i]
		lbl.add_theme_font_size_override("font_size", i == 2 and 1 or 11)
		lbl.add_theme_color_override("font_color", INACTIVE_GRAY)
		lbl.position = Vector2(x - 16, tab_y + 24)
		add_child(lbl)
		_tab_labels.append(lbl)


func _build_home_indicator() -> void:
	var home_y := VIEWPORT_H - HOME_IND_H

	var home_bg := ColorRect.new()
	home_bg.color = Color(0.95, 0.95, 0.97)
	home_bg.size = Vector2(VIEWPORT_W, HOME_IND_H)
	home_bg.position = Vector2(0, home_y)
	add_child(home_bg)

	var ind := ColorRect.new()
	ind.color = HOME_IND_COLOR
	ind.size = Vector2(140, 5)
	ind.position = Vector2((VIEWPORT_W - 140) / 2.0, home_y + 8)
	add_child(ind)


func _update_tabs() -> void:
	for i: int in _tab_labels.size():
		_tab_labels[i].add_theme_color_override(
			"font_color",
			ACTIVE_BLUE if i == _active_tab else INACTIVE_GRAY
		)


## ボトムタブバーのアクティブ項目を切り替える（VRT スクリプトから呼び出す）。
## idx: 0 = Home、1 = Search、2 = New Post、3 = Notifications、4 = Profile
func set_active_tab(idx: int) -> void:
	if idx < 0 or idx >= _tab_labels.size():
		return
	_active_tab = idx
	_update_tabs()


## ナビゲーション階層を追加する（VRT スクリプトから呼び出す）。
## title: 新しい画面のタイトル
func push_nav(title: String) -> void:
	_nav_stack.append(title)
	_nav_title_label.text = title
	_nav_back_label.visible = true
