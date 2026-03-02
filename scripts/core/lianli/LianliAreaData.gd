class_name LianliAreaData extends Node

var NORMAL_AREAS: Dictionary = {}
var SPECIAL_AREAS: Dictionary = {}

func _ready():
	_load_config()

func _load_config():
	var file = FileAccess.open("res://scripts/core/lianli/areas.json", FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		var data = JSON.parse_string(json_text)
		if data:
			NORMAL_AREAS = data.get("normal_areas", {})
			SPECIAL_AREAS = data.get("special_areas", {})

func get_normal_areas() -> Dictionary:
	return NORMAL_AREAS.duplicate()

func get_special_areas() -> Dictionary:
	return SPECIAL_AREAS.duplicate()

func get_all_areas() -> Dictionary:
	var all_areas = NORMAL_AREAS.duplicate()
	for area_id in SPECIAL_AREAS.keys():
		all_areas[area_id] = SPECIAL_AREAS[area_id]
	return all_areas

func get_normal_area_ids() -> Array:
	return NORMAL_AREAS.keys()

func get_special_area_ids() -> Array:
	return SPECIAL_AREAS.keys()

func get_all_area_ids() -> Array:
	var ids = []
	ids.append_array(NORMAL_AREAS.keys())
	ids.append_array(SPECIAL_AREAS.keys())
	return ids

func get_area_data(area_id: String) -> Dictionary:
	if NORMAL_AREAS.has(area_id):
		return NORMAL_AREAS[area_id].duplicate()
	if SPECIAL_AREAS.has(area_id):
		return SPECIAL_AREAS[area_id].duplicate()
	return {}

func get_area_name(area_id: String) -> String:
	if NORMAL_AREAS.has(area_id):
		return NORMAL_AREAS[area_id].get("name", "未知区域")
	if SPECIAL_AREAS.has(area_id):
		return SPECIAL_AREAS[area_id].get("name", "未知区域")
	return "未知区域"

func get_area_description(area_id: String) -> String:
	if NORMAL_AREAS.has(area_id):
		return NORMAL_AREAS[area_id].get("description", "")
	if SPECIAL_AREAS.has(area_id):
		return SPECIAL_AREAS[area_id].get("description", "")
	return ""

func is_normal_area(area_id: String) -> bool:
	return NORMAL_AREAS.has(area_id)

func is_special_area(area_id: String) -> bool:
	return SPECIAL_AREAS.has(area_id)

func is_single_boss_area(area_id: String) -> bool:
	if SPECIAL_AREAS.has(area_id):
		return SPECIAL_AREAS[area_id].get("is_single_boss", false)
	return false

func get_special_drops(area_id: String) -> Dictionary:
	if SPECIAL_AREAS.has(area_id):
		return SPECIAL_AREAS[area_id].get("special_drops", {}).duplicate()
	return {}

func get_random_enemy_config(area_id: String) -> Dictionary:
	var area = get_area_data(area_id)
	if area.is_empty():
		return {}
	
	var enemies = area.get("enemies", [])
	if enemies.is_empty():
		return {}
	
	var total_weight = 0
	for enemy in enemies:
		total_weight += enemy.get("weight", 0)
	
	if total_weight <= 0:
		return enemies[0].duplicate()
	
	var random_value = randi() % int(total_weight)
	var current_weight = 0
	
	for enemy in enemies:
		current_weight += enemy.get("weight", 0)
		if random_value < current_weight:
			return enemy.duplicate()
	
	return enemies[0].duplicate()

func get_enemies_list(area_id: String) -> Array:
	var area = get_area_data(area_id)
	return area.get("enemies", []).duplicate()
