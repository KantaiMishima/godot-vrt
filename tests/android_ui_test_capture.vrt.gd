extends RefCounted

## Android UI テスト用キャプチャスクリプト
##
## 以下の 4 状態を記録する:
##   01_initial       - 初期状態（Home タブ、バッジなし）
##   02_nav_search    - Search タブに切り替え
##   03_nav_notif     - Notifications タブに切り替え
##   04_fab_badge     - FAB にバッジを表示した状態

func run(scene_node: Node, session: Object) -> void:
	await session.take_screenshot("01_initial")

	scene_node.set_active_nav(1)
	await session.wait_ms(50)
	await session.take_screenshot("02_nav_search")

	scene_node.set_active_nav(2)
	await session.wait_ms(50)
	await session.take_screenshot("03_nav_notif")

	scene_node.set_active_nav(0)
	scene_node.show_fab_badge()
	await session.wait_ms(50)
	await session.take_screenshot("04_fab_badge")
