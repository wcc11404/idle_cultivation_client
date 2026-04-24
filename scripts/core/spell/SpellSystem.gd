class_name SpellSystem extends Node

signal spell_equipped(spell_id: String, spell_type: String)
signal spell_unequipped(spell_id: String, spell_type: String)
signal spell_used(spell_id: String)

var player: Node = null
var spell_data: Node = null

var player_spells: Dictionary = {}

var equipped_spells: Dictionary = {}
var _cached_bonuses: Dictionary = {
	"attack": 1.0,
	"defense": 1.0,
	"health": 1.0,
	"spirit_gain": 1.0,
	"max_spirit": 1.0,
	"speed": 0.0
}

var lianli_system: Node = null

func set_player(player_node: Node):
	player = player_node
	_notify_player_attributes_changed()

func set_spell_data(spell_data_node: Node):
	spell_data = spell_data_node
	_init_player_spells()

func set_lianli_system(lianli_sys: Node):
	lianli_system = lianli_sys

func _init_player_spells(should_recalculate: bool = true):
	player_spells.clear()
	if spell_data:
		var all_spell_ids = spell_data.get_all_spell_ids()
		
		for spell_id in all_spell_ids:
			player_spells[spell_id] = {
				"obtained": false,
				"level": 0,
				"use_count": 0,
				"charged_spirit": 0
			}
		equipped_spells = {
			"breathing": [],
			"active": [],
			"opening": [],
			"production": []
		}
		if should_recalculate:
			recalculate_bonuses()

func recalculate_bonuses():
	_cached_bonuses = {
		"attack": 1.0,
		"defense": 1.0,
		"health": 1.0,
		"spirit_gain": 1.0,
		"max_spirit": 1.0,
		"speed": 0.0
	}
	
	if not spell_data:
		_notify_player_attributes_changed()
		return
	
	for spell_id in player_spells.keys():
		var spell_info = player_spells[spell_id]
		if not spell_info.obtained or spell_info.level <= 0:
			continue
		
		var level_data = spell_data.get_spell_level_data(spell_id, spell_info.level)
		var attribute_bonus = level_data.get("attribute_bonus", {})
		
		for attr in attribute_bonus.keys():
			if attr == "speed":
				_cached_bonuses[attr] += attribute_bonus[attr]
			else:
				_cached_bonuses[attr] *= attribute_bonus[attr]
	
	_notify_player_attributes_changed()

func _notify_player_attributes_changed():
	if player and is_instance_valid(player) and player.has_method("reload_attributes"):
		player.reload_attributes()

func _is_in_battle() -> bool:
	if lianli_system:
		return lianli_system.is_in_battle
	return false

func equip_spell(spell_id: String) -> Dictionary:
	var result = {"success": false, "reason": "", "spell_id": spell_id, "spell_type": ""}
	
	if _is_in_battle():
		result.reason = "战斗中无法装备术法"
		return result
	
	if not player_spells.has(spell_id):
		result.reason = "术法不存在"
		return result
	
	if not player_spells[spell_id].obtained:
		result.reason = "未获取该术法"
		return result
	
	if is_spell_equipped(spell_id):
		result.reason = "术法已装备"
		return result
	
	var spell_type = spell_data.get_spell_type(spell_id)
	var limit = spell_data.get_equipment_limit(spell_type)
	var type_name = spell_data.get_spell_type_name(spell_type)
	
	if limit >= 0 and equipped_spells.has(spell_type) and equipped_spells[spell_type].size() >= limit:
		result.reason = type_name + "装备数量达到上限（" + str(limit) + "个），请先卸下已装备的术法"
		return result
	
	if not equipped_spells.has(spell_type):
		equipped_spells[spell_type] = []
	equipped_spells[spell_type].append(spell_id)
	spell_equipped.emit(spell_id, spell_type)
	result.success = true
	result.spell_type = spell_type
	return result

func unequip_spell(spell_id: String) -> Dictionary:
	var result = {"success": false, "reason": "", "spell_id": spell_id, "spell_type": ""}
	
	if _is_in_battle():
		result.reason = "战斗中无法卸下术法"
		return result
	
	if not player_spells.has(spell_id):
		result.reason = "术法不存在"
		return result
	
	if not is_spell_equipped(spell_id):
		result.reason = "术法未装备"
		return result
	
	var spell_type = spell_data.get_spell_type(spell_id)
	if equipped_spells.has(spell_type):
		equipped_spells[spell_type].erase(spell_id)
	spell_unequipped.emit(spell_id, spell_type)
	result.success = true
	result.spell_type = spell_type
	return result

func get_player_spells() -> Dictionary:
	return player_spells

func is_spell_equipped(spell_id: String) -> bool:
	if not player_spells.has(spell_id):
		return false
	
	var spell_type = spell_data.get_spell_type(spell_id)
	return spell_id in equipped_spells.get(spell_type, [])

func get_equipped_count(spell_type: String) -> int:
	if equipped_spells.has(spell_type):
		return equipped_spells[spell_type].size()
	return 0

func add_spell_use_count(spell_id: String):
	if player_spells.has(spell_id) and player_spells[spell_id].obtained:
		var spell_info = player_spells[spell_id]
		var spell_config = spell_data.get_spell_data(spell_id)
		var max_level = spell_config.get("max_level", 3)
		
		if spell_info.level >= max_level:
			return
		
		var level_data = spell_data.get_spell_level_data(spell_id, spell_info.level)
		var use_count_required = level_data.get("use_count_required", 0)
		
		if spell_info.use_count >= use_count_required:
			return
		
		player_spells[spell_id].use_count += 1
		spell_used.emit(spell_id)

func get_spell_info(spell_id: String) -> Dictionary:
	if not player_spells.has(spell_id) or not spell_data:
		return {}
	
	var player_info = player_spells[spell_id]
	var config = spell_data.get_spell_data(spell_id)
	
	return {
		"id": spell_id,
		"name": config.get("name", ""),
		"type": config.get("type", "active"),
		"type_name": spell_data.get_spell_type_name(config.get("type", "active")),
		"description": config.get("description", ""),
		"obtained": player_info.obtained,
		"level": player_info.level,
		"max_level": config.get("max_level", 3),
		"use_count": player_info.use_count,
		"equipped": is_spell_equipped(spell_id),
		"charged_spirit": player_info.charged_spirit
	}

func get_attribute_bonuses() -> Dictionary:
	return _cached_bonuses.duplicate(true)

func get_equipped_breathing_heal_effect() -> Dictionary:
	if not spell_data:
		return {"heal_amount": 0.0, "spell_ids": []}
	
	var breathing_spells = equipped_spells.get("breathing", [])
	if breathing_spells.is_empty():
		return {"heal_amount": 0.0, "spell_ids": []}
	
	var total_heal_percent = 0.0
	var valid_spell_ids = []
	
	for breathing_spell_id in breathing_spells:
		var spell_info = player_spells[breathing_spell_id]
		if not spell_info.obtained or spell_info.level <= 0:
			continue
		
		var level_data = spell_data.get_spell_level_data(breathing_spell_id, spell_info.level)
		var effect = level_data.get("effect", {})
		
		if effect.get("effect_type") == "passive_heal":
			var heal_percent = effect.get("heal_percent", 0.0)
			total_heal_percent += heal_percent
			valid_spell_ids.append(breathing_spell_id)
	
	return {
		"heal_amount": total_heal_percent,
		"spell_ids": valid_spell_ids
	}

func charge_spell_spirit(spell_id: String, amount: int) -> Dictionary:
	var result = {"success": false, "reason": "", "spell_id": spell_id, "charged_amount": 0}
	
	if not player_spells.has(spell_id):
		result.reason = "术法不存在"
		return result
	
	var spell_info = player_spells[spell_id]
	if not spell_info.obtained:
		result.reason = "未获取该术法"
		return result
	
	var spell_config = spell_data.get_spell_data(spell_id)
	var max_level = spell_config.get("max_level", 3)
	
	if spell_info.level >= max_level:
		result.reason = "已达到最高等级"
		return result
	
	var next_level = spell_info.level + 1
	var level_data = spell_data.get_spell_level_data(spell_id, spell_info.level)
	var spirit_cost = level_data.get("spirit_cost", 0)
	
	var current_charged = spell_info.charged_spirit
	var need = spirit_cost - current_charged
	
	if need <= 0:
		result.reason = "灵气已充足"
		return result
	
	var available = min(amount, need)
	
	if player and player.spirit_energy < available:
		available = int(player.spirit_energy)
	
	if available <= 0:
		result.reason = "自身灵气不足"
		return result
	
	if player:
		player.spirit_energy -= available
	
	spell_info.charged_spirit += available
	result.success = true
	result.charged_amount = available
	
	return result

func apply_save_data(data: Dictionary):
	_init_player_spells(false)
	
	if data == null:
		recalculate_bonuses()
		return

	var loaded_spells: Dictionary = {}
	if data.has("player_spells") and data["player_spells"] is Dictionary:
		loaded_spells = data["player_spells"]

	if not loaded_spells.is_empty():
		for raw_spell_id in loaded_spells.keys():
			var spell_id = str(raw_spell_id)
			if not player_spells.has(spell_id):
				continue
			var spell_info = loaded_spells[raw_spell_id]
			if not (spell_info is Dictionary):
				continue
			var level = int(spell_info.get("level", 0))
			var obtained = bool(spell_info.get("obtained", false)) or level > 0
			player_spells[spell_id] = {
				"obtained": obtained,
				"level": level,
				"use_count": int(spell_info.get("use_count", 0)),
				"charged_spirit": int(spell_info.get("charged_spirit", 0))
			}

	var loaded_equipped: Dictionary = {}
	if data.has("equipped_spells") and data["equipped_spells"] is Dictionary:
		loaded_equipped = data["equipped_spells"]

	equipped_spells["breathing"] = []
	equipped_spells["active"] = []
	equipped_spells["opening"] = []
	equipped_spells["production"] = []

	if loaded_equipped.is_empty():
		recalculate_bonuses()
		return

	for spell_id in _get_equipped_list_by_keys(loaded_equipped, ["breathing", "production"]):
		if player_spells.has(spell_id) and player_spells[spell_id].obtained:
			equipped_spells["breathing"].append(spell_id)

	for spell_id in _get_equipped_list_by_keys(loaded_equipped, ["active"]):
		if player_spells.has(spell_id) and player_spells[spell_id].obtained:
			equipped_spells["active"].append(spell_id)

	for spell_id in _get_equipped_list_by_keys(loaded_equipped, ["opening"]):
		if player_spells.has(spell_id) and player_spells[spell_id].obtained:
			equipped_spells["opening"].append(spell_id)
	
	recalculate_bonuses()

func _get_equipped_list_by_keys(source: Dictionary, keys: Array) -> Array:
	for key in keys:
		if source.has(key) and source[key] is Array:
			var result: Array = []
			for spell_id in source[key]:
				result.append(str(spell_id))
			return result
	return []
