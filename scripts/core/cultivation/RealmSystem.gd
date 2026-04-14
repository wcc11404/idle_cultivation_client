class_name RealmSystem extends Node

signal breakthrough_success(new_realm: String, new_level: int)
signal breakthrough_failed(reason: String)

var REALM_ORDER: Array = []
var BREAKTHROUGH_MATERIALS: Dictionary = {}
var REALMS: Dictionary = {}

func _ready():
	_load_config()

func _load_config():
	var file = FileAccess.open("res://scripts/core/cultivation/realms.json", FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		var data = JSON.parse_string(json_text)
		if data:
			REALM_ORDER = data.get("realm_order", [])
			BREAKTHROUGH_MATERIALS = data.get("breakthrough_materials", {})
			REALMS = data.get("realms", {})

func get_realm_info(realm_name: String) -> Dictionary:
	return REALMS.get(realm_name, {})

func get_total_realm_level(realm_name: String, level: int) -> int:
	var realm_index = REALM_ORDER.find(realm_name)
	if realm_index < 0:
		return 0
	return realm_index * 10 + level

func check_realm_requirement(realm_name: String, level: int, requirement: Dictionary) -> bool:
	if requirement.is_empty():
		return true
	var realm_min = requirement.get("realm_min", 0)
	var total_level = get_total_realm_level(realm_name, level)
	return total_level >= realm_min

func get_level_info(realm_name: String, level: int) -> Dictionary:
	var realm_info = get_realm_info(realm_name)
	var levels = realm_info.get("levels", {})
	return levels.get(str(level), {})

func get_level_name(realm_name: String, level: int) -> String:
	var realm_info = get_realm_info(realm_name)
	var names = realm_info.get("level_names", {})
	return names.get(str(level), str(level) + "段")

func get_max_spirit_energy(realm_name: String, level: int) -> int:
	var level_info = get_level_info(realm_name, level)
	return level_info.get("max_spirit_energy", 10)

func get_spirit_stone_cost(realm_name: String, current_level: int) -> int:
	var level_info = get_level_info(realm_name, current_level)
	return level_info.get("spirit_stone_cost", 0)

func get_spirit_energy_cost(realm_name: String, current_level: int) -> int:
	var level_info = get_level_info(realm_name, current_level)
	return level_info.get("spirit_energy_cost", 0)

func get_spirit_gain_speed(realm_name: String) -> float:
	var realm_info = get_realm_info(realm_name)
	return realm_info.get("spirit_gain_speed", 1.0)

func get_breakthrough_materials(realm_name: String, current_level: int, _is_realm_breakthrough: bool = false) -> Dictionary:
	var realm_materials = BREAKTHROUGH_MATERIALS.get(realm_name, {})
	var level_key = str(current_level)
	return realm_materials.get(level_key, {})

func can_breakthrough(realm_name: String, current_level: int, spirit_stone: int, spirit_energy: int, inventory_items: Dictionary = {}) -> Dictionary:
	var realm_info = get_realm_info(realm_name)
	if realm_info.is_empty():
		return {"can": false, "reason": "未知境界"}
	
	var max_level = realm_info.get("max_level", 0)
	var stone_cost = get_spirit_stone_cost(realm_name, current_level)
	var energy_cost = get_spirit_energy_cost(realm_name, current_level)
	var is_realm_breakthrough = (current_level >= max_level)
	var required_materials = get_breakthrough_materials(realm_name, current_level, is_realm_breakthrough)
	
	var material_check = {}
	for material_id in required_materials.keys():
		var required_count = required_materials[material_id]
		var current_count = inventory_items.get(material_id, 0)
		material_check[material_id] = {
			"required": required_count,
			"current": current_count,
			"enough": current_count >= required_count
		}
		if current_count < required_count:
			var material_name = get_material_name(material_id)
			return {
				"can": false, 
				"reason": material_name + "不足", 
				"stone_cost": stone_cost, 
				"energy_cost": energy_cost, 
				"materials": material_check
			}
	
	if current_level >= max_level:
		var next_realm = realm_info.get("next_realm", "")
		if next_realm.is_empty():
			return {"can": false, "reason": "已达到最高境界"}
		else:
			if spirit_energy < energy_cost:
				return {"can": false, "reason": "灵气不足", "stone_cost": stone_cost, "energy_cost": energy_cost, "energy_current": spirit_energy, "materials": material_check}
			
			if spirit_stone < stone_cost:
				return {"can": false, "reason": "灵石不足", "stone_cost": stone_cost, "stone_current": spirit_stone, "energy_cost": energy_cost, "materials": material_check}
			
			return {"can": true, "type": "realm", "next_realm": next_realm, "stone_cost": stone_cost, "energy_cost": energy_cost, "materials": material_check}
	
	if spirit_energy < energy_cost:
		return {"can": false, "reason": "灵气不足", "stone_cost": stone_cost, "energy_cost": energy_cost, "energy_current": spirit_energy, "materials": material_check}
	
	if spirit_stone < stone_cost:
		return {"can": false, "reason": "灵石不足", "stone_cost": stone_cost, "stone_current": spirit_stone, "energy_cost": energy_cost, "materials": material_check}
	
	return {"can": true, "type": "level", "stone_cost": stone_cost, "energy_cost": energy_cost, "materials": material_check}

func get_material_name(material_id: String) -> String:
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		var item_data = game_manager.get_item_data()
		if item_data:
			var name = item_data.get_item_name(material_id)
			if name != "未知物品":
				return name
	return material_id

func get_initial_stats() -> Dictionary:
	return get_level_info("炼气期", 1)

func get_realm_display_name(realm_name: String, level: int) -> String:
	var level_name = get_level_name(realm_name, level)
	return realm_name + " " + level_name

func get_all_realms() -> Array:
	return REALMS.keys()
