extends RefCounted

## command_test.tscn 用の外部キャプチャスクリプト
##
## コマンド入力前後の状態をキャプチャする。
## scene_node.input_command(text) でコマンド入力を再現する。
##
## 出力ファイル名（story 名 "interaction"）:
##   command_test_interaction_initial.png      ← 初期状態（入力なし）
##   command_test_interaction_wrong_command.png ← 不正解コマンド入力後
##   command_test_interaction_success_effect.png ← 正解コマンド入力後（特殊演出表示）


func run(scene_node: Node, session: Object) -> void:
	# 初期状態（入力なし）
	await session.take_screenshot("initial")

	# 不正解コマンドを入力 → エラー表示、演出なし
	scene_node.input_command("HELLO")
	await session.take_screenshot("wrong_command")

	# 正解コマンドを入力 → 虹色ボーダーの成功演出が表示される
	scene_node.input_command("GODOT")
	await session.take_screenshot("success_effect")
