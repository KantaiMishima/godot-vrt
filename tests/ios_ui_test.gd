extends Control

## iOS プラットフォーム UI テストシーン
##
## iOS 風の UI パターンをビジュアルリグレッションテスト用に表示する。
## Dynamic Island / ノッチ、ラージタイトルナビバー、リスト行、
## タブバー、ホームインジケータ、セーフエリア境界を含む。

const STATUS_H := 54.0
const NAV_H := 96.0
const TAB_H := 50.0
const HOME_H := 34.0
const IOS_BLUE := Color(0.0, 0.48, 1.0)
const LIST_ITEMS: Array[String] = [
	"General", "Display & Brightness", "Wallpaper", "Sounds & Haptics",
	"Focus", "Screen Time", "Notifications", "Privacy & Security",
]
const LIST_ICONS: Array[String] = ["[G]", "[D]", "[W]", "[S]", "[F]", "[T]", "[N]", "[P]"]
const TAB_LABELS: Array[String] = ["Featured", "Search", "Updates", "Settings"]
const TAB_ICONS: Array[String] = ["*", "Q", "^", "@"]

var _dark := false
var _style := "notch"
var _nodes: Array[Node] = []


func _ready() -> void:
	_rebuild()


func set_device_style(style: String) -> void:
	## デバイススタイルを設定（"notch" / "dynamic_island"）
	_style = style
	_rebuild()


func set_dark_mode(enabled: bool) -> void:
	## ダークモードの切り替え
	_dark = enabled
	_rebuild()


func _rebuild() -> void:
	for n: Node in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	var s := get_viewport_rect().size
	_bg(s)
	_safe_area(s)
	_status_area(s)
	_nav_bar(s)
	_list(s)
	_tab_bar(s)
	_home_indicator(s)


func _bg_c() -> Color:
	return Color(0.0, 0.0, 0.0) if _dark else Color(0.95, 0.95, 0.97)

func _card_c() -> Color:
	return Color(0.11, 0.11, 0.12) if _dark else Color(1.0, 1.0, 1.0)

func _txt_c() -> Color:
	return Color(1.0, 1.0, 1.0) if _dark else Color(0.0, 0.0, 0.0)

func _sec_c() -> Color:
	return Color(0.60, 0.60, 0.63) if _dark else Color(0.55, 0.55, 0.58)

func _sep_c() -> Color:
	return Color(0.25, 0.25, 0.27) if _dark else Color(0.78, 0.78, 0.80)


func _a_rect(pos: Vector2, sz: Vector2, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.size = sz
	r.position = pos
	add_child(r)
	_nodes.append(r)
	return r


func _a_label(pos: Vector2, text: String, fs: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	l.position = pos
	add_child(l)
	_nodes.append(l)
	return l


func _a_panel(pos: Vector2, sz: Vector2, bg: Color, rad: int = 0) -> Panel:
	var p := Panel.new()
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	for prop: String in ["corner_radius_top_left", "corner_radius_top_right", "corner_radius_bottom_left", "corner_radius_bottom_right"]:
		st.set(prop, rad)
	p.add_theme_stylebox_override("panel", st)
	p.size = sz
	p.position = pos
	add_child(p)
	_nodes.append(p)
	return p


func _bg(s: Vector2) -> void:
	_a_rect(Vector2.ZERO, s, _bg_c())


func _safe_area(s: Vector2) -> void:
	var sa := Color(0.0, 0.48, 1.0, 0.25)
	var m := 8.0
	var outline := Panel.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	st.border_color = sa
	for side: String in ["border_width_top", "border_width_bottom", "border_width_left", "border_width_right"]:
		st.set(side, 2)
	for c: String in ["corner_radius_top_left", "corner_radius_top_right", "corner_radius_bottom_left", "corner_radius_bottom_right"]:
		st.set(c, 6)
	outline.add_theme_stylebox_override("panel", st)
	outline.size = Vector2(s.x - m * 2.0, s.y - STATUS_H - TAB_H - HOME_H)
	outline.position = Vector2(m, STATUS_H)
	add_child(outline)
	_nodes.append(outline)
	_a_label(Vector2(m + 6.0, STATUS_H + 2.0), "Safe Area", 10, sa)


func _status_area(s: Vector2) -> void:
	_a_rect(Vector2.ZERO, Vector2(s.x, STATUS_H), _bg_c())
	_a_label(Vector2(24.0, 14.0), "9:41", 15, _txt_c())
	_a_label(Vector2(s.x - 90.0, 15.0), "5G  100%", 13, _txt_c())
	if _style == "dynamic_island":
		_a_panel(Vector2((s.x - 126.0) / 2.0, 11.0), Vector2(126.0, 37.0), Color(0.0, 0.0, 0.0), 18)
	else:
		_a_rect(Vector2((s.x - 160.0) / 2.0, 0.0), Vector2(160.0, 34.0), Color(0.0, 0.0, 0.0))


func _nav_bar(s: Vector2) -> void:
	var ny := STATUS_H
	var nav_c := Color(0.10, 0.10, 0.10, 0.90) if _dark else Color(0.97, 0.97, 0.98, 0.90)
	_a_panel(Vector2(0.0, ny), Vector2(s.x, NAV_H), nav_c)
	_a_label(Vector2(16.0, ny + 8.0), "< Back", 17, IOS_BLUE)
	_a_label(Vector2(16.0, ny + 40.0), "Settings", 34, _txt_c())


func _list(s: Vector2) -> void:
	var top := STATUS_H + NAV_H + 8.0
	var rh := 44.0
	var m := 16.0
	var rw := s.x - m * 2.0
	var avail := s.y - top - TAB_H - HOME_H - 8.0
	var cnt: int = mini(LIST_ITEMS.size(), int(avail / rh))
	_a_panel(Vector2(m, top), Vector2(rw, rh * cnt), _card_c(), 10)
	for i: int in cnt:
		var y := top + rh * i
		_a_label(Vector2(m + 12.0, y + 12.0), LIST_ICONS[i], 16, IOS_BLUE)
		_a_label(Vector2(m + 48.0, y + 11.0), LIST_ITEMS[i], 17, _txt_c())
		_a_label(Vector2(m + rw - 24.0, y + 12.0), ">", 16, _sec_c())
		if i < cnt - 1:
			_a_rect(Vector2(m + 48.0, y + rh - 0.5), Vector2(rw - 60.0, 0.5), _sep_c())


func _tab_bar(s: Vector2) -> void:
	var ty := s.y - TAB_H - HOME_H
	var tab_c := Color(0.10, 0.10, 0.10, 0.94) if _dark else Color(0.97, 0.97, 0.98, 0.94)
	_a_rect(Vector2(0.0, ty), Vector2(s.x, 0.5), _sep_c())
	_a_panel(Vector2(0.0, ty), Vector2(s.x, TAB_H), tab_c)
	var tw := s.x / TAB_LABELS.size()
	for i: int in TAB_LABELS.size():
		var x := tw * i
		var c := IOS_BLUE if i == 3 else _sec_c()
		_a_label(Vector2(x + tw / 2.0 - 6.0, ty + 5.0), TAB_ICONS[i], 20, c)
		_a_label(Vector2(x + tw / 2.0 - 18.0, ty + 30.0), TAB_LABELS[i], 10, c)


func _home_indicator(s: Vector2) -> void:
	var ay := s.y - HOME_H
	_a_rect(Vector2(0.0, ay), Vector2(s.x, HOME_H), _bg_c())
	var hi_c := Color(1.0, 1.0, 1.0, 0.3) if _dark else Color(0.0, 0.0, 0.0, 0.3)
	_a_panel(Vector2((s.x - 134.0) / 2.0, s.y - 12.0), Vector2(134.0, 5.0), hi_c, 3)
