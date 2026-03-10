extends Control

## タイミングテスト用シーン
##
## delay_ms / script によるスクリーンショットタイミング制御の検証に使う。
## バーが左から右へ 2 秒かけてスライドするアニメーションを持ち、
## 撮影タイミングによって見た目が変わることを確認できる。

const TRAVEL_DURATION := 2.0
const BG_COLOR := Color(0.08, 0.08, 0.12)
const TRACK_COLOR := Color(0.18, 0.18, 0.28)
const BAR_COLOR := Color(0.3, 0.82, 0.52)
const MARKER_COLOR := Color(0.9, 0.5, 0.2)

## トラック左端 X 座標
const TRACK_X := 40.0
## トラック右端 X 座標（バーの左端の最大位置）
const TRACK_END_X := 1160.0

var _elapsed := 0.0
var _bar: ColorRect
## 各 25%・50%・75% 地点を示すマーカー
var _markers: Array[ColorRect] = []
## set_progress() 呼び出し後にアニメーションを止めるフラグ
var _frozen := false


func _ready() -> void:
	custom_minimum_size = Vector2(1280, 720)

	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.size = Vector2(1280, 720)
	add_child(bg)

	_build_track()
	_build_markers()
	_build_bar()


func _build_track() -> void:
	var track := ColorRect.new()
	track.color = TRACK_COLOR
	track.size = Vector2(TRACK_END_X - TRACK_X + 80.0, 80.0)
	track.position = Vector2(TRACK_X, 320.0)
	add_child(track)


func _build_markers() -> void:
	for i in 3:
		var m := ColorRect.new()
		m.color = MARKER_COLOR
		m.size = Vector2(4.0, 80.0)
		m.position = Vector2(TRACK_X + (TRACK_END_X - TRACK_X) * (float(i + 1) / 4.0), 320.0)
		add_child(m)
		_markers.append(m)


func _build_bar() -> void:
	_bar = ColorRect.new()
	_bar.color = BAR_COLOR
	_bar.size = Vector2(80.0, 80.0)
	_bar.position = Vector2(TRACK_X, 320.0)
	add_child(_bar)


## バーの位置を進行率 t（0.0〜1.0）で直接セットする。
## 呼び出し後はアニメーションが停止する。
func set_progress(t: float) -> void:
	_frozen = true
	_bar.position.x = TRACK_X + t * (TRACK_END_X - TRACK_X)


func _process(delta: float) -> void:
	if _frozen:
		return
	_elapsed = minf(_elapsed + delta, TRAVEL_DURATION)
	var t := _elapsed / TRAVEL_DURATION
	_bar.position.x = TRACK_X + t * (TRACK_END_X - TRACK_X)
