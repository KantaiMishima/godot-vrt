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
## Output: {project_path}/vr_screenshots/{scene_name}.png

const VIEWPORT_SIZE := Vector2i(1280, 720)
const SETTLE_FRAMES := 5
const OUTPUT_DIR := "vr_screenshots"

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
		printerr("  FAIL: image is null or empty")
	else:
		var file_name := scene_path.get_file().get_basename() + ".png"
		var save_path := output_dir.path_join(file_name)
		var err := img.save_png(save_path)
		if err == OK:
			print("  Saved: ", save_path)
		else:
			printerr("  FAIL: Could not save PNG (err=", err, ")")

	if is_instance_valid(scene_node):
		scene_node.queue_free()
	vp.queue_free()
	await process_frame


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
