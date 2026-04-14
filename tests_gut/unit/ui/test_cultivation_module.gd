extends GutTest

const ModuleHarness = preload("res://tests_gut/support/module_harness.gd")

var harness: ModuleHarness = null

func before_each():
	harness = ModuleHarness.new()
	add_child(harness)
	await harness.bootstrap()

func after_each():
	if harness:
		await harness.cleanup()
		harness.free()
		harness = null
	await get_tree().process_frame

func test_cultivation_start_and_stop_use_real_api():
	var module = harness.game_ui.cultivation_module
	harness.clear_logs()

	await module.on_cultivate_button_pressed()
	assert_true(harness.get_player().get_is_cultivating(), "开始修炼后应进入修炼状态")
	assert_eq(harness.game_ui.active_mode, "cultivation", "开始修炼后应占用修炼模式")
	assert_true(harness.last_log().contains("开始修炼"), "应输出开始修炼日志")

	await get_tree().create_timer(0.25).timeout
	harness.clear_logs()
	await module.on_cultivate_button_pressed()
	assert_false(harness.get_player().get_is_cultivating(), "停止修炼后应退出修炼状态")
	assert_eq(harness.game_ui.active_mode, "none", "停止修炼后应释放修炼模式")
	assert_true(harness.last_log().contains("停止修炼"), "应输出停止修炼日志")

func test_breakthrough_related_action_flushes_pending_report_and_formats_success_text():
	await harness.apply_preset_and_sync("breakthrough_ready")
	var module = harness.game_ui.cultivation_module

	await module.on_cultivate_button_pressed()
	await get_tree().create_timer(4.2).timeout
	assert_true(module._pending_count >= 3, "应先累计待上报修炼tick")

	harness.client.clear_call_counts()
	var settled = await module.flush_pending_and_then(func(): pass)
	assert_true(settled, "突破相关操作前应能成功同步修炼增量")

	assert_eq(module._pending_count, 0, "突破前应先同步完待上报tick")
	assert_eq(harness.client.get_call_count("cultivation_report"), 1, "突破前应调用一次修炼上报")
	var breakthrough_result = await harness.client.player_breakthrough()
	assert_true(breakthrough_result.get("success", false), "突破预设应允许真实突破成功")
	assert_true(module._resolve_cultivation_result_message(breakthrough_result, "").begins_with("突破成功，消耗了"), "突破成功文案应来自 reason_code 翻译")

func test_breakthrough_failure_uses_missing_resource_copy():
	await harness.apply_preset_and_sync("breakthrough_ready")
	await harness.client.test_post("/test/set_inventory_items", {"items": {}})
	var module = harness.game_ui.cultivation_module
	var result = await harness.client.player_breakthrough()

	assert_false(result.get("success", true), "清空突破资源后服务端应返回突破失败")
	assert_true(module._resolve_cultivation_result_message(result, "").begins_with("突破失败，缺少"), "突破失败时应提示缺少的资源")

func test_cultivation_repeat_start_and_unsynced_stop_have_client_copy():
	var module = harness.game_ui.cultivation_module
	var first_start = await harness.client.cultivation_start()
	assert_true(first_start.get("success", false), "首次开始修炼应成功")
	harness.get_player().cultivation_active = true

	var start_again = await harness.client.cultivation_start()
	assert_false(start_again.get("success", true), "重复开始修炼应被服务端拒绝")
	assert_eq(module._resolve_cultivation_result_message(start_again, ""), "已在修炼状态", "重复开始修炼应使用客户端固定文案")

	module._pending_count = 2
	module._flush_in_flight = true
	harness.clear_logs()
	await module._stop_cultivation_internal(false)
	module._flush_in_flight = false

	var logs = harness.get_log_messages()
	assert_true(logs.has("修炼同步异常，正在尝试停止修炼"), "同步异常时应提示正在尝试停止")
	assert_true(harness.last_log().contains("停止修炼"), "同步异常后仍应允许停止修炼")
	assert_false(harness.get_player().get_is_cultivating(), "同步异常后点击停止修炼应成功退出修炼状态")

func test_cultivation_respects_mode_lock_message():
	harness.game_ui.set_active_mode("alchemy")
	var enter_check = harness.game_ui.can_enter_mode("cultivation")
	assert_eq(enter_check.get("message", ""), "请先停止炼丹", "修炼应遵循主界面模式互斥提示")

func test_cultivation_time_invalid_logs_once_per_invalid_report():
	var module = harness.game_ui.cultivation_module
	var start_result = await harness.client.cultivation_start()
	assert_true(start_result.get("success", false), "开始修炼应成功")
	harness.get_player().cultivation_active = true

	harness.clear_logs()
	module._pending_count = 5
	var first_flush_ok = await module._flush_pending_report()
	assert_false(first_flush_ok, "立即上报应触发时间校验失败")

	module._pending_count = 5
	var second_flush_ok = await module._flush_pending_report()
	assert_false(second_flush_ok, "连续立即上报应继续失败")

	var hit_count := 0
	for msg in harness.get_log_messages():
		if str(msg).contains("修炼同步异常，请稍后重试"):
			hit_count += 1
	assert_eq(hit_count, 2, "每次非法上报应各提示一次")

func test_cultivation_invalid_report_waits_for_next_window_without_immediate_retry():
	var module = harness.game_ui.cultivation_module
	var start_result = await harness.client.cultivation_start()
	assert_true(start_result.get("success", false), "开始修炼应成功")
	harness.get_player().cultivation_active = true

	harness.client.clear_call_counts()
	module._pending_count = 5
	var first_flush_ok = await module._flush_pending_report()
	assert_false(first_flush_ok, "立即上报应触发时间校验失败")
	assert_eq(harness.client.get_call_count("cultivation_report"), 1, "失败后应只有本次上报请求")
	assert_true(module._pending_count >= 5, "失败后 pending 不应被清空")

	# 在下一次 5 秒窗口到达前，process 不应立即再次上报。
	await module._process(0.1)
	await get_tree().process_frame
	assert_eq(harness.client.get_call_count("cultivation_report"), 1, "失败后应等待下一个上报窗口，不做立即重试")
