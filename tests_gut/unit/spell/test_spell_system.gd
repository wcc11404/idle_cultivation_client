extends GutTest

## SpellSystem 单元测试

var spell_system: SpellSystem = null
var mock_player: Node = null
var mock_spell_data: SpellData = null

func before_all():
	await get_tree().process_frame

func before_each():
	spell_system = SpellSystem.new()
	
	mock_player = _create_mock_player()
	mock_spell_data = _create_mock_spell_data()
	
	spell_system.set_player(mock_player)
	spell_system.set_spell_data(mock_spell_data)
	
	add_child(spell_system)
	await get_tree().process_frame

func after_each():
	if spell_system:
		spell_system.queue_free()
	if mock_player:
		mock_player.queue_free()
	if mock_spell_data:
		mock_spell_data.queue_free()

func _create_mock_player() -> Node:
	var script = GDScript.new()
	script.source_code = """
extends Node
var spirit_energy: float = 100.0
"""
	script.reload()
	
	var mock = Node.new()
	mock.set_script(script)
	mock.name = "MockPlayer"
	return mock

func _create_mock_spell_data() -> SpellData:
	var mock = SpellData.new()
	mock.SPELLS = {
		"fireball": {
			"name": "火球术",
			"type": SpellData.SpellType.ACTIVE,
			"description": "发射火球",
			"max_level": 3,
			"levels": {
				1: {"spirit_cost": 10, "use_count_required": 5, "attribute_bonus": {}, "effect": {"type": "active_damage", "trigger_chance": 0.3, "damage_percent": 1.5}},
				2: {"spirit_cost": 20, "use_count_required": 10, "attribute_bonus": {"attack": 1.1}, "effect": {"type": "active_damage", "trigger_chance": 0.4, "damage_percent": 2.0}},
				3: {"spirit_cost": 30, "use_count_required": 20, "attribute_bonus": {"attack": 1.2}, "effect": {"type": "active_damage", "trigger_chance": 0.5, "damage_percent": 3.0}}
			}
		},
		"iron_skin": {
			"name": "铁皮术",
			"type": SpellData.SpellType.PASSIVE,
			"description": "增加防御",
			"max_level": 3,
			"levels": {
				1: {"spirit_cost": 15, "use_count_required": 5, "attribute_bonus": {"defense": 1.1}, "effect": {"type": "start_buff", "buff_type": "defense", "buff_percent": 0.2}}
			}
		},
		"breathing": {
			"name": "吐纳术",
			"type": SpellData.SpellType.BREATHING,
			"description": "修炼时恢复气血",
			"max_level": 3,
			"levels": {
				1: {"spirit_cost": 5, "use_count_required": 3, "attribute_bonus": {}, "effect": {"type": "passive_heal", "heal_percent": 0.02}}
			}
		}
	}
	
	mock.MAX_BREATHING_SPELLS = 1
	mock.MAX_ACTIVE_SPELLS = 2
	mock.MAX_PASSIVE_SPELLS = 2
	return mock

#region 初始化测试

func test_init_player_spells():
	assert_true(spell_system.player_spells.has("fireball"), "应初始化火球术")
	assert_true(spell_system.player_spells.has("iron_skin"), "应初始化铁皮术")
	assert_false(spell_system.player_spells["fireball"]["obtained"], "初始术法应为未获取")

func test_init_equipped_spells():
	assert_true(spell_system.equipped_spells.has(SpellData.SpellType.BREATHING), "应有吐纳槽位")
	assert_true(spell_system.equipped_spells.has(SpellData.SpellType.ACTIVE), "应有主动槽位")
	assert_true(spell_system.equipped_spells.has(SpellData.SpellType.PASSIVE), "应有被动槽位")
	assert_eq(spell_system.equipped_spells[SpellData.SpellType.ACTIVE].size(), 0, "初始装备槽应为空")

#endregion

#region 获取术法测试

func test_obtain_spell():
	var result = spell_system.obtain_spell("fireball")
	assert_true(result, "获取术法应成功")
	assert_true(spell_system.player_spells["fireball"]["obtained"], "术法应标记为已获取")
	assert_eq(spell_system.player_spells["fireball"]["level"], 1, "获取后等级应为1")

func test_obtain_spell_already_obtained():
	spell_system.obtain_spell("fireball")
	var result = spell_system.obtain_spell("fireball")
	assert_false(result, "重复获取应失败")

func test_obtain_spell_invalid():
	var result = spell_system.obtain_spell("invalid_spell")
	assert_false(result, "获取无效术法应失败")

#endregion

#region 装备术法测试

func test_equip_spell():
	spell_system.obtain_spell("fireball")
	var result = spell_system.equip_spell("fireball")
	assert_true(result.success, "装备术法应成功")
	assert_true(spell_system.is_spell_equipped("fireball"), "术法应已装备")

func test_equip_spell_not_obtained():
	var result = spell_system.equip_spell("fireball")
	assert_false(result.success, "装备未获取术法应失败")
	assert_eq(result.reason, "未获取该术法", "失败原因应正确")

func test_equip_spell_already_equipped():
	spell_system.obtain_spell("fireball")
	spell_system.equip_spell("fireball")
	var result = spell_system.equip_spell("fireball")
	assert_false(result.success, "重复装备应失败")

func test_unequip_spell():
	spell_system.obtain_spell("fireball")
	spell_system.equip_spell("fireball")
	var result = spell_system.unequip_spell("fireball")
	assert_true(result.success, "卸下术法应成功")
	assert_false(spell_system.is_spell_equipped("fireball"), "术法应已卸下")

func test_unequip_spell_not_equipped():
	spell_system.obtain_spell("fireball")
	var result = spell_system.unequip_spell("fireball")
	assert_false(result.success, "卸下未装备术法应失败")

#endregion

#region 装备数量测试

func test_get_equipped_count():
	spell_system.obtain_spell("fireball")
	spell_system.equip_spell("fireball")
	assert_eq(spell_system.get_equipped_count(SpellData.SpellType.ACTIVE), 1, "已装备数量应为1")

func test_get_equipment_limit():
	assert_eq(spell_system.get_equipment_limit(SpellData.SpellType.ACTIVE), 2, "主动术法上限应为2")
	assert_eq(spell_system.get_equipment_limit(SpellData.SpellType.PASSIVE), 2, "被动术法上限应为2")

#endregion

#region 属性加成测试

func test_get_attribute_bonuses_empty():
	var bonuses = spell_system.get_attribute_bonuses()
	assert_eq(bonuses.attack, 1.0, "无术法时攻击加成应为1.0")
	assert_eq(bonuses.defense, 1.0, "无术法时防御加成应为1.0")
	assert_eq(bonuses.speed, 0.0, "无术法时速度加成应为0")

func test_get_attribute_bonuses_with_spell():
	spell_system.obtain_spell("iron_skin")
	spell_system.equip_spell("iron_skin")
	
	var bonuses = spell_system.get_attribute_bonuses()
	assert_eq(bonuses.defense, 1.1, "铁皮术应增加10%防御")

#endregion

#region 存档数据测试

func test_get_save_data():
	spell_system.obtain_spell("fireball")
	spell_system.equip_spell("fireball")
	spell_system.player_spells["fireball"]["use_count"] = 5
	spell_system.player_spells["fireball"]["charged_spirit"] = 10
	
	var data = spell_system.get_save_data()
	
	assert_true(data.has("player_spells"), "存档应有术法数据")
	assert_true(data.player_spells.has("fireball"), "存档应包含火球术")
	assert_true(data.has("equipped_spells"), "存档应有装备数据")

func test_apply_save_data():
	var save_data = {
		"player_spells": {
			"fireball": {"obtained": true, "level": 2, "use_count": 5, "charged_spirit": 15}
		},
		"equipped_spells": {SpellData.SpellType.ACTIVE: ["fireball"]}
	}
	
	spell_system.apply_save_data(save_data)
	
	assert_true(spell_system.player_spells["fireball"]["obtained"], "加载后术法应已获取")
	assert_eq(spell_system.player_spells["fireball"]["level"], 2, "加载后等级应正确")
	assert_true(spell_system.is_spell_equipped("fireball"), "加载后应已装备")

#endregion
