extends GutTest

const MODULE_HARNESS = preload("res://tests_gut/support/ModuleHarness.gd")

var harness: ModuleHarness = null


func before_each():
	harness = MODULE_HARNESS.new()
	add_child(harness)
	await harness.bootstrap("http://localhost:8444/api")


func after_each():
	if harness:
		await harness.cleanup()
		harness.free()
		harness = null
	await get_tree().process_frame


func _find_header_title(node: Node) -> Label:
	if node is Label and node.name == "HeaderTitle":
		return node
	for child in node.get_children():
		var found := _find_header_title(child)
		if found:
			return found
	return null


func _task_card_titles(list_root: VBoxContainer) -> Array:
	var names: Array = []
	for child in list_root.get_children():
		var header_title := _find_header_title(child)
		if header_title:
			names.append(header_title.text)
	return names


func test_task_panel_renders_and_claim_refreshes():
	await harness.client.reset_account()
	await harness.sync_full_state()

	var module = harness.game_ui.task_module
	assert_not_null(module, "TaskModule 应初始化")

	# 完成一个新手任务并刷新列表。
	var use_pack = await harness.client.inventory_use("starter_pack")
	assert_true(use_pack.get("success", false), "应能成功打开新手礼包Ⅰ")

	await module._refresh_task_list()
	module._on_newbie_tab_pressed()
	assert_gt(module.task_list.get_child_count(), 0, "任务列表应渲染卡片")

	await module._on_claim_pressed("newbie_open_starter_pack_1")
	assert_true(harness.last_log().contains("领取成功"), "领取成功后应有日志提示")


func test_task_panel_sort_unclaimed_first_claimed_last():
	await harness.client.reset_account()
	await harness.sync_full_state()

	var module = harness.game_ui.task_module
	var use_pack = await harness.client.inventory_use("starter_pack")
	assert_true(use_pack.get("success", false), "应能先完成新手任务Ⅰ")
	await module._refresh_task_list()
	await module._on_claim_pressed("newbie_open_starter_pack_1")
	await module._refresh_task_list()
	module._on_newbie_tab_pressed()

	var titles := _task_card_titles(module.task_list)
	assert_eq(titles.size(), 3, "新手任务卡片数应为3")
	assert_eq(titles[0], "打开新手礼包Ⅱ", "未领取任务应在上方")
	assert_eq(titles[1], "打开新手礼包Ⅲ", "未领取任务应在上方")
	assert_eq(titles[2], "打开新手礼包Ⅰ", "已领取任务应下沉到底部")

