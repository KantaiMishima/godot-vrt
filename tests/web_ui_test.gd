extends Control

## ブラウザ風 UI テストシーン
##
## Web プラットフォーム向けの UI パターンをビジュアルリグレッションテスト用に表示する。
## ヘッダーバー、レスポンシブカードグリッド、プログレスバー、
## ビューポート情報、Cookie 同意バナーを含む。

const HEADER_H := 52.0
const CARD_TITLES: Array[String] = ["Dashboard", "Analytics", "Settings", "Profile", "Messages", "Reports"]
const CARD_DESCS: Array[String] = [
	"プロジェクトの概要を確認", "アクセス解析データを表示", "アプリケーション設定を管理",
	"ユーザープロフィール編集", "受信メッセージ一覧", "レポート生成と閲覧",
]

var _progress_fill: ColorRect
var _progress_label: Label
var _fullscreen_indicator: Label
var _viewport_label: Label


func _ready() -> void:
	var s := get_viewport_rect().size
	_add_rect(Vector2.ZERO, s, Color(0.95, 0.96, 0.97))
	_build_header(s)
	_build_progress_bar(s)
	_build_card_grid(s)
	_build_viewport_info(s)
	_build_cookie_banner(s)


func set_loading_progress(t: float) -> void:
	## プログレスバーの進捗を設定（0.0〜1.0）
	t = clampf(t, 0.0, 1.0)
	_progress_fill.size.x = (get_viewport_rect().size.x - 80.0) * t
	_progress_label.text = "Loading... %d%%" % int(t * 100.0)
	_progress_label.visible = true


func set_fullscreen_mode(enabled: bool) -> void:
	## フルスクリーンモード表示の切り替え
	_fullscreen_indicator.visible = enabled
	_fullscreen_indicator.text = "[FULLSCREEN]" if enabled else ""


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


func _build_header(s: Vector2) -> void:
	_add_rect(Vector2.ZERO, Vector2(s.x, HEADER_H), Color(0.20, 0.22, 0.28))
	var symbols: Array[String] = ["<", ">", "O"]
	for i: int in symbols.size():
		var b := _add_rect(Vector2(12.0 + i * 36.0, 10.0), Vector2(30.0, 32.0), Color(0.35, 0.37, 0.43))
		var l := Label.new()
		l.text = symbols[i]
		l.add_theme_font_size_override("font_size", 14)
		l.add_theme_color_override("font_color", Color(0.80, 0.82, 0.86))
		l.position = Vector2(9.0, 6.0)
		b.add_child(l)
	var url_x := 130.0
	_add_rect(Vector2(url_x, 10.0), Vector2(s.x - url_x - 16.0, 32.0), Color(0.30, 0.32, 0.38))
	_add_label(Vector2(url_x + 10.0, 16.0), "https://example.app/dashboard", 13, Color(0.75, 0.78, 0.82))
	_fullscreen_indicator = _add_label(Vector2(s.x - 120.0, 18.0), "", 11, Color(0.9, 0.7, 0.2))
	_fullscreen_indicator.visible = false


func _build_progress_bar(s: Vector2) -> void:
	var y := HEADER_H + 16.0
	var w := s.x - 80.0
	_add_rect(Vector2(40.0, y), Vector2(w, 6.0), Color(0.85, 0.86, 0.88))
	_progress_fill = _add_rect(Vector2(40.0, y), Vector2(0.0, 6.0), Color(0.24, 0.47, 0.85))
	_progress_label = _add_label(Vector2(40.0, y + 10.0), "", 11, Color(0.50, 0.52, 0.58))
	_progress_label.visible = false


func _build_card_grid(s: Vector2) -> void:
	var top := HEADER_H + 50.0
	var margin := 40.0
	var gap := 20.0
	var avail := s.x - margin * 2.0
	var cols := 3 if avail >= 900.0 else (2 if avail >= 600.0 else 1)
	var cw := (avail - gap * (cols - 1)) / cols
	var ch := 120.0
	var accent := Color(0.24, 0.47, 0.85)
	for i: int in CARD_TITLES.size():
		var x := margin + (i % cols) * (cw + gap)
		var y := top + (i / cols) * (ch + gap)
		_add_rect(Vector2(x + 1.0, y + 2.0), Vector2(cw + 2.0, ch + 2.0), Color(0.0, 0.0, 0.0, 0.08))
		var p := _make_panel(Vector2(x, y), Vector2(cw, ch), Color(1.0, 1.0, 1.0), 8)
		var pst: StyleBoxFlat = p.get_theme_stylebox("panel")
		pst.border_color = Color(0.88, 0.89, 0.90)
		for side: String in ["border_width_top", "border_width_bottom", "border_width_left", "border_width_right"]:
			pst.set(side, 1)
		_add_rect(Vector2(x, y), Vector2(cw, 3.0), accent)
		_add_label(Vector2(x + 16.0, y + 20.0), CARD_TITLES[i], 16, Color(0.15, 0.16, 0.20))
		_add_label(Vector2(x + 16.0, y + 48.0), CARD_DESCS[i], 12, Color(0.50, 0.52, 0.58))
		var badge_color := accent if i % 2 == 0 else Color(0.50, 0.52, 0.58)
		_add_label(Vector2(x + 16.0, y + 80.0), "Active" if i % 2 == 0 else "Pending", 11, badge_color)


func _build_viewport_info(s: Vector2) -> void:
	var y := s.y - 100.0
	_make_panel(Vector2(40.0, y), Vector2(s.x - 80.0, 36.0), Color(0.90, 0.92, 0.95), 4)
	var renderer := ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown")
	_viewport_label = _add_label(
		Vector2(52.0, y + 9.0),
		"Viewport: %dx%d | Renderer: %s" % [int(s.x), int(s.y), str(renderer)],
		12, Color(0.50, 0.52, 0.58))


func _build_cookie_banner(s: Vector2) -> void:
	var bh := 52.0
	var by := s.y - bh
	_make_panel(Vector2(0.0, by), Vector2(s.x, bh), Color(0.18, 0.20, 0.26))
	_add_label(Vector2(20.0, by + 16.0), "This site uses cookies to improve your experience.", 13, Color(0.92, 0.93, 0.95))
	_make_panel(Vector2(s.x - 110.0, by + 11.0), Vector2(80.0, 30.0), Color(0.30, 0.65, 0.45), 4)
	_add_label(Vector2(s.x - 96.0, by + 16.0), "Accept", 13, Color(1.0, 1.0, 1.0))
