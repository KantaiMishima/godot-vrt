extends RefCounted

## Web UI テスト用キャプチャスクリプト
##
## 以下の 4 状態を記録する:
##   01_initial       - 初期状態（Home タブ、Cookie バナーあり）
##   02_tab_search    - Search タブに切り替え
##   03_tab_settings  - Settings タブに切り替え
##   04_banner_hidden - Cookie バナーを非表示にした状態

func run(scene_node: Node, session: Object) -> void:
	await session.take_screenshot("01_initial")

	scene_node.set_active_tab(1)
	await session.wait_ms(50)
	await session.take_screenshot("02_tab_search")

	scene_node.set_active_tab(2)
	await session.wait_ms(50)
	await session.take_screenshot("03_tab_settings")

	scene_node.set_active_tab(0)
	scene_node.dismiss_banner()
	await session.wait_ms(50)
	await session.take_screenshot("04_banner_hidden")
