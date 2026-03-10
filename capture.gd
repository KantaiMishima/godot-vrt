extends SceneTree

## Visual Regression Test - Capture Script
##
## Usage (対象プロジェクトの .tscn をキャプチャ):
##   GODOT_MTL_OFF_SCREEN=1 godot \
##     --path /path/to/your/project \
##     --rendering-driver metal \
##     --script /path/to/godot/tests/visual_regression/capture.gd \
##     -- res://title.tscn
##
## 引数なしの場合はプロジェクト内の全 .tscn をキャプチャ:
##   GODOT_MTL_OFF_SCREEN=1 godot \
##     --path /path/to/your/project \
##     --rendering-driver metal \
##     --script /path/to/godot/tests/visual_regression/capture.gd
##
## Output (デフォルト):  {project_path}/vr_screenshots/{scene_name}.png
## Output (stories設定): {project_path}/vr_screenshots/{scene_name}_{story_name}.png
## Output (script複数枚): {project_path}/vr_screenshots/{scene_name}_{story_name}_{suffix}.png

const VIEWPORT_SIZE := Vector2i(1280, 720)
const SETTLE_FRAMES := 5
const OUTPUT_DIR := "vr_screenshots"
const VRT_DEFAULT_SEED: int = 12345
const STORIES_EXT := ".stories.json"


## 外部スクリプト（.vrt.gd）に渡すセッションオブジェクト。
## スクリーンショットの撮影タイミングと待機をスクリプト側から制御できる。
##
## 使い方（外部スクリプト例）:
##   extends RefCounted
##   func run(scene_node: Node, session: Object) -> void:
##       await session.wait_ms(100)
##       await session.take_screenshot("100ms")
##       await session.wait_ms(400)
##       await session.take_screenshot("500ms")
class VRTSession:
	var _tree: SceneTree
	var _vp: SubViewport
	var _output_dir: String
	## "{scene}_{story}" 形式のプレフィックス（拡張子なし）
	var _prefix: String

	## ms ミリ秒待機する。
	func wait_ms(ms: float) -> void:
		await _tree.create_timer(ms / 1000.0).timeout

	## スクリーンショットを撮影して保存する。
	## suffix を指定すると "{prefix}_{suffix}.png"、省略すると "{prefix}.png"。
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


func _initialize() -> void:
	print("=== Godot Visual Regression Capture ===")
	print("Project: ", ProjectSettings.globalize_path("res://"))

	# -- 以降の引数をシーンパスとして受け取る
	var args := OS.get_cmdline_user_args()
	var scenes: Array[String] = []

	if args.size() > 0:
		scenes.assign(args)
	else:
		scenes = _find_all_scenes()

	if scenes.is_empty():
		printerr("No scenes found.")
		quit(1)
		return

	print("Scenes to capture: ", scenes.size())

	var output_dir := ProjectSettings.globalize_path("res://" + OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(output_dir)
	_clear_output_dir(output_dir)

	for scene_path in scenes:
		await _capture_scene(scene_path, output_dir)

	print("=== Done ===")
	quit(0)


func _capture_scene(scene_path: String, output_dir: String) -> void:
	print("\nCapturing: ", scene_path)

	var packed: PackedScene = load(scene_path)
	if packed == null:
		printerr("  FAIL: Could not load scene: ", scene_path)
		return

	var stories := _load_stories(scene_path)

	if stories.is_empty():
		# stories 設定なし: デフォルトの 1 seed でキャプチャ
		await _capture_with_story(scene_path, packed, output_dir,
				{"name": "", "seed": VRT_DEFAULT_SEED, "delay_ms": 0, "script": ""})
	else:
		# stories 設定あり: 設定ファイルの seed・名前・オプションを使用
		print("  Stories config: ", stories.size(), " stories")
		for story in stories:
			await _capture_with_story(scene_path, packed, output_dir, story)


func _capture_with_story(scene_path: String, packed: PackedScene, output_dir: String, story: Dictionary) -> void:
	var vrt_seed: int = story["seed"]
	var story_name: String = story["name"]
	var delay_ms: int = story.get("delay_ms", 0)
	var script_path: String = story.get("script", "")

	# Pattern 1: グローバル乱数 seed を固定（randf/randi 系を安定化）
	seed(vrt_seed)

	var vp := SubViewport.new()
	vp.size = VIEWPORT_SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	root.add_child(vp)

	var scene_node := packed.instantiate()
	vp.add_child(scene_node)

	# フレーム安定化（レイアウト・アニメーション初期化を待つ）
	for i in SETTLE_FRAMES:
		await process_frame

	var base_name := scene_path.get_file().get_basename()
	var prefix := base_name + ("_" + story_name if not story_name.is_empty() else "")

	if not script_path.is_empty():
		# 外部スクリプトに撮影タイミングを委任
		var session := VRTSession.new()
		session._tree = self
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
		# 通常キャプチャ（delay_ms 指定があれば待機してから 1 枚撮影）
		if delay_ms > 0:
			await create_timer(delay_ms / 1000.0).timeout

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
	await process_frame


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


## シーンファイルの横にある .stories.json を読み込む。
## 存在しない場合は空配列を返す。
## 返り値の各要素: { "name": String, "seed": int, "delay_ms": int, "script": String }
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
		stories.append({
			"name": story_name,
			"seed": story_seed,
			"delay_ms": delay_ms,
			"script": script_path,
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
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full := path.path_join(name)
		if dir.current_is_dir():
			_scan_dir(full, result)
		elif name.ends_with(".tscn"):
			result.append(full)
		name = dir.get_next()
	dir.list_dir_end()
