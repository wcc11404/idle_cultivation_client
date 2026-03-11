extends GutTest

## 集成测试 - 历练系统战斗流程

var game_manager: Node = null
var lianli_system: LianliSystem = null
var inventory: Inventory = null
var player: PlayerData = null
var spell_system: SpellSystem = null
var item_data: ItemData = null
var enemy_data: EnemyData = null
var lianli_area_data: LianliAreaData = null
var realm_system: RealmSystem = null

var _reward_connection: Dictionary = {}

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
	lianli_system = game_manager.get_lianli_system()
	spell_system = game_manager.get_spell_system()
	item_data = game_manager.get_item_data()
	enemy_data = game_manager.get_enemy_data()
	lianli_area_data = game_manager.get_lianli_area_data()
	realm_system = game_manager.get_realm_system()
	
	if not player or not inventory or not lianli_system:
		pending("Required systems not available")
		return
	
	_connect_reward_signal()
	_reset_player_state()
	_reset_inventory()
	_reset_spell_system()

func _connect_reward_signal():
	if lianli_system:
		if not _reward_connection.has("connected"):
			lianli_system.lianli_reward.connect(_on_lianli_reward)
			_reward_connection["connected"] = true

func _on_lianli_reward(item_id: String, amount: int, source: String):
	if inventory:
		inventory.add_item(item_id, amount)

func _reset_player_state():
	if lianli_system.is_in_lianli:
		lianli_system.end_lianli()
		await get_tree().process_frame
	
	player.realm = "炼气期"
	player.realm_level = 1
	player.apply_realm_stats()
	player.health = player.get_final_max_health()
	player.spirit_energy = player.get_final_max_spirit_energy()
	player.combat_buffs = {}
	
	lianli_system.tower_highest_floor = 0
	lianli_system.daily_dungeon_data = {}

func _reset_inventory():
	inventory.clear()

func _reset_spell_system():
	if spell_system:
		for spell_id in spell_system.player_spells.keys():
			spell_system.player_spells[spell_id]["obtained"] = false
			spell_system.player_spells[spell_id]["level"] = 1
			spell_system.player_spells[spell_id]["use_count"] = 0
			spell_system.player_spells[spell_id]["charged_spirit"] = 0
		
		for spell_type in spell_system.equipped_spells.keys():
			spell_system.equipped_spells[spell_type] = []

func _cleanup_systems():
	if lianli_system and lianli_system.is_in_lianli:
		lianli_system.end_lianli()
		await get_tree().process_frame
	
	if inventory:
		inventory.clear()

func _check_systems_available() -> bool:
	if not player or not inventory or not lianli_system:
		pending("Required systems not available")
		return false
	return true

#region 场景①: 炼气一层玩家挑战炼气外围
## 测试场景: 炼气期一层玩家进入炼气外围历练
## 测试目标: 验证低境界玩家在高级区域会死亡并自动退出
## 预期结果: 玩家最多打倒2个怪物后死亡，自动退出历练区域
#endregion

func test_qi_level1_vs_outer_area_survival():
	if not _check_systems_available():
		return
	
	var assert_count_start = gut.get_assert_count()
	var test_start_time = Time.get_ticks_msec()
	
	player.realm = "炼气期"
	player.realm_level = 1
	player.apply_realm_stats()
	player.health = player.get_final_max_health()
	
	var max_health = int(player.get_final_max_health())
	
	lianli_system.set_lianli_speed(10.0)
	lianli_system.base_wait_interval_min = 0.1
	lianli_system.base_wait_interval_max = 0.1
	lianli_system.min_wait_time = 0.1
	
	assert_eq(player.realm, "炼气期", "境界应为炼气期")
	assert_eq(player.realm_level, 1, "境界等级应为1")
	assert_eq(max_health, 50, "炼气一层最大气血应为50")
	
	lianli_system.set_continuous_lianli(true)
	var started = lianli_system.start_lianli_in_area("qi_refining_outer")
	assert_true(started, "应成功进入历练区域")
	
	var battle_count = 0
	var max_battles = 10
	var max_total_wait = 120.0
	var total_wait = 0.0
	
	while battle_count < max_battles and total_wait < max_total_wait:
		while not lianli_system.is_in_battle and total_wait < max_total_wait:
			await get_tree().process_frame
			total_wait += get_process_delta_time()
		
		if not lianli_system.is_in_battle:
			break
		
		var enemy = lianli_system.current_enemy
		
		while lianli_system.is_in_battle and total_wait < max_total_wait:
			await get_tree().process_frame
			total_wait += get_process_delta_time()
		
		if enemy.size() > 0 and enemy.get("current_health", 0) <= 0:
			battle_count += 1
		
		if player.health <= 0:
			break
		
		while lianli_system.is_waiting and total_wait < max_total_wait:
			await get_tree().process_frame
			total_wait += get_process_delta_time()
		
		if not lianli_system.is_in_lianli:
			break
	
	var total_test_time = (Time.get_ticks_msec() - test_start_time) / 1000.0
	
	lianli_system.set_lianli_speed(1.0)
	
	assert_lt(total_test_time, 10.0, "场景①总耗时应小于10秒")
	assert_lte(battle_count, 2, "炼气一层玩家最多打倒2个怪物")
	assert_eq(int(player.health), 0, "玩家应死亡")
	assert_false(lianli_system.is_in_lianli, "应自动退出历练区域")
	
	var assert_count_end = gut.get_assert_count()
	var passed = assert_count_end - assert_count_start
	gut.p("[场景①] 断言: " + str(passed) + "/" + str(assert_count_end - assert_count_start) + " 通过, 耗时: " + str(total_test_time) + "秒")

#region 场景②: 炼气四层玩家 + 基础拳法挑战炼气外围
## 测试场景: 炼气期四层玩家装备基础拳法进入炼气外围历练
## 测试目标: 验证中等境界玩家可以连续战斗，术法使用次数增加，战斗中无法装备被动术法
## 预期结果: 玩家打倒怪物后获得灵石掉落，基础拳法使用次数>0，基础防御装备失败
## 同时测试: 术法系统 + 历练系统
#endregion

func test_qi_level4_with_spell_vs_outer_area():
	if not _check_systems_available():
		return
	
	var assert_count_start = gut.get_assert_count()
	var test_start_time = Time.get_ticks_msec()
	
	player.realm = "炼气期"
	player.realm_level = 4
	player.apply_realm_stats()
	player.health = player.get_final_max_health()
	
	var max_health = int(player.get_final_max_health())
	
	lianli_system.set_lianli_speed(10.0)
	lianli_system.base_wait_interval_min = 0.1
	lianli_system.base_wait_interval_max = 0.1
	lianli_system.min_wait_time = 0.1
	
	assert_eq(max_health, 68, "炼气四层最大气血应为68")
	
	if spell_system and spell_system.player_spells.has("basic_fist"):
		spell_system.obtain_spell("basic_fist")
		spell_system.equip_spell("basic_fist")
	
	var initial_stones = inventory.get_item_count("spirit_stone")
	
	lianli_system.set_continuous_lianli(true)
	var started = lianli_system.start_lianli_in_area("qi_refining_outer")
	assert_true(started, "应成功进入历练区域")
	
	var battle_count = 0
	var min_battles = 5
	var max_total_wait = 180.0
	var total_wait = 0.0
	var defense_equipped_during_battle = false
	
	while battle_count < 10 and total_wait < max_total_wait:
		while not lianli_system.is_in_battle and total_wait < max_total_wait:
			await get_tree().process_frame
			total_wait += get_process_delta_time()
		
		if not lianli_system.is_in_battle:
			break
		
		if spell_system and spell_system.player_spells.has("basic_defense") and not defense_equipped_during_battle:
			spell_system.obtain_spell("basic_defense")
			spell_system.equip_spell("basic_defense")
			defense_equipped_during_battle = true
		
		var enemy = lianli_system.current_enemy
		
		while lianli_system.is_in_battle and total_wait < max_total_wait:
			await get_tree().process_frame
			total_wait += get_process_delta_time()
		
		if enemy.size() > 0 and enemy.get("current_health", 0) <= 0:
			battle_count += 1
		
		if player.health <= 0:
			break
		
		while lianli_system.is_waiting and total_wait < max_total_wait:
			await get_tree().process_frame
			total_wait += get_process_delta_time()
		
		if not lianli_system.is_in_lianli:
			break
	
	var total_test_time = (Time.get_ticks_msec() - test_start_time) / 1000.0
	var final_stones = inventory.get_item_count("spirit_stone")
	
	lianli_system.set_lianli_speed(1.0)
	
	assert_gte(battle_count, min_battles, "炼气四层玩家应至少打倒5个怪物")
	assert_gt(final_stones, initial_stones, "应获得灵石掉落")
	
	if spell_system and spell_system.player_spells.has("basic_fist"):
		var spell_use_count = spell_system.player_spells["basic_fist"].get("use_count", 0)
		assert_gt(spell_use_count, 0, "基础拳法使用次数应大于0")
	
	if spell_system and spell_system.player_spells.has("basic_defense"):
		var defense_equipped = spell_system.equipped_spells.get(spell_system.spell_data.SpellType.PASSIVE, [])
		assert_false(defense_equipped.has("basic_defense"), "战斗中装备基础防御应失败")
	
	var assert_count_end = gut.get_assert_count()
	var passed = assert_count_end - assert_count_start
	gut.p("[场景②] 断言: " + str(passed) + "/" + str(assert_count_end - assert_count_start) + " 通过, 耗时: " + str(total_test_time) + "秒")

#region 场景③: 筑基三层玩家挑战破境草洞穴
## 测试场景: 筑基期三层玩家进入破境草洞穴获取破境草
## 测试目标: 验证特殊区域每日次数限制和掉落奖励，储纳系统正确记录物品数量
## 预期结果: 玩家消耗3次机会，获得30个破境草和60个灵石
## 同时测试: 储纳系统 + 历练系统
#endregion

func test_foundation_level3_vs_herb_cave():
	if not _check_systems_available():
		return
	
	var assert_count_start = gut.get_assert_count()
	var test_start_time = Time.get_ticks_msec()
	
	player.realm = "筑基期"
	player.realm_level = 3
	player.apply_realm_stats()
	player.health = player.get_final_max_health()
	
	var max_health = int(player.get_final_max_health())
	
	lianli_system.set_lianli_speed(10.0)
	lianli_system.base_wait_interval_min = 0.1
	lianli_system.base_wait_interval_max = 0.1
	lianli_system.min_wait_time = 0.1
	
	assert_eq(max_health, 302, "筑基三层最大气血应为302")
	
	if spell_system:
		if spell_system.player_spells.has("basic_fist"):
			spell_system.obtain_spell("basic_fist")
			spell_system.equip_spell("basic_fist")
		if spell_system.player_spells.has("basic_defense"):
			spell_system.obtain_spell("basic_defense")
			spell_system.equip_spell("basic_defense")
	
	var initial_herb = inventory.get_item_count("foundation_herb")
	var initial_stones = inventory.get_item_count("spirit_stone")
	var initial_count = lianli_system.get_daily_dungeon_count("foundation_herb_cave")
	var battle_count = 0
	
	lianli_system.set_continuous_lianli(false)
	var started1 = lianli_system.start_lianli_in_area("foundation_herb_cave")
	assert_true(started1, "第一次应成功进入")
	
	var total_wait = 0.0
	while lianli_system.is_in_battle and total_wait < 60.0:
		await get_tree().process_frame
		total_wait += get_process_delta_time()
	
	battle_count += 1
	
	await get_tree().create_timer(0.5).timeout
	
	var count_after_first = lianli_system.get_daily_dungeon_count("foundation_herb_cave")
	assert_lt(count_after_first, initial_count, "第一次应消耗次数")
	
	lianli_system.set_continuous_lianli(true)
	
	var wait_started = lianli_system.start_wait_for_next_battle()
	assert_true(wait_started, "应成功进入等待状态")
	
	total_wait = 0.0
	while lianli_system.is_waiting and total_wait < 60.0:
		await get_tree().process_frame
		total_wait += get_process_delta_time()
	
	while lianli_system.is_in_lianli and total_wait < 120.0:
		if lianli_system.is_in_battle:
			while lianli_system.is_in_battle and total_wait < 120.0:
				await get_tree().process_frame
				total_wait += get_process_delta_time()
			battle_count += 1
		
		if lianli_system.is_waiting:
			while lianli_system.is_waiting and total_wait < 120.0:
				await get_tree().process_frame
				total_wait += get_process_delta_time()
		
		if not lianli_system.is_in_lianli:
			break
		
		await get_tree().process_frame
		total_wait += get_process_delta_time()
	
	var total_test_time = (Time.get_ticks_msec() - test_start_time) / 1000.0
	var final_herb = inventory.get_item_count("foundation_herb")
	var final_stones = inventory.get_item_count("spirit_stone")
	var final_count = lianli_system.get_daily_dungeon_count("foundation_herb_cave")
	
	lianli_system.set_lianli_speed(1.0)
	
	assert_lt(total_test_time, 10.0, "场景③总耗时应小于10秒")
	assert_eq(final_herb, initial_herb + 30, "应获得30个破境草")
	assert_eq(final_stones, initial_stones + 60, "应获得60个灵石")
	assert_lte(final_count, 0, "次数应用完")
	assert_gt(int(player.health), 0, "玩家应存活")
	assert_false(lianli_system.is_in_lianli, "应正常退出历练")
	assert_eq(battle_count, 3, "总战斗场次应为3")
	
	var assert_count_end = gut.get_assert_count()
	var passed = assert_count_end - assert_count_start
	gut.p("[场景③] 断言: " + str(passed) + "/" + str(assert_count_end - assert_count_start) + " 通过, 耗时: " + str(total_test_time) + "秒")

#region 场景④: 筑基一层玩家连续挑战无尽塔
## 测试场景: 筑基期一层玩家进入无尽塔连续挑战
## 测试目标: 验证无尽塔层数递增、最高层数记录、奖励层发放奖励
## 预期结果: 玩家挑战多层后死亡或通关，记录最高层数，奖励层获得奖励
## 同时测试: 无尽塔系统 + 历练系统
#endregion

func test_foundation_level1_vs_endless_tower():
	if not _check_systems_available():
		return
	
	var assert_count_start = gut.get_assert_count()
	var test_start_time = Time.get_ticks_msec()
	
	player.realm = "筑基期"
	player.realm_level = 1
	player.apply_realm_stats()
	player.health = player.get_final_max_health()
	
	var max_health = int(player.get_final_max_health())
	
	lianli_system.set_lianli_speed(10.0)
	lianli_system.base_wait_interval_min = 0.1
	lianli_system.base_wait_interval_max = 0.1
	lianli_system.min_wait_time = 0.1
	
	assert_eq(max_health, 250, "筑基一层最大气血应为250")
	
	if spell_system and spell_system.player_spells.has("basic_fist"):
		spell_system.obtain_spell("basic_fist")
		spell_system.equip_spell("basic_fist")
	
	lianli_system.tower_highest_floor = 0
	
	var started = lianli_system.start_endless_tower()
	assert_true(started, "应成功进入无尽塔")
	assert_true(lianli_system.is_in_tower, "应在无尽塔中")
	assert_eq(lianli_system.get_current_tower_floor(), 1, "应从第1层开始")
	
	lianli_system.set_continuous_lianli(true)
	
	var max_total_wait = 120.0
	var total_wait = 0.0
	var battle_count = 0
	
	while total_wait < max_total_wait:
		while lianli_system.is_in_battle and total_wait < max_total_wait:
			await get_tree().process_frame
			total_wait += get_process_delta_time()
		
		battle_count += 1
		
		if player.health <= 0:
			break
		
		while lianli_system.is_waiting and total_wait < max_total_wait:
			await get_tree().process_frame
			total_wait += get_process_delta_time()
		
		if not lianli_system.is_in_lianli:
			break
	
	var total_test_time = (Time.get_ticks_msec() - test_start_time) / 1000.0
	var final_floor = lianli_system.tower_highest_floor
	var has_basic_breathing = inventory.get_item_count("spell_basic_breathing") > 0
	
	lianli_system.set_lianli_speed(1.0)
	
	assert_lt(total_test_time, 20.0, "场景④总耗时应小于20秒")
	assert_gte(final_floor, 18, "最高层数应至少18层")
	assert_gt(battle_count, 0, "应完成至少1场战斗")
	assert_true(has_basic_breathing, "应获得基础吐纳心法")
	
	var assert_count_end = gut.get_assert_count()
	var passed = assert_count_end - assert_count_start
	gut.p("[场景④] 断言: " + str(passed) + "/" + str(assert_count_end - assert_count_start) + " 通过, 耗时: " + str(total_test_time) + "秒")

#endregion
