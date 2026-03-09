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
## Output: {project_path}/vr_screenshots/{scene_name}_s{seed}.png

const VIEWPORT_SIZE := Vector2i(1280, 720)
const SETTLE_FRAMES := 5
const OUTPUT_DIR := "vr_screenshots"
const VRT_SEEDS: Array[int] = [12345, 99999, 42]

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

	for vrt_seed in VRT_SEEDS:
		await _capture_with_seed(scene_path, packed, output_dir, vrt_seed)


func _capture_with_seed(scene_path: String, packed: PackedScene, output_dir: String, vrt_seed: int) -> void:
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

	var img := vp.get_texture().get_image()
	if img == null or img.is_empty():
		printerr("  FAIL: image is null or empty (seed=", vrt_seed, ")")
	else:
		var file_name := scene_path.get_file().get_basename() + "_s" + str(vrt_seed) + ".png"
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
