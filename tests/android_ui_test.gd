extends Control

## Android プラットフォーム UI テストシーン
##
## Material Design 風の UI パターンをビジュアルリグレッションテスト用に表示する。
## ステータスバー、セーフエリア境界、マテリアルカードリスト、FAB、
## ボトムナビゲーション、ノッチ表示エリアを含む。

const STATUS_H := 28.0
const APP_BAR_H := 56.0
const NAV_H := 56.0
const FAB_SZ := 56.0
const NOTCH_W := 120.0
const NOTCH_H := 32.0
const PRIMARY := Color(0.24, 0.32, 0.71)
const WHITE := Color(1.0, 1.0, 1.0)
const ITEMS: Array[String] = ["Inbox", "Starred", "Sent Mail", "Drafts", "Trash"]
const SUBS: Array[String] = ["3 件の未読メッセージ", "お気に入りのメッセージ", "送信済みメール一覧", "下書き保存中のメール", "削除されたメッセージ"]
const ICONS: Array[String] = ["[M]", "[*]", "[>]", "[D]", "[X]"]
const NAV_LABELS: Array[String] = ["Home", "Search", "Profile"]
const NAV_ICONS: Array[String] = ["[H]", "[S]", "[P]"]

var _notch_rect: ColorRect


func _ready() -> void:
	var s := get_viewport_rect().size
	_add_rect(Vector2.ZERO, s, Color(0.96, 0.96, 0.98))
	_build_notch(s)
	_build_safe_area(s)
	_build_status_bar(s)
	_build_app_bar(s)
	_build_card_list(s)
	_build_fab(s)
	_build_bottom_nav(s)


func set_notch_visible(enabled: bool) -> void:
	## ノッチ（カットアウト）表示の切り替え
	_notch_rect.visible = enabled


func set_orientation(landscape: bool) -> void:
	## 画面向きフラグの設定
	pass


func _add_rect(pos: Vector2, sz: Vector2, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.size = sz
	r.position = pos
	add_child(r)
	return r


func _add_label(pos: Vector2, text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.position = pos
	add_child(l)
	return l


func _make_panel(pos: Vector2, sz: Vector2, bg: Color, radius: int = 0) -> Panel:
	var p := Panel.new()
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	for prop: String in ["corner_radius_top_left", "corner_radius_top_right", "corner_radius_bottom_left", "corner_radius_bottom_right"]:
		st.set(prop, radius)
	p.add_theme_stylebox_override("panel", st)
	p.size = sz
	p.position = pos
	add_child(p)
	return p


func _build_notch(s: Vector2) -> void:
	_notch_rect = _add_rect(Vector2((s.x - NOTCH_W) / 2.0, 0.0), Vector2(NOTCH_W, NOTCH_H), Color(0.0, 0.0, 0.0))
	_notch_rect.visible = false


func _build_safe_area(s: Vector2) -> void:
	var m := 12.0
	var top := STATUS_H + m
	var sa_color := Color(0.0, 0.8, 0.4, 0.35)
	var outline := Panel.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	st.border_color = sa_color
	for side: String in ["border_width_top", "border_width_bottom", "border_width_left", "border_width_right"]:
		st.set(side, 2)
	for c: String in ["corner_radius_top_left", "corner_radius_top_right", "corner_radius_bottom_left", "corner_radius_bottom_right"]:
		st.set(c, 4)
	outline.add_theme_stylebox_override("panel", st)
	outline.size = Vector2(s.x - m * 2.0, s.y - top - NAV_H - m)
	outline.position = Vector2(m, top)
	add_child(outline)
	_add_label(Vector2(m + 6.0, top + 2.0), "Safe Area", 10, sa_color)


func _build_status_bar(s: Vector2) -> void:
	_add_rect(Vector2.ZERO, Vector2(s.x, STATUS_H), Color(0.13, 0.14, 0.18))
	_add_label(Vector2(16.0, 6.0), "12:34", 12, WHITE)
	_add_label(Vector2(s.x - 120.0, 7.0), "|||| WiFi 85%", 11, WHITE)


func _build_app_bar(s: Vector2) -> void:
	_add_rect(Vector2(0.0, STATUS_H), Vector2(s.x, APP_BAR_H), PRIMARY)
	_add_label(Vector2(16.0, STATUS_H + 14.0), "=", 22, WHITE)
	_add_label(Vector2(56.0, STATUS_H + 16.0), "Material App", 20, WHITE)
	_add_label(Vector2(s.x - 40.0, STATUS_H + 16.0), "...", 20, WHITE)


func _build_card_list(s: Vector2) -> void:
	var top := STATUS_H + APP_BAR_H + 16.0
	var ch := 72.0
	var gap := 8.0
	var m := 16.0
	var cw := s.x - m * 2.0
	for i: int in ITEMS.size():
		var y := top + i * (ch + gap)
		_add_rect(Vector2(m + 1.0, y + 2.0), Vector2(cw + 1.0, ch + 2.0), Color(0.0, 0.0, 0.0, 0.12))
		_make_panel(Vector2(m, y), Vector2(cw, ch), WHITE, 8)
		_add_label(Vector2(m + 16.0, y + 14.0), ICONS[i], 20, PRIMARY)
		_add_label(Vector2(m + 64.0, y + 14.0), ITEMS[i], 16, Color(0.13, 0.13, 0.17))
		_add_label(Vector2(m + 64.0, y + 40.0), SUBS[i], 12, Color(0.46, 0.46, 0.52))


func _build_fab(s: Vector2) -> void:
	var fx := s.x - FAB_SZ - 24.0
	var fy := s.y - NAV_H - FAB_SZ - 24.0
	_add_rect(Vector2(fx + 2.0, fy + 3.0), Vector2(FAB_SZ + 4.0, FAB_SZ + 4.0), Color(0.0, 0.0, 0.0, 0.18))
	_make_panel(Vector2(fx, fy), Vector2(FAB_SZ, FAB_SZ), Color(0.91, 0.30, 0.24), 16)
	_add_label(Vector2(fx + 17.0, fy + 10.0), "+", 28, WHITE)


func _build_bottom_nav(s: Vector2) -> void:
	var ny := s.y - NAV_H
	var nav_p := _make_panel(Vector2(0.0, ny), Vector2(s.x, NAV_H), WHITE)
	var pst: StyleBoxFlat = nav_p.get_theme_stylebox("panel")
	pst.border_color = Color(0.88, 0.88, 0.90)
	pst.border_width_top = 1
	var tw := s.x / NAV_LABELS.size()
	for i: int in NAV_LABELS.size():
		var tx := tw * i
		var c := PRIMARY if i == 0 else Color(0.55, 0.55, 0.60)
		_add_label(Vector2(tx + tw / 2.0 - 12.0, ny + 8.0), NAV_ICONS[i], 16, c)
		_add_label(Vector2(tx + tw / 2.0 - 16.0, ny + 32.0), NAV_LABELS[i], 11, c)
