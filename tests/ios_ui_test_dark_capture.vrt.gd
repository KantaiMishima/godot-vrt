extends RefCounted

func run(scene: Node, session: Object) -> void:
	if scene.has_method("set_dark_mode"):
		scene.set_dark_mode(true)
	await session.wait_ms(100)
	await session.take_screenshot()
