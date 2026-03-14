extends GutTest

## PlayerData 单元测试

var player: PlayerData = null

func before_all():
	await get_tree().process_frame

func before_each():
	player = PlayerData.new()
	add_child(player)
	await get_tree().process_frame

func after_each():
	if player:
		player.queue_free()

#region 初始值测试

func test_initial_realm():
	assert_eq(player.realm, "炼气期", "初始境界应为炼气期")

func test_initial_realm_level():
	assert_eq(player.realm_level, 1, "初始境界等级应为1")

func test_initial_health():
	assert_gt(player.health, 0, "初始气血应大于0")

func test_initial_spirit_energy():
	assert_eq(player.spirit_energy, 0.0, "初始灵气应为0")

func test_initial_tower_floor():
	assert_eq(player.tower_highest_floor, 0, "初始无尽塔层数应为0")

func test_initial_combat_buffs():
	assert_eq(player.combat_buffs, {}, "初始战斗Buff应为空")

func test_initial_cultivation_active():
	assert_false(player.cultivation_active, "初始不应在修炼中")

#endregion

#region 气血管理测试

func test_take_damage():
	player.health = 100.0
	var new_health = player.take_damage(30.0)
	assert_eq(new_health, 70.0, "受伤后气血应减少")
	assert_eq(player.health, 70.0, "玩家气血应为70")

func test_take_damage_to_zero():
	player.health = 50.0
	var new_health = player.take_damage(100.0)
	assert_eq(new_health, 0.0, "气血不应小于0")
	assert_eq(player.health, 0.0, "玩家气血应为0")

func test_heal():
	var max_health = player.get_final_max_health()
	player.health = max_health * 0.5
	var new_health = player.heal(max_health * 0.3)
	assert_eq(new_health, max_health * 0.8, "治疗后气血应正确")
	assert_eq(player.health, max_health * 0.8, "玩家气血应正确")

func test_heal_not_exceed_max():
	player.health = player.get_final_max_health() - 10.0
	var max_health = player.get_final_max_health()
	var new_health = player.heal(1000.0)
	assert_eq(player.health, max_health, "气血不应超过最大值")

func test_set_health():
	player.set_health(75.0)
	assert_eq(player.health, 75.0, "设置气血应正确")

func test_set_health_negative():
	player.set_health(-10.0)
	assert_eq(player.health, 0.0, "负值气血应为0")

#endregion

#region 灵气管理测试

func test_add_spirit_energy():
	player.spirit_energy = 0.0
	var max_spirit = player.get_final_max_spirit_energy()
	player.add_spirit_energy(10.0)
	assert_lte(player.spirit_energy, max_spirit, "灵气不应超过最大值")

func test_add_spirit_energy_unlimited():
	player.spirit_energy = 100.0
	player.add_spirit_energy_unlimited(50.0)
	assert_eq(player.spirit_energy, 150.0, "无限制灵气应正确增加")

func test_consume_spirit():
	player.spirit_energy = 50.0
	var result = player.consume_spirit(20.0)
	assert_true(result, "消耗灵气应成功")
	assert_eq(player.spirit_energy, 30.0, "灵气应减少")

func test_consume_spirit_insufficient():
	player.spirit_energy = 10.0
	var result = player.consume_spirit(20.0)
	assert_false(result, "灵气不足时应失败")
	assert_eq(player.spirit_energy, 10.0, "灵气不应变化")

func test_set_spirit():
	player.set_spirit(50.0)
	assert_eq(player.spirit_energy, 50.0, "设置灵气应正确")

func test_set_spirit_negative():
	player.set_spirit(-10.0)
	assert_eq(player.spirit_energy, 0.0, "负值灵气应为0")

#endregion

#region 战斗Buff测试

func test_set_combat_buffs():
	var buffs = {"attack_percent": 0.2, "defense_percent": 0.1}
	player.set_combat_buffs(buffs)
	assert_eq(player.combat_buffs, buffs, "战斗Buff应正确设置")

func test_get_combat_buffs():
	var buffs = {"attack_percent": 0.2}
	player.set_combat_buffs(buffs)
	var result = player.get_combat_buffs()
	assert_eq(result, buffs, "获取战斗Buff应正确")

func test_clear_combat_buffs():
	player.set_combat_buffs({"attack_percent": 0.2})
	player.clear_combat_buffs()
	assert_eq(player.combat_buffs, {}, "清除后Buff应为空")

#endregion

#region 存档数据测试

func test_get_save_data():
	player.realm = "筑基期"
	player.realm_level = 5
	player.tower_highest_floor = 10
	
	var data = player.get_save_data()
	
	assert_eq(data.realm, "筑基期", "存档境界应正确")
	assert_eq(data.realm_level, 5, "存档境界等级应正确")
	assert_eq(data.tower_highest_floor, 10, "存档无尽塔层数应正确")

func test_apply_save_data_basic():
	var save_data = {
		"realm": "金丹期",
		"realm_level": 3,
		"tower_highest_floor": 20,
		"daily_dungeon_data": {}
	}
	
	player.apply_save_data(save_data)
	
	assert_eq(player.realm, "金丹期", "加载境界应正确")
	assert_eq(player.realm_level, 3, "加载境界等级应正确")
	assert_eq(player.tower_highest_floor, 20, "加载无尽塔层数应正确")

func test_save_data_contains_health():
	var data = player.get_save_data()
	assert_true(data.has("health"), "存档应包含health")
	assert_true(data.has("spirit_energy"), "存档应包含spirit_energy")

#endregion

#region 每日副本测试

func test_get_daily_dungeon_count_initial():
	var count = player.get_daily_dungeon_count("test_dungeon")
	assert_eq(count, PlayerData.DAILY_DUNGEON_MAX_COUNT, "初始副本次数应为最大值")

func test_use_daily_dungeon_count():
	player.get_daily_dungeon_count("test_dungeon")
	var result = player.use_daily_dungeon_count("test_dungeon")
	assert_true(result, "使用副本次数应成功")
	var count = player.get_daily_dungeon_count("test_dungeon")
	assert_eq(count, PlayerData.DAILY_DUNGEON_MAX_COUNT - 1, "使用后次数应减少")

func test_use_daily_dungeon_count_exhausted():
	for i in range(PlayerData.DAILY_DUNGEON_MAX_COUNT):
		player.use_daily_dungeon_count("exhausted_dungeon")
	var result = player.use_daily_dungeon_count("exhausted_dungeon")
	assert_false(result, "次数用尽时应失败")

#endregion

#region 最终属性测试

func test_get_final_attack():
	var attack = player.get_final_attack()
	assert_gt(attack, 0, "最终攻击力应大于0")

func test_get_final_defense():
	var defense = player.get_final_defense()
	assert_gt(defense, 0, "最终防御力应大于0")

func test_get_final_speed():
	var speed = player.get_final_speed()
	assert_gt(speed, 0, "最终速度应大于0")

func test_get_final_max_health():
	var health = player.get_final_max_health()
	assert_gt(health, 0, "最终最大气血应大于0")

func test_get_final_max_spirit_energy():
	var spirit = player.get_final_max_spirit_energy()
	assert_gt(spirit, 0, "最终最大灵气应大于0")

#endregion

#region 修炼状态测试

func test_get_is_cultivating():
	assert_false(player.get_is_cultivating(), "初始不应在修炼中")
	player.cultivation_active = true
	assert_true(player.get_is_cultivating(), "设置后应在修炼中")
	player.cultivation_active = false
	assert_false(player.get_is_cultivating(), "取消后不应在修炼中")

#endregion

#region 境界属性测试

func test_apply_realm_stats():
	player.realm = "炼气期"
	player.realm_level = 5
	player.apply_realm_stats()
	assert_eq(player.realm, "炼气期", "设置境界应正确")
	assert_eq(player.realm_level, 5, "设置境界等级应正确")

#endregion
