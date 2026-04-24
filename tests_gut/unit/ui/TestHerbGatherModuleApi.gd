extends GutTest

const MODULE_HARNESS = preload("res://tests_gut/support/ModuleHarness.gd")

var harness: ModuleHarness = null

func before_each():
	harness = MODULE_HARNESS.new()
	add_child(harness)
	await harness.bootstrap("http://localhost:8444/api", "")

func after_each():
	if harness:
		await harness.cleanup()
		harness.free()
		harness = null
	await get_tree().process_frame

func _module():
	return harness.game_ui.herb_gather_module

func test_herb_cards_render_and_button_state():
	harness.game_ui.show_herb_gather_panel()
	await _module()._refresh_points()

	assert_true(_module().point_list.get_child_count() >= 2, "应渲染至少两个采集点卡片")
	assert_true(_module()._card_refs.has("point_low_yield"), "应包含低产采集点")
	assert_true(_module()._card_refs.has("point_high_yield"), "应包含高产采集点")
	var low_refs = _module()._card_refs["point_low_yield"]
	assert_false(low_refs["start"].disabled, "未采集状态下开始按钮可点击")
	assert_true(low_refs["stop"].disabled, "未采集状态下停止按钮不可点击")

func test_herb_start_blocked_by_cultivation_message():
	await harness.client.test_post("/test/set_runtime_state", {"is_cultivating": true})
	await harness.sync_full_state()
	harness.game_ui.show_herb_gather_panel()
	await _module()._refresh_points()
	harness.clear_logs()

	await _module()._on_start_pressed("point_low_yield")
	assert_eq(harness.last_log(), "正在修炼中，无法开始采集", "修炼中开始采集应提示互斥文案")

func test_herb_start_report_and_stop_flow():
	await harness.client.test_post("/test/reset_account", {})
	await harness.sync_full_state()
	harness.game_ui.show_herb_gather_panel()
	await _module()._refresh_points()
	harness.clear_logs()

	await _module()._on_start_pressed("point_low_yield")
	assert_true(_module()._is_gathering, "开始采集后应进入采集状态")

	# 构造可上报时间，避免触发时间校验失败。
	await harness.client.test_post("/test/set_runtime_state", {
		"is_gathering": true,
		"current_herb_point_id": "point_low_yield",
		"herb_elapsed_seconds": 10
	})
	await _module()._do_report_once()

	var log_text = harness.last_log()
	assert_true(
		log_text == "采集获得" or log_text == "本轮采集失败",
		"上报后应输出采集结果文案，实际: %s" % log_text
	)

	await _module()._on_stop_pressed()
	assert_false(_module()._is_gathering, "停止采集后应退出采集状态")
	assert_eq(harness.last_log(), "停止采集", "停止采集应输出固定文案")
