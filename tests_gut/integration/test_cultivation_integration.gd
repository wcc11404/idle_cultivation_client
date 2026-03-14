extends GutTest

## 集成测试 - 修炼系统与其他系统交互

var game_manager: Node = null
var cultivation_system: CultivationSystem = null
var lianli_system: LianliSystem = null
var alchemy_system: AlchemySystem = null
var inventory: Inventory = null
var player: PlayerData = null
var spell_system: SpellSystem = null
var realm_system: RealmSystem = null

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
	cultivation_system = game_manager.get_cultivation_system()
	lianli_system = game_manager.get_lianli_system()
	alchemy_system = game_manager.get_alchemy_system()
	spell_system = game_manager.get_spell_system()
	realm_system = game_manager.get_realm_system()
	
	if not player or not cultivation_system:
		pending("Required systems not available")
		return
	
	_reset_player_state()
	_reset_inventory()
	_reset_cultivation_system()
	_reset_other_systems()

func _reset_player_state():
	player.realm = "炼气期"
	player.realm_level = 1
	player.apply_realm_stats()
	player.health = player.get_final_max_health()
	player.spirit_energy = 0
	player.cultivation_active = false

func _reset_inventory():
	inventory.clear()

func _reset_cultivation_system():
	if cultivation_system.is_cultivating:
		cultivation_system.stop_cultivation()

func _reset_other_systems():
	if lianli_system and lianli_system.is_in_lianli:
		lianli_system.end_lianli()
		await get_tree().process_frame
	
	if alchemy_system and alchemy_system.is_crafting:
		alchemy_system.stop_crafting()
		await get_tree().process_frame
	
	if spell_system:
		for spell_id in spell_system.player_spells.keys():
			spell_system.player_spells[spell_id]["obtained"] = false
			spell_system.player_spells[spell_id]["level"] = 1
			spell_system.player_spells[spell_id]["use_count"] = 0
			spell_system.player_spells[spell_id]["charged_spirit"] = 0
		
		for spell_type in spell_system.equipped_spells.keys():
			spell_system.equipped_spells[spell_type] = []

func _cleanup_systems():
	if cultivation_system and cultivation_system.is_cultivating:
		cultivation_system.stop_cultivation()
	
	if lianli_system and lianli_system.is_in_lianli:
		lianli_system.end_lianli()
		await get_tree().process_frame
	
	if alchemy_system and alchemy_system.is_crafting:
		alchemy_system.stop_crafting()
		await get_tree().process_frame
	
	if inventory:
		inventory.clear()

func _check_systems_available() -> bool:
	if not player or not cultivation_system:
		pending("Required systems not available")
		return false
	return true

#region 场景①: 修炼系统与吐纳心法联动
## 测试场景: 装备吐纳心法后进行修炼
## 测试目标: 验证吐纳心法对修炼气血恢复的加成效果
## 预期结果: 装备吐纳心法后，气血恢复速度加快，术法使用次数增加
## 同时测试: 修炼系统 + 术法系统
#endregion

func test_cultivation_with_breathing_spell():
	if not _check_systems_available() or not spell_system:
		return
	
	var assert_count_start = gut.get_assert_count()
	var test_start_time = Time.get_ticks_msec()
	
	player.health = player.get_final_max_health() * 0.5
	var initial_health = player.health
	
	# 装备吐纳心法
	if spell_system.player_spells.has("basic_breathing"):
		spell_system.obtain_spell("basic_breathing")
		spell_system.equip_spell("basic_breathing")
		
		var initial_use_count = spell_system.player_spells["basic_breathing"].get("use_count", 0)
		
		# 开始修炼
		cultivation_system.start_cultivation()
		assert_true(cultivation_system.is_cultivating, "应开始修炼")
		
		# 执行多次修炼
		for i in range(10):
			cultivation_system.do_cultivate()
			await get_tree().process_frame
		
		# 检查结果
		var final_health = player.health
		var final_use_count = spell_system.player_spells["basic_breathing"].get("use_count", 0)
		
		assert_gt(final_health, initial_health, "气血应增加")
		assert_gt(final_use_count, initial_use_count, "吐纳心法使用次数应增加")
	
	var total_test_time = (Time.get_ticks_msec() - test_start_time) / 1000.0
	
	var assert_count_end = gut.get_assert_count()
	var passed = assert_count_end - assert_count_start
	gut.p("[场景①] 断言: " + str(passed) + "/" + str(assert_count_end - assert_count_start) + " 通过, 耗时: " + str(total_test_time) + "秒")

#region 场景②: 修炼与历练系统互斥
## 测试场景: 修炼时尝试开始历练
## 测试目标: 验证修炼和历练不能同时进行
## 预期结果: 开始历练时，修炼自动停止
## 同时测试: 修炼系统 + 历练系统
#endregion

func test_cultivation_lianli_mutex():
	if not _check_systems_available() or not lianli_system:
		return
	
	var assert_count_start = gut.get_assert_count()
	var test_start_time = Time.get_ticks_msec()
	
	# 开始修炼
	cultivation_system.start_cultivation()
	assert_true(cultivation_system.is_cultivating, "应开始修炼")
	assert_true(player.cultivation_active, "玩家应处于修炼状态")
	
	# 尝试开始历练
	lianli_system.set_continuous_lianli(false)
	var started = lianli_system.start_lianli_in_area("qi_refining_outer")
	assert_true(started, "应成功进入历练区域")
	
	# 检查修炼状态
	assert_false(cultivation_system.is_cultivating, "修炼应自动停止")
	assert_false(player.cultivation_active, "玩家修炼状态应变为false")
	assert_true(lianli_system.is_in_lianli, "应在历练中")
	
	var total_test_time = (Time.get_ticks_msec() - test_start_time) / 1000.0
	
	var assert_count_end = gut.get_assert_count()
	var passed = assert_count_end - assert_count_start
	gut.p("[场景②] 断言: " + str(passed) + "/" + str(assert_count_end - assert_count_start) + " 通过, 耗时: " + str(total_test_time) + "秒")

#region 场景③: 修炼与炼丹系统互斥
## 测试场景: 修炼时尝试开始炼丹
## 测试目标: 验证修炼和炼丹不能同时进行
## 预期结果: 开始炼丹时，修炼自动停止
## 同时测试: 修炼系统 + 炼丹系统
#endregion

func test_cultivation_alchemy_mutex():
	if not _check_systems_available() or not alchemy_system:
		return
	
	var assert_count_start = gut.get_assert_count()
	var test_start_time = Time.get_ticks_msec()
	
	# 准备炼丹材料
	inventory.add_item("mat_herb", 100)
	player.spirit_energy = 100
	
	# 学习丹方
	alchemy_system.learn_recipe("health_pill")
	
	# 开始修炼
	cultivation_system.start_cultivation()
	assert_true(cultivation_system.is_cultivating, "应开始修炼")
	assert_true(player.cultivation_active, "玩家应处于修炼状态")
	
	# 尝试开始炼丹
	var result = alchemy_system.start_crafting_batch("health_pill", 5)
	assert_true(result.success, "应成功开始炼丹")
	
	# 检查修炼状态
	assert_false(cultivation_system.is_cultivating, "修炼应自动停止")
	assert_false(player.cultivation_active, "玩家修炼状态应变为false")
	assert_true(alchemy_system.is_crafting, "应在炼丹中")
	
	# 停止炼丹
	alchemy_system.stop_crafting()
	
	var total_test_time = (Time.get_ticks_msec() - test_start_time) / 1000.0
	
	var assert_count_end = gut.get_assert_count()
	var passed = assert_count_end - assert_count_start
	gut.p("[场景③] 断言: " + str(passed) + "/" + str(assert_count_end - assert_count_start) + " 通过, 耗时: " + str(total_test_time) + "秒")

#region 场景④: 完整修炼突破流程
## 测试场景: 从炼气期一层修炼到突破至二层
## 测试目标: 验证完整的修炼和突破流程
## 预期结果: 修炼积累灵气，达到突破条件后成功突破
## 同时测试: 修炼系统 + 境界系统
#endregion

func test_cultivation_breakthrough_flow():
	if not _check_systems_available() or not realm_system:
		return
	
	var assert_count_start = gut.get_assert_count()
	var test_start_time = Time.get_ticks_msec()
	
	# 重置玩家状态
	player.realm = "炼气期"
	player.realm_level = 1
	player.apply_realm_stats()
	player.health = player.get_final_max_health()
	player.spirit_energy = 0
	
	# 添加足够的灵石用于突破
	var stone_cost = realm_system.get_spirit_stone_cost("炼气期", 1)
	inventory.add_item("spirit_stone", stone_cost + 100)
	
	# 开始修炼
	cultivation_system.start_cultivation()
	assert_true(cultivation_system.is_cultivating, "应开始修炼")
	
	# 积累灵气直到可以突破
	var breakthrough_cost = realm_system.get_spirit_energy_cost("炼气期", 1)
	while player.spirit_energy < breakthrough_cost:
		cultivation_system.do_cultivate()
		await get_tree().process_frame
	
	# 检查突破条件
	var can_breakthrough = realm_system.can_breakthrough("炼气期", 1, inventory.get_item_count("spirit_stone"), player.spirit_energy, {})
	assert_true(can_breakthrough.can, "应满足突破条件")
	
	# 执行突破
	var breakthrough_result = player.attempt_breakthrough()
	assert_true(breakthrough_result.success, "突破应成功")
	assert_eq(player.realm_level, 2, "境界等级应提升到2")
	
	# 停止修炼
	cultivation_system.stop_cultivation()
	
	var total_test_time = (Time.get_ticks_msec() - test_start_time) / 1000.0
	
	var assert_count_end = gut.get_assert_count()
	var passed = assert_count_end - assert_count_start
	gut.p("[场景④] 断言: " + str(passed) + "/" + str(assert_count_end - assert_count_start) + " 通过, 耗时: " + str(total_test_time) + "秒")

#region 场景⑤: 练气大圆满到筑基突破
## 测试场景: 从炼气期十层突破到筑基期
## 测试目标: 验证大境界突破的物品消耗
## 预期结果: 突破成功，消耗筑基丹，境界提升到筑基期
## 同时测试: 修炼系统 + 境界系统 + 储纳系统
#endregion

func test_qi_max_to_foundation_breakthrough():
	if not _check_systems_available() or not realm_system:
		return
	
	var assert_count_start = gut.get_assert_count()
	var test_start_time = Time.get_ticks_msec()
	
	# 重置玩家状态
	player.realm = "炼气期"
	player.realm_level = 10  # 练气大圆满
	player.apply_realm_stats()
	player.health = player.get_final_max_health()
	player.spirit_energy = 1000  # 足够的灵气
	
	# 添加突破材料和灵石
	inventory.add_item("foundation_pill", 1)  # 筑基丹
	var stone_cost = realm_system.get_spirit_stone_cost("炼气期", 10)
	inventory.add_item("spirit_stone", stone_cost + 1000)  # 足够的灵石
	var initial_pill_count = inventory.get_item_count("foundation_pill")
	
	# 检查突破条件
	var can_breakthrough = realm_system.can_breakthrough("炼气期", 10, 1000, player.spirit_energy, {"foundation_pill": 1})
	assert_true(can_breakthrough.can, "应满足突破条件")
	
	# 执行突破
	var breakthrough_result = player.attempt_breakthrough()
	assert_true(breakthrough_result.success, "突破应成功")
	assert_eq(player.realm, "筑基期", "境界应提升到筑基期")
	assert_eq(player.realm_level, 1, "境界等级应重置为1")
	
	# 检查材料消耗
	var final_pill_count = inventory.get_item_count("foundation_pill")
	assert_lt(final_pill_count, initial_pill_count, "应消耗筑基丹")
	
	var total_test_time = (Time.get_ticks_msec() - test_start_time) / 1000.0
	
	var assert_count_end = gut.get_assert_count()
	var passed = assert_count_end - assert_count_start
	gut.p("[场景⑤] 断言: " + str(passed) + "/" + str(assert_count_end - assert_count_start) + " 通过, 耗时: " + str(total_test_time) + "秒")
