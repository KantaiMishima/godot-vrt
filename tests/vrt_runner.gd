extends Node

## エクスポートビルド用 VRT ランナー

const DEFAULT_VIEWPORT_SIZE := Vector2i(1280, 720)
const SETTLE_FRAMES := 5
const OUTPUT_DIR := "vr_screenshots"
const VRT_DEFAULT_SEED: int = 12345
const STORIES_EXT := ".stories.json"
const SCENE_MANIFEST := "res://vrt_scenes.json"

## Web エクスポートではブラウザの仮想 FS が quit 時に破棄されるため、
## キャプチャした PNG を同一オリジンのローカルサーバーへ HTTP POST する。
const UPLOAD_PATH := "/__vrt_upload/"

var _http: HTTPRequest = null
var _upload_base: String = ""


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
		else:
			printerr("  FAIL: Could not save PNG (", name, ", err=", err, ")")


func _ready() -> void:
	# _ready 内ではシーンツリーが子の構築中で add_child() が失敗するため、
	# 1 フレーム待ってから処理を開始する
	await get_tree().process_frame

	print("=== Godot VRT Runner (Export Build) ===")
	print("OS: ", OS.get_name())
	print("Project: ", ProjectSettings.globalize_path("res://"))
	print("User data dir: ", OS.get_user_data_dir())

	var args := OS.get_cmdline_user_args()
	var scenes: Array[String] = []

	if args.size() > 0:
		scenes.assign(args)
	else:
		scenes = _find_all_scenes()

	if scenes.is_empty():
		printerr("No scenes found.")
		get_tree().quit(1)
		return

	print("Scenes to capture: ", scenes.size())

	var output_dir := OS.get_user_data_dir().path_join(OUTPUT_DIR)
	print("Output dir: ", output_dir)
	DirAccess.make_dir_recursive_absolute(output_dir)

	var dir_check := DirAccess.open(output_dir)
	if dir_check == null:
		printerr("FAIL: Could not open output dir: ", output_dir)
		printerr("DirAccess error: ", DirAccess.get_open_error())
	else:
		print("Output dir opened OK")

	_clear_output_dir(output_dir)

	_setup_uploader()

	for scene_path in scenes:
		await _capture_scene(scene_path, output_dir)

	# Web: 仮想 FS が quit 時に破棄される前にローカルサーバーへ送信する
	if not _upload_base.is_empty():
		await _upload_all(output_dir)

	print("=== Done ===")
	get_tree().quit(0)


## アップロード先のベース URL を決定し、必要なら HTTPRequest を準備する。
## Web エクスポートのみ同一オリジンへアップロードする。
func _setup_uploader() -> void:
	_upload_base = _get_upload_base_url()
	if _upload_base.is_empty():
		return
	_http = HTTPRequest.new()
	add_child(_http)
	print("HTTP upload enabled: ", _upload_base)


func _get_upload_base_url() -> String:
	if OS.has_feature("web"):
		var origin: Variant = JavaScriptBridge.eval("location.origin", true)
		if origin is String and not (origin as String).is_empty():
			return origin
	return ""


## 出力ディレクトリ内の全 PNG をローカルサーバーへ POST する。
func _upload_all(output_dir: String) -> void:
	var dir := DirAccess.open(output_dir)
	if dir == null:
		printerr("Upload: could not open ", output_dir)
		return
	var count := 0
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".png"):
			if await _upload_file(output_dir.path_join(fname), fname):
				count += 1
		fname = dir.get_next()
	dir.list_dir_end()
	print("Uploaded ", count, " screenshots")


func _upload_file(path: String, fname: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		printerr("  Upload FAIL: cannot read ", fname)
		return false
	var bytes := file.get_buffer(file.get_length())
	file.close()

	var url := _upload_base + UPLOAD_PATH + fname.uri_encode()
	var err := _http.request_raw(url, ["Content-Type: image/png"], HTTPClient.METHOD_POST, bytes)
	if err != OK:
		printerr("  Upload FAIL: request error ", err, " for ", fname)
		return false

	var result: Array = await _http.request_completed
	var code: int = result[1]
	if code == 200:
		print("  Uploaded: ", fname)
		return true
	printerr("  Upload FAIL: HTTP ", code, " for ", fname)
	return false


func _capture_scene(scene_path: String, output_dir: String) -> void:
	print("\nCapturing: ", scene_path)

	var packed: PackedScene = load(scene_path)
	if packed == null:
		printerr("  FAIL: Could not load scene: ", scene_path)
		return

	var stories := _load_stories(scene_path)

	if stories.is_empty():
		await _capture_with_story(scene_path, packed, output_dir,
				{"name": "", "seed": VRT_DEFAULT_SEED, "delay_ms": 0, "script": "", "viewport_size": DEFAULT_VIEWPORT_SIZE})
	else:
		print("  Stories config: ", stories.size(), " stories")
		for story in stories:
			await _capture_with_story(scene_path, packed, output_dir, story)


func _capture_with_story(scene_path: String, packed: PackedScene, output_dir: String, story: Dictionary) -> void:
	var vrt_seed: int = story["seed"]
	var story_name: String = story["name"]
	var delay_ms: int = story.get("delay_ms", 0)
	var script_path: String = story.get("script", "")
	var vp_size: Vector2i = story.get("viewport_size", DEFAULT_VIEWPORT_SIZE)

	seed(vrt_seed)

	var vp := SubViewport.new()
	vp.size = vp_size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	get_tree().root.add_child(vp)

	var scene_node := packed.instantiate()
	vp.add_child(scene_node)

	for i in SETTLE_FRAMES:
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
				print("  Saved: ", save_path, " (seed=", vrt_seed, ")")
			else:
				printerr("  FAIL: Could not save PNG (err=", err, ", seed=", vrt_seed, ")")

	if is_instance_valid(scene_node):
		scene_node.queue_free()
	vp.queue_free()
	await get_tree().process_frame


func _clear_output_dir(output_dir: String) -> void:
	var dir := DirAccess.open(output_dir)
	if dir == null:
		return
	print("Clearing output directory: ", output_dir)
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".png"):
			var err := dir.remove(file_name)
			if err == OK:
				print("  Removed: ", file_name)
			else:
				printerr("  WARN: Could not remove: ", file_name, " (err=", err, ")")
		file_name = dir.get_next()
	dir.list_dir_end()


func _load_stories(scene_path: String) -> Array[Dictionary]:
	var config_path := scene_path.get_basename() + STORIES_EXT
	if not FileAccess.file_exists(config_path):
		return []

	var file := FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		printerr("  WARN: Could not open stories config: ", config_path)
		return []

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		printerr("  WARN: Invalid JSON in stories config (line ", json.get_error_line(), "): ", config_path)
		return []

	var data: Variant = json.data
	if not data is Dictionary or not data.has("stories"):
		printerr("  WARN: stories config must have a 'stories' array: ", config_path)
		return []

	var stories_raw: Variant = data["stories"]
	if not stories_raw is Array:
		printerr("  WARN: 'stories' must be an array: ", config_path)
		return []

	var stories: Array[Dictionary] = []
	for entry: Variant in stories_raw:
		if not entry is Dictionary:
			printerr("  WARN: Each story must be an object, skipping entry")
			continue
		if not entry.has("name") or not entry.has("seed"):
			printerr("  WARN: Each story must have 'name' and 'seed', skipping entry")
			continue
		var story_name: String = str(entry["name"])
		var story_seed: int = int(entry["seed"])
		var delay_ms: int = int(entry.get("delay_ms", 0))
		var script_path: String = str(entry.get("script", ""))
		var vp_size := DEFAULT_VIEWPORT_SIZE
		if entry.has("viewport_size"):
			var vp_raw: Variant = entry["viewport_size"]
			if vp_raw is Array and vp_raw.size() == 2:
				vp_size = Vector2i(int(vp_raw[0]), int(vp_raw[1]))
		stories.append({
			"name": story_name,
			"seed": story_seed,
			"delay_ms": delay_ms,
			"script": script_path,
			"viewport_size": vp_size,
		})

	return stories


func _find_all_scenes() -> Array[String]:
	var result: Array[String] = []
	_scan_dir("res://", result)
	if result.is_empty():
		# エクスポートビルドでは DirAccess で res:// を列挙できないため
		# マニフェストファイルから読み込む
		result = _load_scene_manifest()
	return result


func _load_scene_manifest() -> Array[String]:
	var result: Array[String] = []
	if not FileAccess.file_exists(SCENE_MANIFEST):
		printerr("Scene manifest not found: ", SCENE_MANIFEST)
		return result

	var file := FileAccess.open(SCENE_MANIFEST, FileAccess.READ)
	if file == null:
		printerr("Could not open scene manifest: ", SCENE_MANIFEST)
		return result

	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		printerr("Invalid JSON in scene manifest: ", SCENE_MANIFEST)
		return result

	var data: Variant = json.data
	if data is Dictionary and data.has("scenes") and data["scenes"] is Array:
		for entry: Variant in data["scenes"]:
			if entry is String:
				result.append(entry)
		print("Loaded ", result.size(), " scenes from manifest")
	else:
		printerr("Scene manifest must have a 'scenes' array: ", SCENE_MANIFEST)

	return result


func _scan_dir(path: String, result: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full := path.path_join(name)
		if dir.current_is_dir():
			_scan_dir(full, result)
		elif name.ends_with(".tscn") and name != "vrt_runner.tscn":
			result.append(full)
		name = dir.get_next()
	dir.list_dir_end()
