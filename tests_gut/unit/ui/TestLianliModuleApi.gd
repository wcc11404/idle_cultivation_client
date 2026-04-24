extends GutTest

const MODULE_HARNESS = preload("res://tests_gut/support/ModuleHarness.gd")

class FakeLianliNetworkManager:
	extends Node

	func get_api_error_text_for_ui(_result: Dictionary, fallback: String = "") -> String:
		return fallback

class FakeLianliApi:
	extends Node

	var network_manager := FakeLianliNetworkManager.new()
	var simulate_calls: int = 0
	var finish_calls: int = 0

	func _ready():
		add_child(network_manager)

	func lianli_finish(_speed: float, _index = null) -> Dictionary:
		finish_calls += 1
		return {
			"success": true,
			"reason_code": "LIANLI_FINISH_FULLY_SETTLED",
			"reason_data": {},
			"loot_gained": []
		}

	func lianli_simulate(area_id: String) -> Dictionary:
		simulate_calls += 1
		return {
			"success": true,
			"reason_code": "LIANLI_SIMULATE_SUCCEEDED",
			"reason_data": {},
			"battle_timeline": [
				{
					"time": 0.1,
					"type": "player_action",
					"info": {
						"spell_id": "norm_attack",
						"effect_type": "instant_damage",
						"damage": 1,
						"target_health_after": 99
					}
				}
			],
			"total_time": 0.2,
			"victory": true,
			"loot": [],
			"enemy_data": {"name": "测试敌人", "level": 1, "health": 100},
			"player_health_after": 100,
			"area_id": area_id
		}

class CaptureFinishApi:
	extends FakeLianliApi

	var captured_finish_index = "__unset__"
	var captured_finish_speed: float = -1.0

	func lianli_finish(_speed: float, _index = null) -> Dictionary:
		captured_finish_speed = _speed
		captured_finish_index = _index
		return await super.lianli_finish(_speed, _index)

var harness: ModuleHarness = null

func before_each():
	harness = MODULE_HARNESS.new()
	add_child(harness)
	await harness.bootstrap("http://localhost:8444/api", "lianli_ready")

func after_each():
	if harness:
		await harness.cleanup()
		harness.free()
		harness = null
	await get_tree().process_frame

func test_lianli_local_state_keeps_scene_panel_when_returning_to_tab():
	var module = harness.game_ui.lianli_module
	var sim_result = await harness.client.lianli_simulate("area_1")
	assert_true(sim_result.get("success", false), "历练模拟应先成功")
	module._start_timeline_from_simulation(sim_result, "area_1")

	assert_true(harness.get_game_manager().get_lianli_system().is_in_lianli, "进入区域后客户端应记录历练态")
	assert_eq(harness.get_game_manager().get_lianli_system().current_area_id, "area_1", "应记录当前历练区域")

	harness.game_ui.show_chuna_tab()
	harness.game_ui.show_lianli_tab()

	assert_true(module.lianli_scene_panel.visible, "返回历练页时应直接回到战斗面板")
	assert_false(module.lianli_select_panel.visible, "返回历练页时不应回到区域选择页")

func test_lianli_finish_failure_exits_battle_and_returns_to_select_panel():
	var module = harness.game_ui.lianli_module
	var sim_result = await harness.client.lianli_simulate("area_1")
	assert_true(sim_result.get("success", false), "历练模拟应先成功")
	module._start_timeline_from_simulation(sim_result, "area_1")
	harness.clear_logs()

	await module._finish_current_battle(true)

	assert_true(harness.last_log().contains("历练结算同步异常，请稍后重试"), "过早结算应提示同步异常，实际为: %s" % harness.last_log())
	assert_false(harness.get_game_manager().get_lianli_system().is_in_lianli, "结算失败后应退出本地历练态")
	assert_true(module.lianli_select_panel.visible, "结算失败后应返回区域选择页")

func test_lianli_local_health_check_blocks_entry():
	var set_state = await harness.client.test_post("/test/set_player_state", {"health": 0})
	assert_true(set_state.get("success", false), "应能构造低气血状态")
	await harness.sync_full_state()

	var module = harness.game_ui.lianli_module
	harness.clear_logs()
	await module.start_lianli_in_area("area_1")

	assert_eq(harness.last_log(), "气血值不足，无法进入历练区域！请先修炼恢复气血值。", "本地气血校验应先于服务端请求拦截")

func test_lianli_daily_dungeon_limit_uses_reason_code_copy():
	var runtime = await harness.client.test_post(
		"/test/set_runtime_state",
		{"is_cultivating": false}
	)
	assert_true(runtime.get("success", false), "应能确保非修炼态，避免前置 flush 干扰本用例")
	var cultivation_module = harness.game_ui.cultivation_module
	if cultivation_module:
		cultivation_module._pending_elapsed_seconds = 0.0
		cultivation_module._last_optimistic_update_at = 0.0
		cultivation_module._optimistic_tick_accumulator = 0.0
	var player = harness.get_game_manager().get_player()
	if player:
		player.cultivation_active = false
	var progress = await harness.client.test_post(
		"/test/set_progress_state",
		{"daily_dungeon_remaining_counts": {"foundation_herb_cave": 0}}
	)
	assert_true(progress.get("success", false), "应能设置日副本剩余次数")
	await harness.sync_full_state()

	var module = harness.game_ui.lianli_module
	harness.clear_logs()
	await module.start_lianli_in_area("foundation_herb_cave")

	assert_eq(harness.last_log(), "今日副本次数已用完", "日副本次数耗尽应提示固定文案")

func test_lianli_continuous_waiting_flow_advances_to_next_simulation():
	var module = harness.game_ui.lianli_module
	var fake_api = FakeLianliApi.new()
	module.add_child(fake_api)
	module.api = fake_api
	module.continuous_checkbox.button_pressed = true
	module.on_continuous_toggled(true)

	module._start_timeline_from_simulation(
		{
			"battle_timeline": [],
			"total_time": 0.0,
			"victory": true,
			"loot": [],
			"enemy_data": {"name": "测试敌人", "level": 1, "health": 100},
			"player_health_after": 100
		},
		"area_1"
	)

	await module._finish_current_battle(true)
	assert_true(module._is_waiting, "连续战斗开启后，结算胜利应进入等待态")
	assert_true(harness.get_game_manager().get_lianli_system().is_waiting, "等待态应写入本地 lianli_system")

	module._wait_interval = 0.01
	module._wait_timer = 0.0
	await module._process(0.02)

	assert_eq(fake_api.simulate_calls, 1, "等待结束后应自动发起下一场模拟")
	assert_false(module._is_waiting, "下一场模拟启动后应退出等待态")

func test_lianli_exit_before_first_event_uses_minus_one_index():
	var module = harness.game_ui.lianli_module
	var capture_api = CaptureFinishApi.new()
	module.add_child(capture_api)
	module.api = capture_api

	module._start_timeline_from_simulation(
		{
			"battle_timeline": [
				{
					"time": 1.0,
					"type": "player_action",
					"info": {
						"spell_id": "norm_attack",
						"effect_type": "instant_damage",
						"damage": 1,
						"target_health_after": 99
					}
				}
			],
			"total_time": 1.0,
			"victory": true,
			"loot": [],
			"enemy_data": {"name": "测试敌人", "level": 1, "health": 100},
			"player_health_after": 100
		},
		"area_1"
	)
	module._timeline_cursor = 0

	await module._finish_current_battle(false)

	assert_eq(capture_api.captured_finish_index, -1, "首个事件前退出应上传 index=-1")

func test_lianli_full_settle_uses_null_index():
	var module = harness.game_ui.lianli_module
	var capture_api = CaptureFinishApi.new()
	module.add_child(capture_api)
	module.api = capture_api

	module._start_timeline_from_simulation(
		{
			"battle_timeline": [],
			"total_time": 0.0,
			"victory": true,
			"loot": [],
			"enemy_data": {"name": "测试敌人", "level": 1, "health": 100},
			"player_health_after": 100
		},
		"area_1"
	)

	await module._finish_current_battle(true)

	assert_eq(capture_api.captured_finish_index, null, "完整结算应上传 null（请求体省略 index）")

func test_tower_reward_panel_shows_current_floor_reward_when_current_floor_is_reward_floor():
	var module = harness.game_ui.lianli_module
	var lianli_sys = harness.get_game_manager().get_lianli_system()

	module.current_lianli_area_id = "sourth_endless_tower"
	lianli_sys.is_in_tower = true
	lianli_sys.current_tower_floor = 5

	module._update_battle_info()

	assert_eq(
		module.reward_info_label.text,
		"距离奖励层还需挑战 0 层（第5层）\n奖励：10灵石、3补血丹",
		"当前挑战层本身就是奖励层时，应显示当前层奖励而不是下一奖励层"
	)
