extends RefCounted

func run(scene: Node, session: Object) -> void:
	if scene.has_method("set_notch_visible"):
		scene.set_notch_visible(true)
	await session.wait_ms(100)
	await session.take_screenshot()
