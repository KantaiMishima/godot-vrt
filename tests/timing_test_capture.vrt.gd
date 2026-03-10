extends RefCounted

## timing_test.tscn 用の外部キャプチャスクリプト
##
## scene_node.set_progress(t) でバーの位置を直接指定し、4 枚撮影する。
## アニメーション待ちを一切行わないため、環境依存なく正確な位置が記録される。
##
## 出力ファイル名（story 名 "direct"）:
##   timing_test_direct_t000.png   ← t = 0%  （左端）
##   timing_test_direct_t025.png   ← t = 25%
##   timing_test_direct_t050.png   ← t = 50%
##   timing_test_direct_t100.png   ← t = 100%（右端）


func run(scene_node: Node, session: Object) -> void:
	for t: float in [0.0, 0.25, 0.5, 1.0]:
		scene_node.set_progress(t)
		await session.take_screenshot("t%03d" % int(t * 100))
