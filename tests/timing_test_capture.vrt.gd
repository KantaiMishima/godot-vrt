extends RefCounted

## timing_test.tscn 用の外部キャプチャスクリプト
##
## 1 回のシーンロードからバーのアニメーション途中を 3 枚撮影する。
## SETTLE_FRAMES が終わった時点を起点として、以下のタイミングで撮影する:
##   - 100ms 後  → バーは左端付近
##   - 500ms 後  → バーは約 25% 地点
##   - 2000ms 後 → バーは右端（アニメーション完了）
##
## 出力ファイル名:
##   timing_test_multi_0100ms.png
##   timing_test_multi_0500ms.png
##   timing_test_multi_2000ms.png


func run(scene_node: Node, session: Object) -> void:
	await session.wait_ms(100)
	await session.take_screenshot("0100ms")

	await session.wait_ms(400)
	await session.take_screenshot("0500ms")

	await session.wait_ms(1500)
	await session.take_screenshot("2000ms")
