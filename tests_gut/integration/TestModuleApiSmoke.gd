extends GutTest

const MODULE_HARNESS = preload("res://tests_gut/support/ModuleHarness.gd")

var harness: ModuleHarness = null

func before_each():
	harness = MODULE_HARNESS.new()
	add_child(harness)
	await harness.bootstrap()

func after_each():
	if harness:
		await harness.cleanup()
		harness.free()
		harness = null
	await get_tree().process_frame

func test_module_api_smoke_flow():
	await harness.apply_preset_and_sync("breakthrough_ready")
	var cultivation_module = harness.game_ui.cultivation_module
	await cultivation_module.on_breakthrough_button_pressed()
	assert_true(harness.last_log().begins_with("突破成功"), "突破 smoke 应成功")

	await harness.apply_preset_and_sync("alchemy_ready")
	var alchemy_module = harness.game_ui.alchemy_module
	harness.get_alchemy_system().special_bonus_speed_rate = 1000.0
	alchemy_module._select_recipe("health_pill")
	alchemy_module.set_craft_count(1)
	await alchemy_module._on_craft_pressed()
	while alchemy_module.is_crafting_active():
		await alchemy_module._run_alchemy_tick()
	assert_true(harness.last_log().begins_with("收丹停火："), "炼丹 smoke 应成功")

	await harness.apply_preset_and_sync("spell_ready")
	var spell_module = harness.game_ui.spell_module
	spell_module.current_viewing_spell = "basic_steps"
	await spell_module._on_spell_equip_toggle()
	assert_true(harness.last_log().contains("卸下成功"), "术法 smoke 应成功")

	await harness.apply_preset_and_sync("lianli_ready")
	var lianli_module = harness.game_ui.lianli_module
	var sim_result = await harness.client.lianli_simulate("area_1")
	assert_true(sim_result.get("success", false), "历练 smoke 应先拿到模拟结果")
	lianli_module._start_timeline_from_simulation(sim_result, "area_1")
	assert_true(harness.get_game_manager().get_lianli_system().is_in_lianli, "历练 smoke 应进入战斗")

	await harness.apply_preset_and_sync("full_unlock")
	var herb_module = harness.game_ui.herb_gather_module
	harness.game_ui.show_herb_gather_panel()
	await herb_module._refresh_points()
	await herb_module._on_start_pressed("point_low_yield")
	assert_true(herb_module._is_gathering, "采集 smoke 应进入采集状态")
	await harness.client.test_post("/test/set_runtime_state", {
		"is_gathering": true,
		"current_herb_point_id": "point_low_yield",
		"herb_elapsed_seconds": 10
	})
	await herb_module._do_report_once()
	await herb_module._on_stop_pressed()
	assert_false(herb_module._is_gathering, "采集 smoke 停止后应退出采集状态")

	var settings_module = harness.game_ui.settings_module
	await settings_module._load_rank_data()
	assert_gt(settings_module.rank_list.get_child_count(), 0, "设置 smoke 应能加载排行榜")
