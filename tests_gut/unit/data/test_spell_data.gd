extends GutTest

## SpellData 单元测试

var spell_data: SpellData = null

func before_all():
	await get_tree().process_frame

func before_each():
	spell_data = SpellData.new()
	
	add_child(spell_data)
	await get_tree().process_frame
	
	# 在 _ready 之后设置 mock 数据，覆盖从 JSON 加载的数据
	_setup_mock_data()

func after_each():
	if spell_data:
		spell_data.queue_free()

func _setup_mock_data():
	spell_data.SPELLS = {
		"fireball": {
			"name": "火球术",
			"description": "发射火球攻击敌人",
			"type": SpellData.SpellType.ACTIVE,
			"max_level": 3,
			"levels": {
				1: {
					"spirit_cost": 10,
					"use_count_required": 5,
					"attribute_bonus": {},
					"effect": {"type": "active_damage", "trigger_chance": 0.3, "damage_percent": 1.5}
				},
				2: {
					"spirit_cost": 20,
					"use_count_required": 10,
					"attribute_bonus": {"attack": 1.1},
					"effect": {"type": "active_damage", "trigger_chance": 0.4, "damage_percent": 2.0}
				},
				3: {
					"spirit_cost": 30,
					"use_count_required": 20,
					"attribute_bonus": {"attack": 1.2},
					"effect": {"type": "active_damage", "trigger_chance": 0.5, "damage_percent": 3.0}
				}
			}
		},
		"iron_skin": {
			"name": "铁皮术",
			"description": "增加防御力",
			"type": SpellData.SpellType.PASSIVE,
			"max_level": 3,
			"levels": {
				1: {
					"spirit_cost": 15,
					"use_count_required": 5,
					"attribute_bonus": {"defense": 1.1},
					"effect": {"type": "start_buff", "buff_type": "defense", "buff_percent": 0.2}
				}
			}
		},
		"breathing": {
			"name": "吐纳术",
			"description": "修炼时恢复气血",
			"type": SpellData.SpellType.BREATHING,
			"max_level": 3,
			"levels": {
				1: {
					"spirit_cost": 5,
					"use_count_required": 3,
					"attribute_bonus": {},
					"effect": {"type": "passive_heal", "heal_percent": 0.02}
				}
			}
		}
	}
	
	spell_data.MAX_BREATHING_SPELLS = 1
	spell_data.MAX_ACTIVE_SPELLS = 2
	spell_data.MAX_PASSIVE_SPELLS = 2

#region 初始化测试

func test_initial_spells():
	assert_eq(spell_data.SPELLS.size(), 3, "应有3个术法")

func test_spell_type_enum():
	assert_eq(spell_data.SpellType.BREATHING, 0, "吐纳类型应为0")
	assert_eq(spell_data.SpellType.ACTIVE, 1, "主动类型应为1")
	assert_eq(spell_data.SpellType.PASSIVE, 2, "被动类型应为2")
	assert_eq(spell_data.SpellType.MISC, 3, "特殊类型应为3")

#endregion

#region 获取术法数据测试

func test_get_spell_data():
	var data = spell_data.get_spell_data("fireball")
	assert_eq(data.get("name", ""), "火球术", "术法名称应正确")

func test_get_spell_data_invalid():
	var data = spell_data.get_spell_data("invalid_spell")
	assert_eq(data, {}, "无效术法应返回空字典")

func test_get_spell_name():
	var name = spell_data.get_spell_name("fireball")
	assert_eq(name, "火球术", "术法名称应正确")

func test_get_spell_name_invalid():
	var name = spell_data.get_spell_name("invalid_spell")
	assert_eq(name, "未知术法", "无效术法应返回未知术法")

#endregion

#region 术法类型测试

func test_get_spell_type():
	var type = spell_data.get_spell_type("fireball")
	assert_eq(type, SpellData.SpellType.ACTIVE, "火球术应为主动类型")

func test_get_spell_type_passive():
	var type = spell_data.get_spell_type("iron_skin")
	assert_eq(type, SpellData.SpellType.PASSIVE, "铁皮术应为被动类型")

func test_get_spell_type_breathing():
	var type = spell_data.get_spell_type("breathing")
	assert_eq(type, SpellData.SpellType.BREATHING, "吐纳术应为吐纳类型")

func test_get_spell_type_invalid():
	var type = spell_data.get_spell_type("invalid_spell")
	assert_eq(type, SpellData.SpellType.ACTIVE, "无效术法应返回主动类型")

func test_get_spell_type_name():
	var name = spell_data.get_spell_type_name(SpellData.SpellType.ACTIVE)
	assert_eq(name, "主动术法", "主动类型名称应正确")

func test_get_spell_type_name_passive():
	var name = spell_data.get_spell_type_name(SpellData.SpellType.PASSIVE)
	assert_eq(name, "被动术法", "被动类型名称应正确")

func test_get_spell_type_name_breathing():
	var name = spell_data.get_spell_type_name(SpellData.SpellType.BREATHING)
	assert_eq(name, "吐纳心法", "吐纳类型名称应正确")

func test_get_spell_type_name_invalid():
	var name = spell_data.get_spell_type_name(999)
	assert_eq(name, "未知", "无效类型应返回未知")

#endregion

#region 等级数据测试

func test_get_spell_level_data():
	var data = spell_data.get_spell_level_data("fireball", 1)
	assert_eq(data.get("spirit_cost", 0), 10, "1级灵气消耗应为10")

func test_get_spell_level_data_level_2():
	var data = spell_data.get_spell_level_data("fireball", 2)
	assert_eq(data.get("spirit_cost", 0), 20, "2级灵气消耗应为20")

func test_get_spell_level_data_invalid_spell():
	var data = spell_data.get_spell_level_data("invalid_spell", 1)
	assert_eq(data, {}, "无效术法应返回空字典")

func test_get_spell_level_data_invalid_level():
	var data = spell_data.get_spell_level_data("fireball", 999)
	assert_eq(data, {}, "无效等级应返回空字典")

func test_get_max_level_from_data():
	var data = spell_data.get_spell_data("fireball")
	assert_eq(data.get("max_level", 1), 3, "火球术最大等级应为3")

func test_get_max_level_invalid():
	var data = spell_data.get_spell_data("invalid_spell")
	assert_eq(data.get("max_level", 1), 1, "无效术法最大等级应为1")

#endregion

#region 灵气消耗测试

func test_get_spirit_cost():
	var data = spell_data.get_spell_level_data("fireball", 1)
	assert_eq(data.get("spirit_cost", 0), 10, "1级灵气消耗应为10")

func test_get_spirit_cost_level_2():
	var data = spell_data.get_spell_level_data("fireball", 2)
	assert_eq(data.get("spirit_cost", 0), 20, "2级灵气消耗应为20")

func test_get_spirit_cost_invalid():
	var data = spell_data.get_spell_level_data("invalid_spell", 1)
	assert_eq(data.get("spirit_cost", 0), 0, "无效术法灵气消耗应为0")

#endregion

#region 使用次数需求测试

func test_get_use_count_required():
	var data = spell_data.get_spell_level_data("fireball", 1)
	assert_eq(data.get("use_count_required", 0), 5, "1级使用次数需求应为5")

func test_get_use_count_required_level_2():
	var data = spell_data.get_spell_level_data("fireball", 2)
	assert_eq(data.get("use_count_required", 0), 10, "2级使用次数需求应为10")

func test_get_use_count_required_invalid():
	var data = spell_data.get_spell_level_data("invalid_spell", 1)
	assert_eq(data.get("use_count_required", 0), 0, "无效术法使用次数需求应为0")

#endregion

#region 属性加成测试

func test_get_attribute_bonus():
	var data = spell_data.get_spell_level_data("fireball", 2)
	var bonus = data.get("attribute_bonus", {})
	assert_eq(bonus.get("attack", 1.0), 1.1, "2级应有10%攻击加成")

func test_get_attribute_bonus_empty():
	var data = spell_data.get_spell_level_data("fireball", 1)
	var bonus = data.get("attribute_bonus", {})
	assert_eq(bonus, {}, "1级应无属性加成")

func test_get_attribute_bonus_defense():
	var data = spell_data.get_spell_level_data("iron_skin", 1)
	var bonus = data.get("attribute_bonus", {})
	assert_eq(bonus.get("defense", 1.0), 1.1, "铁皮术应有10%防御加成")

#endregion

#region 效果测试

func test_get_spell_effect():
	var data = spell_data.get_spell_level_data("fireball", 1)
	var effect = data.get("effect", {})
	assert_eq(effect.get("type", ""), "active_damage", "效果类型应正确")
	assert_eq(effect.get("trigger_chance", 0), 0.3, "触发几率应正确")

func test_get_spell_effect_invalid():
	var data = spell_data.get_spell_level_data("invalid_spell", 1)
	var effect = data.get("effect", {})
	assert_eq(effect, {}, "无效术法应返回空字典")

#endregion

#region 装备上限测试

func test_get_equipment_limit_breathing():
	var limit = spell_data.get_equipment_limit(SpellData.SpellType.BREATHING)
	assert_eq(limit, 1, "吐纳术上限应为1")

func test_get_equipment_limit_active():
	var limit = spell_data.get_equipment_limit(SpellData.SpellType.ACTIVE)
	assert_eq(limit, 2, "主动术法上限应为2")

func test_get_equipment_limit_passive():
	var limit = spell_data.get_equipment_limit(SpellData.SpellType.PASSIVE)
	assert_eq(limit, 2, "被动术法上限应为2")

func test_get_equipment_limit_misc():
	var limit = spell_data.get_equipment_limit(SpellData.SpellType.MISC)
	assert_eq(limit, -1, "特殊术法上限应为-1（无限制）")

func test_get_equipment_limit_invalid():
	var limit = spell_data.get_equipment_limit(999)
	assert_eq(limit, 1, "无效类型上限应为1")

#endregion

#region 获取所有术法ID测试

func test_get_all_spell_ids():
	var ids = spell_data.get_all_spell_ids()
	assert_eq(ids.size(), 3, "应有3个术法ID")

func test_get_spell_ids_by_type():
	var ids = spell_data.get_spell_ids_by_type(SpellData.SpellType.ACTIVE)
	assert_eq(ids.size(), 1, "应有1个主动术法")
	assert_true("fireball" in ids, "应包含火球术")

func test_get_spell_ids_by_type_passive():
	var ids = spell_data.get_spell_ids_by_type(SpellData.SpellType.PASSIVE)
	assert_eq(ids.size(), 1, "应有1个被动术法")
	assert_true("iron_skin" in ids, "应包含铁皮术")

func test_get_spell_ids_by_type_breathing():
	var ids = spell_data.get_spell_ids_by_type(SpellData.SpellType.BREATHING)
	assert_eq(ids.size(), 1, "应有1个吐纳术法")
	assert_true("breathing" in ids, "应包含吐纳术")

#endregion
