class_name CultivationSystem extends Node

const AttributeCalculator = preload("res://scripts/core/AttributeCalculator.gd")

signal cultivation_progress(current: int, max: int)
signal cultivation_complete()
signal log_message(message: String)

var is_cultivating: bool = false
var cultivation_timer: float = 0.0
var cultivation_interval: float = 1.0

var player: Node = null

const BASE_HEAL_PER_SECOND: float = 1.0

func _ready():
	pass

func set_player(player_node: Node):
	player = player_node

func start_cultivation():
	_stop_other_systems()
	
	if player:
		is_cultivating = true
		player.cultivation_active = true

func _stop_other_systems():
	var game_manager = get_node_or_null("/root/GameManager")
	if not game_manager:
		return
	
	var lianli_system = game_manager.get_lianli_system()
	if lianli_system and lianli_system.is_in_lianli:
		lianli_system.end_lianli()
	
	var alchemy_system = game_manager.get_alchemy_system()
	if alchemy_system and alchemy_system.is_crafting:
		alchemy_system.stop_crafting()

func stop_cultivation():
	is_cultivating = false
	if player:
		player.cultivation_active = false
	log_message.emit("停止修炼")

func _process(delta: float):
	if not is_cultivating or not player:
		return
	
	cultivation_timer += delta
	
	if cultivation_timer >= cultivation_interval:
		cultivation_timer = 0.0
		do_cultivate()

func do_cultivate():
	if not player:
		return
	
	var final_max_health = AttributeCalculator.calculate_final_max_health(player)
	var total_heal = BASE_HEAL_PER_SECOND
	
	var spell_system = _get_spell_system()
	if spell_system:
		var breathing_effect = spell_system.get_equipped_breathing_heal_effect()
		if breathing_effect.heal_amount > 0:
			total_heal += final_max_health * breathing_effect.heal_amount
		
		for spell_id in breathing_effect.get("spell_ids", []):
			spell_system.add_spell_use_count(spell_id)
	
	if player.health < final_max_health:
		player.heal(total_heal)
	
	if player.spirit_energy >= player.get_final_max_spirit_energy():
		cultivation_complete.emit()
		return
	
	var game_manager = get_node_or_null("/root/GameManager")
	var realm_system = game_manager.get_realm_system() if game_manager else null
	var spirit_gain = 1.0
	if realm_system:
		spirit_gain = realm_system.get_spirit_gain_speed(player.realm)
	
	player.add_spirit_energy(spirit_gain)
	
	cultivation_progress.emit(player.spirit_energy, player.get_final_max_spirit_energy())

func _get_spell_system() -> Node:
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		return game_manager.get_spell_system()
	return null
