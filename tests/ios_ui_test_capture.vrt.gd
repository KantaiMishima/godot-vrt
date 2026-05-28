extends RefCounted

func run(scene: Node, session: Object) -> void:
	if scene.has_method("set_device_style"):
		scene.set_device_style("dynamic_island")
	await session.wait_ms(100)
	await session.take_screenshot()
