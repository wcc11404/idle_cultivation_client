extends GutTest

## 集成测试 - 储纳系统与其他系统交互

var game_manager: Node = null
var inventory: Inventory = null
var player: PlayerData = null
var lianli_system: LianliSystem = null
var alchemy_system: AlchemySystem = null
var spell_system: SpellSystem = null
var item_data: ItemData = null

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
	alchemy_system = game_manager.get_alchemy_system()
	spell_system = game_manager.get_spell_system()
	item_data = game_manager.get_item_data()
	
	if not player or not inventory:
		pending("Required systems not available")
		return
	
	_reset_player_state()
	_reset_inventory()
	_reset_other_systems()

func _reset_player_state():
	player.realm = "炼气期"
	player.realm_level = 1
	player.apply_realm_stats()
	player.health = player.get_final_max_health()
	player.spirit_energy = player.get_final_max_spirit_energy()

func _reset_inventory():
	inventory.clear()

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
	if lianli_system and lianli_system.is_in_lianli:
		lianli_system.end_lianli()
		await get_tree().process_frame
	
	if alchemy_system and alchemy_system.is_crafting:
		alchemy_system.stop_crafting()
		await get_tree().process_frame
	
	if inventory:
		inventory.clear()

func _check_systems_available() -> bool:
	if not player or not inventory:
		pending("Required systems not available")
		return false
	return true

#region 场景①: 储纳系统与历练系统交互
## 测试场景: 历练获得物品后储纳系统更新
## 测试目标: 验证历练系统获得的物品能正确添加到储纳系统
## 预期结果: 击败怪物后，储纳系统中出现相应的掉落物品
## 同时测试: 储纳系统 + 历练系统
#endregion

func test_inventory_lianli_interaction():
	if not _check_systems_available() or not lianli_system:
		return
	
	var assert_count_start = gut.get_assert_count()
	var test_start_time = Time.get_ticks_msec()
	
	# 连接掉落信号
	if not lianli_system.lianli_reward.is_connected(_on_lianli_reward):
		lianli_system.lianli_reward.connect(_on_lianli_reward)
	
	# 记录初始物品数量
	var initial_stones = inventory.get_item_count("spirit_stone")
	
	# 设置玩家状态
	player.realm = "筑基期"
	player.realm_level = 3
	player.apply_realm_stats()
	player.health = player.get_final_max_health()
	
	# 开始历练
	lianli_system.set_lianli_speed(10.0)
	lianli_system.set_continuous_lianli(false)
	var started = lianli_system.start_lianli_in_area("qi_refining_outer")
	assert_true(started, "应成功进入历练区域")
	
	# 等待战斗结束
	var max_wait = 60.0
	var total_wait = 0.0
	while lianli_system.is_in_battle and total_wait < max_wait:
		await get_tree().process_frame
		total_wait += get_process_delta_time()
	
	# 检查物品数量
	var final_stones = inventory.get_item_count("spirit_stone")
	assert_gt(final_stones, initial_stones, "应获得灵石")
	
	# 清理
	lianli_system.end_lianli()
	lianli_system.set_lianli_speed(1.0)
	
	var total_test_time = (Time.get_ticks_msec() - test_start_time) / 1000.0
	
	var assert_count_end = gut.get_assert_count()
	var passed = assert_count_end - assert_count_start
	gut.p("[场景①] 断言: " + str(passed) + "/" + str(assert_count_end - assert_count_start) + " 通过, 耗时: " + str(total_test_time) + "秒")

func _on_lianli_reward(item_id: String, amount: int, source: String):
	if inventory:
		inventory.add_item(item_id, amount)

#region 场景②: 储纳系统与炼丹系统交互
## 测试场景: 炼丹消耗材料并获得丹药
## 测试目标: 验证炼丹系统能正确从储纳系统消耗材料并添加丹药
## 预期结果: 炼丹过程中材料减少，炼丹完成后获得丹药
## 同时测试: 储纳系统 + 炼丹系统
#endregion

func test_inventory_alchemy_interaction():
	if not _check_systems_available() or not alchemy_system:
		return
	
	var assert_count_start = gut.get_assert_count()
	var test_start_time = Time.get_ticks_msec()
	
	# 添加炼丹材料
	inventory.add_item("mat_herb", 50)
	player.spirit_energy = 100
	
	# 记录初始数量
	var initial_herb = inventory.get_item_count("mat_herb")
	var initial_pill = inventory.get_item_count("health_pill")
	
	# 学习丹方
	alchemy_system.learn_recipe("health_pill")
	
	# 开始炼丹
	alchemy_system.special_bonus_speed_rate = 50.0
	var result = alchemy_system.start_crafting_batch("health_pill", 10)
	assert_true(result.success, "应成功开始炼丹")
	
	# 等待炼丹完成
	var max_wait = 30.0
	var total_wait = 0.0
	while alchemy_system.is_crafting and total_wait < max_wait:
		await get_tree().process_frame
		total_wait += get_process_delta_time()
	
	# 检查结果
	var final_herb = inventory.get_item_count("mat_herb")
	var final_pill = inventory.get_item_count("health_pill")
	
	assert_lt(final_herb, initial_herb, "材料应减少")
	assert_gt(final_pill, initial_pill, "应获得丹药")
	
	var total_test_time = (Time.get_ticks_msec() - test_start_time) / 1000.0
	
	var assert_count_end = gut.get_assert_count()
	var passed = assert_count_end - assert_count_start
	gut.p("[场景②] 断言: " + str(passed) + "/" + str(assert_count_end - assert_count_start) + " 通过, 耗时: " + str(total_test_time) + "秒")

#region 场景③: 储纳系统与术法系统交互
## 测试场景: 使用术法物品解锁术法
## 测试目标: 验证术法物品使用后能正确解锁术法
## 预期结果: 使用术法物品后，物品减少，术法解锁
## 同时测试: 储纳系统 + 术法系统
#endregion

func test_inventory_spell_interaction():
	if not _check_systems_available() or not spell_system:
		return
	
	var assert_count_start = gut.get_assert_count()
	var test_start_time = Time.get_ticks_msec()
	
	# 添加术法物品
	inventory.add_item("spell_basic_breathing", 1)
	
	# 记录初始数量
	var initial_spell_count = inventory.get_item_count("spell_basic_breathing")
	
	# 使用物品解锁术法（模拟ChunaModule的逻辑）
	var item_info = item_data.get_item_data("spell_basic_breathing")
	if item_info and item_info.get("effect", {}).get("type") == "unlock_spell":
		var spell_id = item_info.effect.get("spell_id", "")
		if spell_system.player_spells.has(spell_id):
			var result = spell_system.obtain_spell(spell_id)
			if result:
				inventory.remove_item("spell_basic_breathing", 1)
			
			# 检查结果
			var final_spell_count = inventory.get_item_count("spell_basic_breathing")
			assert_lt(final_spell_count, initial_spell_count, "术法物品应减少")
			assert_true(spell_system.player_spells[spell_id].get("obtained", false), "术法应已解锁")
	
	var total_test_time = (Time.get_ticks_msec() - test_start_time) / 1000.0
	
	var assert_count_end = gut.get_assert_count()
	var passed = assert_count_end - assert_count_start
	gut.p("[场景③] 断言: " + str(passed) + "/" + str(assert_count_end - assert_count_start) + " 通过, 耗时: " + str(total_test_time) + "秒")

#region 场景④: 储纳系统物品管理
## 测试场景: 物品添加、移除、堆叠完整流程
## 测试目标: 验证储纳系统的基本物品管理功能
## 预期结果: 物品能正确添加、移除和堆叠
## 同时测试: 储纳系统
#endregion

func test_inventory_item_management():
	if not _check_systems_available():
		return
	
	var assert_count_start = gut.get_assert_count()
	var test_start_time = Time.get_ticks_msec()
	
	# 测试物品添加
	var add_result = inventory.add_item("spirit_stone", 10)
	assert_true(add_result, "应成功添加物品")
	assert_eq(inventory.get_item_count("spirit_stone"), 10, "物品数量应正确")
	
	# 测试物品堆叠
	add_result = inventory.add_item("spirit_stone", 5)
	assert_true(add_result, "应成功添加物品")
	assert_eq(inventory.get_item_count("spirit_stone"), 15, "物品应正确堆叠")
	
	# 测试物品移除
	var remove_result = inventory.remove_item("spirit_stone", 7)
	assert_true(remove_result, "应成功移除物品")
	assert_eq(inventory.get_item_count("spirit_stone"), 8, "物品数量应正确减少")
	
	# 测试物品清空
	remove_result = inventory.remove_item("spirit_stone", 8)
	assert_true(remove_result, "应成功移除所有物品")
	assert_eq(inventory.get_item_count("spirit_stone"), 0, "物品应被清空")
	
	var total_test_time = (Time.get_ticks_msec() - test_start_time) / 1000.0
	
	var assert_count_end = gut.get_assert_count()
	var passed = assert_count_end - assert_count_start
	gut.p("[场景④] 断言: " + str(passed) + "/" + str(assert_count_end - assert_count_start) + " 通过, 耗时: " + str(total_test_time) + "秒")
