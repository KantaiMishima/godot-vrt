extends RefCounted

func run(scene: Node, session: Object) -> void:
	if scene.has_method("set_loading_progress"):
		scene.set_loading_progress(0.65)
	await session.wait_ms(100)
	await session.take_screenshot()
