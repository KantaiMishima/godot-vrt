extends RefCounted

## button_test.tscn 用の外部キャプチャスクリプト
##
## ボタン押下前後の状態を順番にキャプチャする。
## scene_node.click_button(idx) でボタン押下を再現し、カウンター変化を記録する。
##
## 出力ファイル名（story 名 "interaction"）:
##   button_test_interaction_initial.png     ← 初期状態（Count: 0）
##   button_test_interaction_after_click1.png ← Count Up を 1 回押した後（Count: 1）
##   button_test_interaction_after_click3.png ← Count Up を計 3 回押した後（Count: 3）
##   button_test_interaction_after_reset.png  ← Reset を押した後（Count: 0）


func run(scene_node: Node, session: Object) -> void:
	# 初期状態（カウンター = 0）
	await session.take_screenshot("initial")

	# Count Up を 1 回押す
	scene_node.click_button(0)
	await session.take_screenshot("after_click1")

	# さらに 2 回押して合計 3 回
	scene_node.click_button(0)
	scene_node.click_button(0)
	await session.take_screenshot("after_click3")

	# Reset を押してカウンターを 0 に戻す
	scene_node.click_button(1)
	await session.take_screenshot("after_reset")
