extends RefCounted

## iOS UI テスト用キャプチャスクリプト
##
## 以下の 4 状態を記録する:
##   01_initial       - 初期状態（Home タブ、Home 画面）
##   02_tab_search    - Search タブに切り替え
##   03_nav_push      - Privacy & Security 画面に遷移（Back ボタンあり）
##   04_tab_profile   - Profile タブに切り替え

func run(scene_node: Node, session: Object) -> void:
	await session.take_screenshot("01_initial")

	scene_node.set_active_tab(1)
	await session.wait_ms(50)
	await session.take_screenshot("02_tab_search")

	scene_node.set_active_tab(0)
	scene_node.push_nav("Privacy & Security")
	await session.wait_ms(50)
	await session.take_screenshot("03_nav_push")

	scene_node.set_active_tab(4)
	await session.wait_ms(50)
	await session.take_screenshot("04_tab_profile")
