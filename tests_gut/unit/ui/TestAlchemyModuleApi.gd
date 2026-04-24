extends GutTest

const MODULE_HARNESS = preload("res://tests_gut/support/ModuleHarness.gd")

var harness: ModuleHarness = null

func before_each():
	harness = MODULE_HARNESS.new()
	add_child(harness)
	await harness.bootstrap("http://localhost:8444/api", "alchemy_ready")

func after_each():
	if harness:
		await harness.cleanup()
		harness.free()
		harness = null
	await get_tree().process_frame

func test_alchemy_insufficient_materials_block_start_with_client_copy():
	var module = harness.game_ui.alchemy_module
	var recipe_id = "health_pill"
	var materials = harness.game_ui.recipe_data.get_recipe_materials(recipe_id)
	var items := {}
	for material_id in materials.keys():
		items[str(material_id)] = 0
	await harness.client.test_post("/test/set_inventory_items", {"items": items})
	await harness.client.test_post("/test/set_player_state", {"spirit_energy": 0})
	await harness.sync_full_state()

	module._select_recipe(recipe_id)
	module.set_craft_count(1)
	harness.clear_logs()
	await module._on_craft_pressed()

	assert_eq(harness.last_log(), "灵材或灵气不足，无法开炉炼丹", "材料不足时应阻止开炉并使用客户端文案")

func test_alchemy_finish_logs_only_summary_and_no_legacy_success_copy():
	var module = harness.game_ui.alchemy_module
	var alchemy_system = harness.get_alchemy_system()
	alchemy_system.special_bonus_speed_rate = 1000.0
	module._select_recipe("health_pill")
	module.set_craft_count(1)
	harness.clear_logs()

	await module._on_craft_pressed()
	while module.is_crafting_active():
		await module._run_alchemy_tick()

	var messages = harness.get_log_messages()
	assert_true(harness.last_log().begins_with("收丹停火：成丹"), "完成后应只输出统一收丹停火汇总")
	for message in messages:
		assert_false(str(message).contains("获得丹药"), "旧的获得丹药文案应已移除")

func test_alchemy_material_labels_turn_red_and_block_when_resources_missing():
	var module = harness.game_ui.alchemy_module
	var recipe_id = "health_pill"
	var materials = harness.game_ui.recipe_data.get_recipe_materials(recipe_id)
	var items := {}
	for material_id in materials.keys():
		items[str(material_id)] = 0
	await harness.client.test_post("/test/set_inventory_items", {"items": items})
	await harness.sync_full_state()

	module._select_recipe(recipe_id)
	module.set_craft_count(1)

	var spirit_label = module._material_labels.get("spirit_energy", null)
	assert_not_null(spirit_label, "应生成灵气需求标签")
	for material_id in materials.keys():
		var material_label = module._material_labels.get(str(material_id), null)
		assert_not_null(material_label, "应生成材料需求标签: %s" % str(material_id))
		assert_eq(material_label.get_theme_color("font_color"), module.COLOR_TEXT_RED, "材料不足时应显示红字")

func test_alchemy_blocked_by_cultivation_uses_client_copy():
	var runtime_state = await harness.client.test_post("/test/set_runtime_state", {"is_cultivating": true})
	assert_true(runtime_state.get("success", false), "应能构造修炼中状态")
	await harness.sync_full_state()

	var module = harness.game_ui.alchemy_module
	module._select_recipe("health_pill")
	module.set_craft_count(1)
	harness.clear_logs()
	await module._on_craft_pressed()

	assert_eq(harness.last_log(), "正在修炼中，无法开始炼丹", "修炼中开炉应使用客户端固定文案")

func test_alchemy_stop_mid_batch_logs_only_summary():
	var module = harness.game_ui.alchemy_module
	var alchemy_system = harness.get_alchemy_system()
	alchemy_system.special_bonus_speed_rate = 1.0
	module._select_recipe("health_pill")
	module.set_craft_count(10)
	harness.clear_logs()

	await module._on_craft_pressed()
	await module._on_stop_pressed()

	var messages = harness.get_log_messages()
	assert_true(harness.last_log().begins_with("收丹停火：成丹"), "中途停火应输出统一收丹停火汇总")
	for message in messages:
		assert_false(str(message).contains("获得丹药"), "停火路径不应出现旧成功文案")

func test_alchemy_report_failure_rolls_back_pre_deduct_cost():
	var module = harness.game_ui.alchemy_module
	var recipe_id = "health_pill"
	var materials = harness.game_ui.recipe_data.get_recipe_materials(recipe_id)
	var player = harness.get_player()
	var inventory = harness.get_inventory()

	module._select_recipe(recipe_id)
	module.set_craft_count(1)

	var before_spirit = int(round(player.spirit_energy))
	var before_counts: Dictionary = {}
	for material_id in materials.keys():
		before_counts[str(material_id)] = int(inventory.get_item_count(str(material_id)))

	harness.clear_logs()
	await module._on_craft_pressed()
	assert_true(module.is_crafting_active(), "开炉成功后应进入炼丹中状态")

	# 立即上报会触发服务端时间校验失败，模块应回滚本轮预扣。
	await module._run_alchemy_tick()
	await get_tree().process_frame

	var after_spirit = int(round(player.spirit_energy))
	assert_eq(after_spirit, before_spirit, "上报失败后应回滚灵气预扣")
	for material_id in materials.keys():
		var key = str(material_id)
		assert_eq(int(inventory.get_item_count(key)), int(before_counts.get(key, 0)), "上报失败后应回滚材料预扣: %s" % key)

	var messages = harness.get_log_messages()
	assert_true(messages.any(func(msg): return str(msg).contains("炼丹同步异常")), "上报失败应输出炼丹同步异常提示")
