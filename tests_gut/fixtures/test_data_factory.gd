extends Node

## 测试数据工厂
## 用于生成测试所需的模拟数据

class_name TestDataFactory

#region 玩家数据

static func create_player_data() -> Dictionary:
	return {
		"realm": "炼气期",
		"realm_level": 1,
		"health": 100.0,
		"spirit_energy": 0.0,
		"base_attack": 50.0,
		"base_defense": 25.0,
		"base_speed": 5.0,
		"base_max_health": 100.0,
		"base_max_spirit": 50.0,
		"tower_highest_floor": 0,
		"daily_dungeon_data": {}
	}

static func create_player_data_advanced() -> Dictionary:
	return {
		"realm": "筑基期",
		"realm_level": 5,
		"health": 500.0,
		"spirit_energy": 100.0,
		"base_attack": 150.0,
		"base_defense": 75.0,
		"base_speed": 8.0,
		"base_max_health": 500.0,
		"base_max_spirit": 200.0,
		"tower_highest_floor": 10,
		"daily_dungeon_data": {}
	}

#endregion

#region 敌人数据

static func create_enemy_data(level: int = 1) -> Dictionary:
	var level_mult = 1.0 + (level - 1) * 0.1
	return {
		"id": "test_enemy",
		"name": "测试敌人 Lv." + str(level),
		"health": int(100 * level_mult),
		"attack": int(20 * level_mult),
		"defense": int(5 * level_mult),
		"speed": 4,
		"is_elite": false,
		"drops": {
			"spirit_stone": {"chance": 1.0, "min": 1, "max": 5}
		}
	}

static func create_elite_enemy_data(level: int = 1) -> Dictionary:
	var level_mult = 1.0 + (level - 1) * 0.15
	return {
		"id": "test_elite",
		"name": "精英敌人 Lv." + str(level),
		"health": int(300 * level_mult),
		"attack": int(50 * level_mult),
		"defense": int(20 * level_mult),
		"speed": 6,
		"is_elite": true,
		"drops": {
			"spirit_stone": {"chance": 1.0, "min": 10, "max": 30},
			"rare_material": {"chance": 0.3, "min": 1, "max": 1}
		}
	}

static func create_boss_enemy_data(level: int = 1) -> Dictionary:
	var level_mult = 1.0 + (level - 1) * 0.2
	return {
		"id": "test_boss",
		"name": "Boss Lv." + str(level),
		"health": int(1000 * level_mult),
		"attack": int(100 * level_mult),
		"defense": int(50 * level_mult),
		"speed": 5,
		"is_elite": true,
		"is_boss": true,
		"drops": {
			"spirit_stone": {"chance": 1.0, "min": 100, "max": 200},
			"rare_item": {"chance": 1.0, "min": 1, "max": 1}
		}
	}

#endregion

#region 物品数据

static func create_item_data() -> Dictionary:
	return {
		"spirit_stone": {
			"name": "灵石",
			"description": "修仙者的通用货币",
			"max_stack": 999,
			"can_stack": true,
			"rarity": "common"
		},
		"herb": {
			"name": "灵草",
			"description": "炼丹的基础材料",
			"max_stack": 99,
			"can_stack": true,
			"rarity": "common"
		},
		"qi_pill": {
			"name": "聚气丹",
			"description": "增加灵气",
			"max_stack": 10,
			"can_stack": true,
			"rarity": "uncommon",
			"effect": {"type": "spirit", "value": 50}
		},
		"healing_pill": {
			"name": "疗伤丹",
			"description": "恢复气血",
			"max_stack": 10,
			"can_stack": true,
			"rarity": "uncommon",
			"effect": {"type": "heal", "value": 100}
		}
	}

static func create_material_data() -> Dictionary:
	return {
		"herb": {"name": "灵草", "max_stack": 99, "can_stack": true},
		"spirit_water": {"name": "灵水", "max_stack": 50, "can_stack": true},
		"blood_grass": {"name": "血灵草", "max_stack": 50, "can_stack": true},
		"rare_herb": {"name": "稀有灵草", "max_stack": 20, "can_stack": true},
		"spirit_crystal": {"name": "灵晶", "max_stack": 10, "can_stack": true}
	}

#endregion

#region 丹方数据

static func create_recipe_data() -> Dictionary:
	return {
		"qi_pill": {
			"name": "聚气丹",
			"success_value": 60,
			"base_time": 5.0,
			"spirit_energy": 10,
			"materials": {"herb": 2, "spirit_water": 1},
			"product": "qi_pill",
			"product_count": 1
		},
		"healing_pill": {
			"name": "疗伤丹",
			"success_value": 50,
			"base_time": 8.0,
			"spirit_energy": 20,
			"materials": {"herb": 3, "blood_grass": 1},
			"product": "healing_pill",
			"product_count": 1
		},
		"foundation_pill": {
			"name": "筑基丹",
			"success_value": 30,
			"base_time": 15.0,
			"spirit_energy": 50,
			"materials": {"rare_herb": 5, "spirit_crystal": 1},
			"product": "foundation_pill",
			"product_count": 1
		}
	}

#endregion

#region 术法数据

static func create_spell_data() -> Dictionary:
	return {
		"fireball": {
			"name": "火球术",
			"type": 1,
			"description": "发射火球攻击敌人",
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
			"type": 2,
			"description": "增加防御力",
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
			"type": 0,
			"description": "修炼时恢复气血",
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

#endregion

#region 历练区域数据

static func create_lianli_area_data() -> Dictionary:
	return {
		"qi_refining_outer": {
			"name": "炼气期外围",
			"type": "normal",
			"enemies": [
				{"template": "qi_monster", "min_level": 1, "max_level": 3}
			],
			"drops": {"spirit_stone": {"chance": 1.0, "min": 1, "max": 3}}
		},
		"qi_refining_inner": {
			"name": "炼气期内围",
			"type": "normal",
			"enemies": [
				{"template": "qi_monster", "min_level": 3, "max_level": 5}
			],
			"drops": {"spirit_stone": {"chance": 1.0, "min": 3, "max": 8}}
		},
		"foundation_herb_cave": {
			"name": "破境草洞穴",
			"type": "special",
			"enemies": [
				{"template": "herb_guardian", "min_level": 5, "max_level": 5}
			],
			"drops": {"spirit_stone": {"chance": 1.0, "min": 5, "max": 10}},
			"special_drops": {"rare_herb": 1}
		}
	}

#endregion

#region 存档数据

static func create_save_data() -> Dictionary:
	return {
		"player": create_player_data(),
		"inventory": {
			"capacity": 50,
			"slots": {}
		},
		"spell_system": {
			"player_spells": {},
			"equipped_spells": {0: [], 1: [], 2: []}
		},
		"alchemy_system": {
			"equipped_furnace_id": "",
			"learned_recipes": []
		},
		"lianli_system": {
			"tower_highest_floor": 0,
			"daily_dungeon_data": {}
		},
		"version": "1.0.0",
		"timestamp": Time.get_unix_time_from_system()
	}

static func create_complete_save_data() -> Dictionary:
	return {
		"player": create_player_data_advanced(),
		"inventory": {
			"capacity": 60,
			"slots": {
				"0": {"id": "spirit_stone", "count": 1000},
				"1": {"id": "herb", "count": 50}
			}
		},
		"spell_system": {
			"player_spells": {
				"fireball": {"obtained": true, "level": 2, "use_count": 10, "charged_spirit": 15}
			},
			"equipped_spells": {0: [], 1: ["fireball"], 2: []}
		},
		"alchemy_system": {
			"equipped_furnace_id": "alchemy_furnace",
			"learned_recipes": ["qi_pill", "healing_pill"]
		},
		"lianli_system": {
			"tower_highest_floor": 10,
			"daily_dungeon_data": {}
		},
		"version": "1.0.0",
		"timestamp": Time.get_unix_time_from_system()
	}

#endregion

#region 战斗Buff数据

static func create_combat_buffs() -> Dictionary:
	return {
		"attack_percent": 0.0,
		"defense_percent": 0.0,
		"speed_bonus": 0.0,
		"health_bonus": 0.0
	}

static func create_combat_buffs_with_bonuses() -> Dictionary:
	return {
		"attack_percent": 0.2,
		"defense_percent": 0.1,
		"speed_bonus": 3.0,
		"health_bonus": 100.0
	}

#endregion
