class_name EndlessTowerData extends Node

var MAX_FLOOR: int = 51
var TOWER_CONFIG: Dictionary = {}
var TOWER_AREA_ID: String = "endless_tower"

func _ready():
	_load_config()

func _load_config():
	var file = FileAccess.open("res://scripts/core/lianli/tower.json", FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		var data = JSON.parse_string(json_text)
		if data:
			MAX_FLOOR = data.get("max_floor", 51)
			TOWER_AREA_ID = data.get("area_id", "endless_tower")
			TOWER_CONFIG = data.get("config", {})

func get_max_floor() -> int:
	return MAX_FLOOR

func get_tower_name() -> String:
	return TOWER_CONFIG.get("name", "无尽塔")

func get_tower_description() -> String:
	return TOWER_CONFIG.get("description", "")

func get_reward_floors() -> Array:
	return TOWER_CONFIG.get("reward_floors", [])

func is_reward_floor(floor: int) -> bool:
	var reward_floors = get_reward_floors()
	return floor in reward_floors

func get_reward_for_floor(floor: int) -> Dictionary:
	var rewards = TOWER_CONFIG.get("rewards", {})
	if floor > 50:
		return rewards.get("50", {})
	return rewards.get(str(floor), {})

func get_reward_description(floor: int) -> String:
	var reward = get_reward_for_floor(floor)
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

func get_next_reward_floor(current_floor: int) -> int:
	var reward_floors = get_reward_floors()
	for floor in reward_floors:
		if floor > current_floor:
			return floor
	return -1

func get_floors_to_next_reward(current_floor: int) -> int:
	var next_reward = get_next_reward_floor(current_floor)
	if next_reward == -1:
		return 0
	return next_reward - current_floor

func get_random_template() -> String:
	var templates = TOWER_CONFIG.get("templates", ["wolf"])
	return templates[randi() % templates.size()]

func get_area_id() -> String:
	return TOWER_AREA_ID
