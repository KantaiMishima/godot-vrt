extends RefCounted

## click_test.tscn 用の外部キャプチャスクリプト
##
## カード選択前後の状態を順番にキャプチャする。
## scene_node.select_card(idx) でクリック選択を再現する。
##
## 出力ファイル名（story 名 "interaction"）:
##   click_test_interaction_01_initial.png          ← 初期状態（全カード未選択）
##   click_test_interaction_02_card0_selected.png   ← カード 0（Alpha）を選択
##   click_test_interaction_03_multi_selected.png   ← カード 3・5 を追加選択（計 3 枚）
##   click_test_interaction_04_card0_deselected.png ← カード 0 を再クリックして解除（2 枚に）


func run(scene_node: Node, session: Object) -> void:
	# 初期状態（全カード未選択）
	await session.take_screenshot("01_initial")

	# カード 0（Alpha）を選択
	scene_node.select_card(0)
	await session.take_screenshot("02_card0_selected")

	# カード 3（Delta）とカード 5（Zeta）を追加選択
	scene_node.select_card(3)
	scene_node.select_card(5)
	await session.take_screenshot("03_multi_selected")

	# カード 0 を再クリックして選択解除（トグル）
	scene_node.select_card(0)
	await session.take_screenshot("04_card0_deselected")
