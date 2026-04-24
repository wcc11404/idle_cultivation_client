class_name LianliAreaData extends Node

var NORMAL_AREAS: Dictionary = {}
var DAILY_AREAS: Dictionary = {}
var TOWER_CONFIG: Dictionary = {}

func _ready():
	_load_config()

func _load_config():
	var file = FileAccess.open("res://scripts/core/lianli/areas.json", FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		var data = JSON.parse_string(json_text)
		if data:
			NORMAL_AREAS = data.get("normal_areas", {})
			DAILY_AREAS = data.get("daily_areas", {})
			TOWER_CONFIG = data.get("tower", {})
			
			_convert_area_data_types(NORMAL_AREAS)
			_convert_area_data_types(DAILY_AREAS)
			_convert_tower_data_types()

func _convert_area_data_types(areas: Dictionary):
	for area_id in areas.keys():
		var enemies_template = areas[area_id].get("enemies_template", [])
		for enemy_group in enemies_template:
			if enemy_group.is_empty():
				continue
			
			enemy_group["weight"] = int(enemy_group.get("weight", 1))
			
			var enemies_list = enemy_group.get("enemies", [])
			for enemy_info in enemies_list:
				enemy_info["min_level"] = int(enemy_info.get("min_level", 1))
				enemy_info["max_level"] = int(enemy_info.get("max_level", 1))
			
			if enemy_group.has("drops"):
				for item_id in enemy_group["drops"].keys():
					var drop_info = enemy_group["drops"][item_id]
					drop_info["min"] = int(drop_info.get("min", 0))
					drop_info["max"] = int(drop_info.get("max", 0))
					if drop_info.has("chance"):
						drop_info["chance"] = float(drop_info["chance"])
					else:
						drop_info["chance"] = 1.0

func _convert_tower_data_types():
	if TOWER_CONFIG.is_empty():
		return
	var config = TOWER_CONFIG.get("config", {})
	if not (config is Dictionary):
		return

	var reward_floors = config.get("reward_floors", [])
	var normalized_reward_floors: Array = []
	for floor in reward_floors:
		normalized_reward_floors.append(int(floor))
	config["reward_floors"] = normalized_reward_floors

	var rewards = config.get("rewards", {})
	if rewards is Dictionary:
		for reward_floor in rewards.keys():
			var reward_data = rewards[reward_floor]
			if not (reward_data is Dictionary):
				continue
			for item_id in reward_data.keys():
				reward_data[item_id] = int(reward_data[item_id])

# ==================== 普通区域相关函数 ====================

func get_normal_areas() -> Dictionary:
	return NORMAL_AREAS.duplicate()

func get_normal_area_ids() -> Array:
	return NORMAL_AREAS.keys()

func is_normal_area(area_id: String) -> bool:
	return NORMAL_AREAS.has(area_id)

# ==================== 每日区域相关函数 ====================

func get_daily_areas() -> Dictionary:
	return DAILY_AREAS.duplicate()

func get_daily_area_ids() -> Array:
	return DAILY_AREAS.keys()

func is_daily_area(area_id: String) -> bool:
	return DAILY_AREAS.has(area_id)

func is_special_area(area_id: String) -> bool:
	return DAILY_AREAS.has(area_id)

func is_single_boss_area(area_id: String) -> bool:
	if DAILY_AREAS.has(area_id):
		return DAILY_AREAS[area_id].get("is_single_boss", false)
	return false

func get_special_drops(area_id: String) -> Dictionary:
	if DAILY_AREAS.has(area_id):
		return DAILY_AREAS[area_id].get("special_drops", {}).duplicate()
	return {}

# ==================== 通用区域函数 ====================

func get_all_areas() -> Dictionary:
	var all_areas = NORMAL_AREAS.duplicate()
	for area_id in DAILY_AREAS.keys():
		all_areas[area_id] = DAILY_AREAS[area_id]
	return all_areas

func get_all_area_ids() -> Array:
	var ids = []
	ids.append_array(NORMAL_AREAS.keys())
	ids.append_array(DAILY_AREAS.keys())
	return ids

func get_area_data(area_id: String) -> Dictionary:
	if NORMAL_AREAS.has(area_id):
		return NORMAL_AREAS[area_id].duplicate()
	if DAILY_AREAS.has(area_id):
		return DAILY_AREAS[area_id].duplicate()
	return {}

func get_area_name(area_id: String) -> String:
	if NORMAL_AREAS.has(area_id):
		return NORMAL_AREAS[area_id].get("name", "未知区域")
	if DAILY_AREAS.has(area_id):
		return DAILY_AREAS[area_id].get("name", "未知区域")
	if is_tower_area(area_id):
		return get_tower_name()
	return "未知区域"

func get_area_description(area_id: String) -> String:
	if NORMAL_AREAS.has(area_id):
		return NORMAL_AREAS[area_id].get("description", "")
	if DAILY_AREAS.has(area_id):
		return DAILY_AREAS[area_id].get("description", "")
	if is_tower_area(area_id):
		return get_tower_description()
	return ""

func get_default_continuous(area_id: String) -> bool:
	var area = get_area_data(area_id)
	return area.get("default_continuous", true)

func get_random_enemy_config(area_id: String) -> Dictionary:
	var area = get_area_data(area_id)
	if area.is_empty():
		return {}
	
	var enemies_template = area.get("enemies_template", [])
	if enemies_template.is_empty():
		return {}
	
	var total_weight = 0
	for enemy_group in enemies_template:
		total_weight += enemy_group.get("weight", 0)
	
	if total_weight <= 0:
		return enemies_template[0].duplicate()
	
	var random_value = randi() % int(total_weight)
	var current_weight = 0
	
	for enemy_group in enemies_template:
		current_weight += enemy_group.get("weight", 0)
		if random_value < current_weight:
			return enemy_group.duplicate()
	
	return enemies_template[0].duplicate()

func get_enemies_list(area_id: String) -> Array:
	var area = get_area_data(area_id)
	return area.get("enemies_template", []).duplicate()

# ==================== 无尽塔相关函数 ====================

func get_tower_config() -> Dictionary:
	return TOWER_CONFIG.duplicate()

func get_tower_max_floor() -> int:
	return int(TOWER_CONFIG.get("max_floor", 51))

func get_tower_id() -> String:
	return TOWER_CONFIG.get("id", "sourth_endless_tower")

func is_tower_area(area_id: String) -> bool:
	return area_id == TOWER_CONFIG.get("id", "sourth_endless_tower")

func get_tower_name() -> String:
	var config = TOWER_CONFIG.get("config", {})
	return config.get("name", "无尽塔")

func get_tower_description() -> String:
	var config = TOWER_CONFIG.get("config", {})
	return config.get("description", "")

func get_tower_reward_floors() -> Array:
	var config = TOWER_CONFIG.get("config", {})
	var raw_reward_floors = config.get("reward_floors", [])
	var normalized_reward_floors: Array = []
	for floor in raw_reward_floors:
		normalized_reward_floors.append(int(floor))
	return normalized_reward_floors

func is_tower_reward_floor(floor: int) -> bool:
	for reward_floor in get_tower_reward_floors():
		if int(reward_floor) == floor:
			return true
	return false

func get_tower_reward_for_floor(floor: int) -> Dictionary:
	var config = TOWER_CONFIG.get("config", {})
	var rewards = config.get("rewards", {})
	if floor > 50:
		return rewards.get("50", {}).duplicate()
	return rewards.get(str(floor), {}).duplicate()

func get_tower_random_template() -> String:
	var config = TOWER_CONFIG.get("config", {})
	var templates = config.get("templates", ["qingwen_fox"])
	return templates[randi() % templates.size()]

func get_tower_next_reward_floor(current_floor: int) -> int:
	for reward_floor in get_tower_reward_floors():
		var floor = int(reward_floor)
		if floor > current_floor:
			return floor
	return -1

func get_tower_floors_to_next_reward(current_floor: int) -> int:
	var next_reward = get_tower_next_reward_floor(current_floor)
	if next_reward == -1:
		return 0
	return next_reward - current_floor

func get_tower_reward_description(floor: int) -> String:
	var reward = get_tower_reward_for_floor(floor)
	if reward.is_empty():
		return ""
	
	var descriptions = []
	for item_id in reward.keys():
		var amount = int(reward[item_id])
		var item_name = _get_item_name(item_id)
		descriptions.append(str(amount) + item_name)
	
	return "、".join(descriptions)

func _get_item_name(item_id: String) -> String:
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		var item_data = game_manager.get_item_data()
		if item_data:
			var name = item_data.get_item_name(item_id)
			if name != item_id:
				return name
	return "未知物品"
