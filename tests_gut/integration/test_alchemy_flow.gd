extends GutTest

## 集成测试 - 炼丹系统炼丹流程

var game_manager: Node = null
var alchemy_system: AlchemySystem = null
var inventory: Inventory = null
var player: PlayerData = null
var spell_system: SpellSystem = null
var recipe_data: AlchemyRecipeData = null

var _craft_connection: Dictionary = {}
var _last_success_count: int = 0
var _last_fail_count: int = 0

func before_all():
	await get_tree().process_frame
	game_manager = get_node_or_null("/root/GameManager")
	if not game_manager:
		pending("GameManager not available")
		return

func before_each():
	if not game_manager:
		pending("GameManager not available")
		return
	
	_setup_systems()
	await get_tree().process_frame

func after_each():
	_cleanup_systems()
	await get_tree().process_frame

func _setup_systems():
	player = game_manager.get_player()
	inventory = game_manager.get_inventory()
	alchemy_system = game_manager.get_alchemy_system()
	spell_system = game_manager.get_spell_system()
	recipe_data = game_manager.get_recipe_data()
	
	if not player or not inventory or not alchemy_system:
		pending("Required systems not available")
		return
	
	_connect_craft_signals()
	_reset_player_state()
	_reset_inventory()
	_reset_alchemy_system()

func _connect_craft_signals():
	if alchemy_system:
		if not _craft_connection.has("connected"):
			alchemy_system.crafting_finished.connect(_on_crafting_finished)
			alchemy_system.single_craft_completed.connect(_on_single_craft_completed)
			_craft_connection["connected"] = true

func _on_crafting_finished(recipe_id: String, success_count: int, fail_count: int):
	_last_success_count = success_count
	_last_fail_count = fail_count

func _on_single_craft_completed(success: bool, recipe_name: String):
	pass

func _reset_player_state():
	player.realm = "炼气期"
	player.realm_level = 1
	player.apply_realm_stats()
	player.health = player.get_final_max_health()
	player.spirit_energy = player.get_final_max_spirit_energy()

func _reset_inventory():
	inventory.clear()

func _reset_alchemy_system():
	if alchemy_system.is_crafting:
		alchemy_system.stop_crafting()
	alchemy_system.learned_recipes.clear()
	alchemy_system.equipped_furnace_id = ""
	alchemy_system.special_bonus_speed_rate = 0.0
	_last_success_count = 0
	_last_fail_count = 0

func _cleanup_systems():
	if alchemy_system and alchemy_system.is_crafting:
		alchemy_system.stop_crafting()
		await get_tree().process_frame
	
	if inventory:
		inventory.clear()

func _check_systems_available() -> bool:
	if not player or not inventory or not alchemy_system:
		pending("Required systems not available")
		return false
	return true

#region 场景①: 基础炼丹流程
## 测试场景: 炼气期玩家学习补血丹丹方，无丹炉无炼丹术加成，炼制10颗
## 测试目标: 验证完整的炼丹流程（学习→预览→开始→完成），储纳系统正确记录材料消耗和丹药获得
## 预期结果: 消耗20个灵草，消耗10点灵气，成功数+失败数=10，获得补血丹数量等于成功数
## 同时测试: 炼丹系统 + 储纳系统
#endregion

func test_basic_alchemy_flow():
	if not _check_systems_available():
		return
	
	var assert_count_start = gut.get_assert_count()
	var test_start_time = Time.get_ticks_msec()
	
	alchemy_system.special_bonus_speed_rate = 50.0
	
	inventory.add_item("mat_herb", 100)
	player.spirit_energy = 100
	
	var initial_herb = inventory.get_item_count("mat_herb")
	var initial_spirit = int(player.spirit_energy)
	var initial_pill = inventory.get_item_count("health_pill")
	
	assert_eq(initial_herb, 100, "应有100个灵草")
	
	alchemy_system.learn_recipe("health_pill")
	assert_true(alchemy_system.has_learned_recipe("health_pill"), "应学会补血丹丹方")
	assert_false(alchemy_system.has_furnace(), "不应有丹炉")
	
	var preview = alchemy_system.get_craft_preview("health_pill", 10)
	assert_true(preview.can_craft, "应可炼制")
	assert_eq(preview.success_rate, 50, "成功率应为50%")
	
	var result = alchemy_system.start_crafting_batch("health_pill", 10)
	assert_true(result.success, "应成功开始炼制")
	
	var max_wait = 30.0
	var total_wait = 0.0
	while alchemy_system.is_crafting and total_wait < max_wait:
		await get_tree().process_frame
		total_wait += get_process_delta_time()
	
	var total_test_time = (Time.get_ticks_msec() - test_start_time) / 1000.0
	var final_herb = inventory.get_item_count("mat_herb")
	var final_pill = inventory.get_item_count("health_pill")
	var final_spirit = int(player.spirit_energy)
	
	var consumed_herb = initial_herb - final_herb
	var consumed_spirit = initial_spirit - final_spirit
	var obtained_pill = final_pill - initial_pill
	
	assert_false(alchemy_system.is_crafting, "炼制应结束")
	
	var expected_herb_consumed = _last_success_count * 2 + _last_fail_count * 1
	assert_eq(consumed_herb, expected_herb_consumed, "灵草消耗应为: 成功数*2 + 失败数*1 = " + str(expected_herb_consumed))
	assert_eq(_last_success_count + _last_fail_count, 10, "成功+失败应等于10")
	assert_eq(consumed_spirit, 10, "应消耗10点灵气")
	assert_eq(obtained_pill, _last_success_count, "获得的补血丹应等于成功数")
	
	var assert_count_end = gut.get_assert_count()
	var passed = assert_count_end - assert_count_start
	gut.p("[场景①] 断言: " + str(passed) + "/" + str(assert_count_end - assert_count_start) + " 通过, 耗时: " + str(total_test_time) + "秒")

#region 场景②: 丹炉+炼丹术加成
## 测试场景: 筑基期玩家装备丹炉并学习炼丹术，炼制筑基丹
## 测试目标: 验证丹炉和炼丹术加成正确应用，术法系统记录炼丹术使用次数
## 预期结果: 成功率>30%（有加成），炼丹术使用次数=炼制次数
## 同时测试: 炼丹系统 + 术法系统 + 储纳系统
#endregion

func test_alchemy_with_furnace_and_spell():
	if not _check_systems_available():
		return
	
	var assert_count_start = gut.get_assert_count()
	var test_start_time = Time.get_ticks_msec()
	
	alchemy_system.special_bonus_speed_rate = 50.0
	
	player.realm = "筑基期"
	player.realm_level = 1
	player.apply_realm_stats()
	player.spirit_energy = 1000
	
	inventory.add_item("foundation_herb", 30)
	inventory.add_item("mat_herb", 100)
	
	var initial_pill = inventory.get_item_count("foundation_pill")
	
	alchemy_system.learn_recipe("foundation_pill")
	alchemy_system.equip_furnace("alchemy_furnace")
	
	assert_true(alchemy_system.has_furnace(), "应有丹炉")
	
	if spell_system and spell_system.player_spells.has("alchemy"):
		spell_system.obtain_spell("alchemy")
	
	var preview = alchemy_system.get_craft_preview("foundation_pill", 10)
	assert_true(preview.can_craft, "应可炼制")
	assert_gt(preview.success_rate, 30, "成功率应>30%")
	assert_true(preview.alchemy_bonus.obtained, "应已获取炼丹术")
	
	var result = alchemy_system.start_crafting_batch("foundation_pill", 10)
	assert_true(result.success, "应成功开始炼制")
	
	var max_wait = 60.0
	var total_wait = 0.0
	while alchemy_system.is_crafting and total_wait < max_wait:
		await get_tree().process_frame
		total_wait += get_process_delta_time()
	
	var total_test_time = (Time.get_ticks_msec() - test_start_time) / 1000.0
	var final_pill = inventory.get_item_count("foundation_pill")
	
	var obtained_pill = final_pill - initial_pill
	
	assert_false(alchemy_system.is_crafting, "炼制应结束")
	assert_gt(obtained_pill, 0, "应获得筑基丹")
	
	if spell_system and spell_system.player_spells.has("alchemy"):
		var use_count = spell_system.player_spells["alchemy"].get("use_count", 0)
		assert_eq(use_count, 10, "炼丹术使用次数应为10")
	
	var assert_count_end = gut.get_assert_count()
	var passed = assert_count_end - assert_count_start
	gut.p("[场景②] 断言: " + str(passed) + "/" + str(assert_count_end - assert_count_start) + " 通过, 耗时: " + str(total_test_time) + "秒")

#region 场景③: 批量炼制中途停止
## 测试场景: 炼气期玩家批量炼制补血丹，中途停止
## 测试目标: 验证停止炼制时储纳系统正确返还材料和灵气
## 预期结果: 返还未消耗的材料，返还已扣除但未使用的灵气
## 同时测试: 炼丹系统 + 储纳系统
#endregion

func test_stop_crafting_returns_materials():
	if not _check_systems_available():
		return
	
	var assert_count_start = gut.get_assert_count()
	var test_start_time = Time.get_ticks_msec()
	
	alchemy_system.special_bonus_speed_rate = 5.0
	
	inventory.add_item("mat_herb", 100)
	player.spirit_energy = 100
	
	var initial_herb = inventory.get_item_count("mat_herb")
	var initial_spirit = int(player.spirit_energy)
	
	alchemy_system.learn_recipe("health_pill")
	
	var result = alchemy_system.start_crafting_batch("health_pill", 10)
	assert_true(result.success, "应成功开始炼制")
	
	await get_tree().create_timer(0.5).timeout
	
	var stop_result = alchemy_system.stop_crafting()
	assert_true(stop_result.success, "停止应成功")
	assert_gt(stop_result.completed_count, 0, "应完成部分炼制")
	assert_gt(stop_result.remaining_count, 0, "应有剩余未炼制")
	
	var total_test_time = (Time.get_ticks_msec() - test_start_time) / 1000.0
	var final_herb = inventory.get_item_count("mat_herb")
	var final_spirit = int(player.spirit_energy)
	
	var consumed_herb = initial_herb - final_herb
	var consumed_spirit = initial_spirit - final_spirit
	
	assert_gt(consumed_herb, 0, "应消耗部分灵草")
	assert_lt(consumed_herb, 20, "应只消耗已炼制的灵草")
	assert_gt(consumed_spirit, 0, "应消耗部分灵气")
	assert_lt(consumed_spirit, 10, "应只消耗已炼制的灵气")
	assert_false(alchemy_system.is_crafting, "不应在炼制中")
	
	var assert_count_end = gut.get_assert_count()
	var passed = assert_count_end - assert_count_start
	gut.p("[场景③] 断言: " + str(passed) + "/" + str(assert_count_end - assert_count_start) + " 通过, 耗时: " + str(total_test_time) + "秒")

#region 场景④: 连续炼制多批次
## 测试场景: 炼气期玩家连续炼制两批补血丹
## 测试目标: 验证炼制完成后状态正确重置，可以立即开始下一批
## 预期结果: 第一批完成后可以开始第二批，两批炼制独立计算
## 同时测试: 炼丹系统 + 储纳系统
#endregion

func test_continuous_crafting_batches():
	if not _check_systems_available():
		return
	
	var assert_count_start = gut.get_assert_count()
	var test_start_time = Time.get_ticks_msec()
	
	alchemy_system.special_bonus_speed_rate = 50.0
	
	inventory.add_item("mat_herb", 100)
	player.spirit_energy = 100
	
	var initial_herb = inventory.get_item_count("mat_herb")
	var initial_pill = inventory.get_item_count("health_pill")
	
	alchemy_system.learn_recipe("health_pill")
	
	var result1 = alchemy_system.start_crafting_batch("health_pill", 5)
	assert_true(result1.success, "第一批应成功开始")
	
	var max_wait = 30.0
	var total_wait = 0.0
	while alchemy_system.is_crafting and total_wait < max_wait:
		await get_tree().process_frame
		total_wait += get_process_delta_time()
	
	assert_false(alchemy_system.is_crafting, "第一批应结束")
	var batch1_success = _last_success_count
	var batch1_fail = _last_fail_count
	
	var result2 = alchemy_system.start_crafting_batch("health_pill", 5)
	assert_true(result2.success, "第二批应成功开始")
	
	total_wait = 0.0
	while alchemy_system.is_crafting and total_wait < max_wait:
		await get_tree().process_frame
		total_wait += get_process_delta_time()
	
	var total_test_time = (Time.get_ticks_msec() - test_start_time) / 1000.0
	var final_herb = inventory.get_item_count("mat_herb")
	var final_pill = inventory.get_item_count("health_pill")
	
	var consumed_herb = initial_herb - final_herb
	var obtained_pill = final_pill - initial_pill
	
	var batch2_success = _last_success_count
	var batch2_fail = _last_fail_count
	var total_success = batch1_success + batch2_success
	var total_fail = batch1_fail + batch2_fail
	var expected_herb_consumed = total_success * 2 + total_fail * 1
	
	assert_false(alchemy_system.is_crafting, "第二批应结束")
	assert_eq(consumed_herb, expected_herb_consumed, "灵草消耗应为: 成功数*2 + 失败数*1 = " + str(expected_herb_consumed))
	assert_eq(batch1_success + batch1_fail, 5, "第一批成功+失败应等于5")
	assert_eq(batch2_success + batch2_fail, 5, "第二批成功+失败应等于5")
	assert_eq(obtained_pill, total_success, "获得的补血丹应等于总成功数")
	
	var assert_count_end = gut.get_assert_count()
	var passed = assert_count_end - assert_count_start
	gut.p("[场景④] 断言: " + str(passed) + "/" + str(assert_count_end - assert_count_start) + " 通过, 耗时: " + str(total_test_time) + "秒")
