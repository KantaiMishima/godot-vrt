extends Node

## Platform Runner — ビルド済みプラットフォーム向け VRT ランナー
##
## Web / Android / iOS など、事前ビルドが必要なプラットフォーム上で
## Visual Regression Test のスクリーンショットを撮影するためのランナー。
##
## ## 設計方針
##
## デスクトップ環境では `capture.gd`（SceneTree スクリプト）を `--script` 引数で
## 直接渡せるが、Web / Android / iOS ではそれができない。
## そのため、このスクリプトをアタッチしたシーン (`runner.tscn`) を
## 「メインシーン」としてエクスポートする。
##
## ## シーンリストの受け取り方（プラットフォーム別）
##
## ### Web
##   URL クエリパラメータ `?scenes=res://a.tscn,res://b.tscn` から取得。
##   省略時はプロジェクト内の全 .tscn をスキャン。
##   JavaScriptBridge.eval() を使用するため HTML5 エクスポートのみ対応。
##
## ### Android / iOS
##   アプリのユーザーデータ領域に置いた設定ファイルから取得。
##   ファイルパス: user://vrt_config.json
##   フォーマット: { "scenes": ["res://a.tscn", "res://b.tscn"] }
##   省略時は全シーンをスキャン。
##
## ## スクリーンショットの保存先
##
##   Web     : JavaScript の Blob 経由でブラウザの Download フォルダ
##   Android : user://vr_screenshots/ → adb pull で回収
##   iOS     : user://vr_screenshots/ → xcrun simctl で回収
##
## ## 完了シグナル
##
##   Web     : window.__VRT_DONE__ = true をセット
##   Android : user://vrt_done ファイルを作成
##   iOS     : user://vrt_done ファイルを作成

const VIEWPORT_SIZE := Vector2i(1280, 720)
const SETTLE_FRAMES := 5
const OUTPUT_DIR := "vr_screenshots"
const VRT_DEFAULT_SEED: int = 12345
const STORIES_EXT := ".stories.json"
const CONFIG_PATH := "user://vrt_config.json"
const DONE_PATH := "user://vrt_done"


## 外部スクリプト（.vrt.gd）に渡すセッションオブジェクト。
## capture.gd の VRTSession と同じ API を提供する。
class VRTSession:
	var _tree: SceneTree
	var _vp: SubViewport
	var _output_dir: String
	var _prefix: String

	func wait_ms(ms: float) -> void:
		await _tree.create_timer(ms / 1000.0).timeout

	func take_screenshot(suffix: String = "") -> void:
		await _tree.process_frame
		var img := _vp.get_texture().get_image()
		if img == null or img.is_empty():
			printerr("  FAIL: image is null or empty (suffix=", suffix, ")")
			return
		var name := _prefix
		if not suffix.is_empty():
			name += "_" + suffix
		name += ".png"
		var err := img.save_png(_output_dir.path_join(name))
		if err == OK:
			print("  Saved: ", name)
			_maybe_push_to_web(img, name)
		else:
			printerr("  FAIL: Could not save PNG (", name, ", err=", err, ")")

	## Web エクスポートの場合、PNG を JavaScript 側に渡してダウンロードさせる。
	func _maybe_push_to_web(_img: Image, _name: String) -> void:
		if not OS.has_feature("web"):
			return
		# JavaScriptBridge 経由でダウンロードリンクを生成する方法は
		# platform_web.md の「Web スクリーンショット取得」セクションを参照。
		pass


func _ready() -> void:
	print("=== Godot VRT Platform Runner ===")
	print("Platform: ", OS.get_name())
	# _ready() から非同期処理を開始するためコルーチンを呼び出す
	_run.call_deferred()


func _run() -> void:
	var scenes := _get_scene_list()
	if scenes.is_empty():
		printerr("No scenes found.")
		_signal_done(false)
		return

	print("Scenes to capture: ", scenes.size())

	var output_dir := ProjectSettings.globalize_path("user://" + OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(output_dir)
	_clear_output_dir(output_dir)

	for scene_path in scenes:
		await _capture_scene(scene_path, output_dir)

	print("=== Done ===")
	_signal_done(true)


## プラットフォームに応じてシーンリストを取得する。
func _get_scene_list() -> Array[String]:
	if OS.has_feature("web"):
		return _get_scenes_from_url()
	else:
		return _get_scenes_from_config()


## Web: URL クエリパラメータ `?scenes=...` からシーンリストを取得する。
## 例: index.html?scenes=res://web_ui_test.tscn,res://button_test.tscn
func _get_scenes_from_url() -> Array[String]:
	var result: Array[String] = []

	if not ClassDB.class_exists("JavaScriptBridge"):
		printerr("JavaScriptBridge is not available. Falling back to full scan.")
		return _find_all_scenes()

	var js_scenes: Variant = JavaScriptBridge.eval(
		"(new URLSearchParams(location.search)).get('scenes') || ''"
	)
	var scenes_str := str(js_scenes).strip_edges()
	if scenes_str.is_empty():
		print("No scenes in URL, scanning all .tscn files...")
		return _find_all_scenes()

	for s in scenes_str.split(","):
		var trimmed := s.strip_edges()
		if not trimmed.is_empty():
			result.append(trimmed)
	return result


## Android / iOS: user://vrt_config.json からシーンリストを取得する。
## フォーマット: { "scenes": ["res://a.tscn", "res://b.tscn"] }
func _get_scenes_from_config() -> Array[String]:
	if not FileAccess.file_exists(CONFIG_PATH):
		print("Config not found at ", CONFIG_PATH, ", scanning all .tscn files...")
		return _find_all_scenes()

	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		printerr("Could not open config: ", CONFIG_PATH)
		return _find_all_scenes()

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK:
		printerr("Invalid JSON in config: ", CONFIG_PATH)
		return _find_all_scenes()

	var data: Variant = json.data
	if not data is Dictionary or not data.has("scenes"):
		printerr("Config must have 'scenes' array: ", CONFIG_PATH)
		return _find_all_scenes()

	var result: Array[String] = []
	for s: Variant in data["scenes"]:
		result.append(str(s))
	return result


func _capture_scene(scene_path: String, output_dir: String) -> void:
	print("\nCapturing: ", scene_path)

	var packed: PackedScene = load(scene_path)
	if packed == null:
		printerr("  FAIL: Could not load scene: ", scene_path)
		return

	var stories := _load_stories(scene_path)

	if stories.is_empty():
		await _capture_with_story(scene_path, packed, output_dir,
				{"name": "", "seed": VRT_DEFAULT_SEED, "delay_ms": 0, "script": ""})
	else:
		print("  Stories config: ", stories.size(), " stories")
		for story in stories:
			await _capture_with_story(scene_path, packed, output_dir, story)


func _capture_with_story(
	scene_path: String,
	packed: PackedScene,
	output_dir: String,
	story: Dictionary,
) -> void:
	var vrt_seed: int = story["seed"]
	var story_name: String = story["name"]
	var delay_ms: int = story.get("delay_ms", 0)
	var script_path: String = story.get("script", "")

	seed(vrt_seed)

	var vp := SubViewport.new()
	vp.size = VIEWPORT_SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	get_tree().root.add_child(vp)

	var scene_node := packed.instantiate()
	vp.add_child(scene_node)

	for _i in SETTLE_FRAMES:
		await get_tree().process_frame

	var base_name := scene_path.get_file().get_basename()
	var prefix := base_name + ("_" + story_name if not story_name.is_empty() else "")

	if not script_path.is_empty():
		var session := VRTSession.new()
		session._tree = get_tree()
		session._vp = vp
		session._output_dir = output_dir
		session._prefix = prefix

		var ext_script: GDScript = load(script_path)
		if ext_script == null:
			printerr("  FAIL: Could not load script: ", script_path)
		else:
			var runner: Object = ext_script.new()
			if runner.has_method("run"):
				await runner.run(scene_node, session)
			else:
				printerr("  FAIL: Script has no run() method: ", script_path)
	else:
		if delay_ms > 0:
			await get_tree().create_timer(delay_ms / 1000.0).timeout

		var img := vp.get_texture().get_image()
		if img == null or img.is_empty():
			printerr("  FAIL: image is null or empty (seed=", vrt_seed, ")")
		else:
			var file_name := prefix + ".png"
			var save_path := output_dir.path_join(file_name)
			var err := img.save_png(save_path)
			if err == OK:
				print("  Saved: ", save_path)
			else:
				printerr("  FAIL: Could not save PNG (err=", err, ")")

	if is_instance_valid(scene_node):
		scene_node.queue_free()
	vp.queue_free()
	await get_tree().process_frame


func _load_stories(scene_path: String) -> Array[Dictionary]:
	var config_path := scene_path.get_basename() + STORIES_EXT
	if not FileAccess.file_exists(config_path):
		return []

	var file := FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		return []

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK:
		return []

	var data: Variant = json.data
	if not data is Dictionary or not data.has("stories"):
		return []

	var stories_raw: Variant = data["stories"]
	if not stories_raw is Array:
		return []

	var stories: Array[Dictionary] = []
	for entry: Variant in stories_raw:
		if not entry is Dictionary:
			continue
		if not entry.has("name") or not entry.has("seed"):
			continue
		stories.append({
			"name": str(entry["name"]),
			"seed": int(entry["seed"]),
			"delay_ms": int(entry.get("delay_ms", 0)),
			"script": str(entry.get("script", "")),
		})
	return stories


func _find_all_scenes() -> Array[String]:
	var result: Array[String] = []
	_scan_dir("res://", result)
	return result


func _scan_dir(path: String, result: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not name.begins_with("."):
			var full := path.path_join(name)
			if dir.current_is_dir():
				_scan_dir(full, result)
			elif name.ends_with(".tscn"):
				result.append(full)
		name = dir.get_next()
	dir.list_dir_end()


func _clear_output_dir(output_dir: String) -> void:
	var dir := DirAccess.open(output_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".png"):
			dir.remove(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


## 完了をプラットフォームに通知する。
func _signal_done(success: bool) -> void:
	if OS.has_feature("web"):
		if ClassDB.class_exists("JavaScriptBridge"):
			var code := "window.__VRT_DONE__ = %s;" % ("true" if success else "false")
			JavaScriptBridge.eval(code)
	else:
		# Android / iOS: 完了ファイルを書き込む
		var file := FileAccess.open(DONE_PATH, FileAccess.WRITE)
		if file != null:
			file.store_string("done" if success else "error")
			file.close()
			print("Done signal written to: ", DONE_PATH)

	get_tree().quit(0 if success else 1)
