class_name LianliSystem extends Node

const AttributeCalculator = preload("res://scripts/core/AttributeCalculator.gd")

signal lianli_started(area_id: String)
signal lianli_ended(victory: bool)
signal lianli_waiting(time_remaining: float)

signal battle_started(enemy_name: String, is_elite: bool, enemy_max_health: float, enemy_level: int, player_max_health: float)
signal battle_action_executed(is_player: bool, damage: float, is_spell: bool, spell_name: String)
signal battle_updated(player_atb: float, enemy_atb: float, player_health: float, enemy_health: float, player_max_health: float, enemy_max_health: float)
signal battle_ended(victory: bool, loot: Array, enemy_name: String)

signal lianli_reward(item_id: String, amount: int, source: String)
signal log_message(message: String)

const ATB_MAX: float = 100.0
const TICK_INTERVAL: float = 0.1
const DEFAULT_ENEMY_ATTACK: float = 50.0
const PERCENTAGE_BASE: float = 100.0

var is_in_lianli: bool = false
var is_in_battle: bool = false
var is_waiting: bool = false

var current_area_id: String = ""
var current_enemy: Dictionary = {}

var is_in_tower: bool = false
var current_tower_floor: int = 0
var endless_tower_data: Node = null

var continuous_lianli: bool = false
var lianli_speed: float = 1.0
var wait_timer: float = 0.0
var current_wait_interval: float = 4.0

var area_continuous_default: Dictionary = {
	"qi_refining_outer": true,
	"qi_refining_inner": true,
	"foundation_outer": true,
	"foundation_inner": true,
	"foundation_herb_cave": false,
	"endless_tower": false,
}

var base_wait_interval_min: float = 3.0
var base_wait_interval_max: float = 5.0
var wait_time_multiplier: float = 1.0
var min_wait_time: float = 0.5

var player_atb: float = 0.0
var enemy_atb: float = 0.0
var tick_accumulator: float = 0.0

var player: Node = null

var lianli_area_data: Node = null
var enemy_data: Node = null

var combat_buffs: Dictionary = {
	"attack_percent": 0.0,
	"defense_percent": 0.0,
	"speed_bonus": 0.0,
	"health_bonus": 0.0
}

var _cached_spell_system: Node = null

func set_player(player_node: Node):
	player = player_node

func set_lianli_area_data(data: Node):
	lianli_area_data = data

func set_enemy_data(data: Node):
	enemy_data = data

func set_endless_tower_data(data: Node):
	endless_tower_data = data

func set_current_area(area_id: String):
	current_area_id = area_id

func set_continuous_lianli(enabled: bool):
	continuous_lianli = enabled

func set_lianli_speed(speed: float):
	lianli_speed = clamp(speed, 1.0, 2.0)

func start_lianli_in_area(area_id: String) -> bool:
	if not lianli_area_data or not enemy_data:
		return false
	
	if player and player.health <= 0:
		var area_name = lianli_area_data.get_area_name(area_id) if lianli_area_data else "历练区域"
		log_message.emit("气血不足，无法进入" + area_name)
		return false
	
	current_area_id = area_id
	is_in_lianli = true
	continuous_lianli = area_continuous_default.get(area_id, true)
	
	lianli_started.emit(area_id)
	
	return start_next_battle()

func start_endless_tower() -> bool:
	if not endless_tower_data or not enemy_data:
		return false
	
	if player and player.health <= 0:
		var tower_name = endless_tower_data.get_tower_name() if endless_tower_data else "无尽塔"
		log_message.emit("气血不足，无法进入" + tower_name)
		return false
	
	is_in_tower = true
	is_in_lianli = true
	continuous_lianli = false
	current_area_id = endless_tower_data.get_area_id()
	
	var start_floor = 1
	var max_floor = endless_tower_data.get_max_floor()
	if player:
		start_floor = min(player.tower_highest_floor + 1, max_floor)
	current_tower_floor = start_floor
	
	lianli_started.emit(current_area_id)
	
	return _start_tower_battle()

func _start_tower_battle() -> bool:
	if not endless_tower_data or not enemy_data:
		return false
	
	var template_id = endless_tower_data.get_random_template()
	var generated_enemy = enemy_data.generate_enemy(template_id, current_tower_floor)
	if generated_enemy.is_empty():
		return false
	
	var stats = generated_enemy.get("stats", {})
	
	var enemy_data_dict = {
		"id": "tower_enemy_" + str(current_tower_floor),
		"name": generated_enemy.get("name", "敌人"),
		"rarity": "普通",
		"level": current_tower_floor,
		"health": stats.get("health", 1000),
		"attack": stats.get("attack", DEFAULT_ENEMY_ATTACK),
		"defense": stats.get("defense", 0),
		"speed": stats.get("speed", 9),
		"drops": {}
	}
	
	return start_battle(enemy_data_dict)

func get_current_tower_floor() -> int:
	return current_tower_floor

func is_in_endless_tower() -> bool:
	return is_in_tower

func start_next_battle() -> bool:
	if not lianli_area_data or not enemy_data:
		return false
	
	var enemy_config = lianli_area_data.get_random_enemy_config(current_area_id)
	if enemy_config.is_empty():
		return false
	
	var template_id = enemy_config.get("template", "")
	var min_level = int(enemy_config.get("min_level", 1))
	var max_level = int(enemy_config.get("max_level", 1))
	var level = randi_range(min_level, max_level)
	
	var generated_enemy = enemy_data.generate_enemy(template_id, level)
	if generated_enemy.is_empty():
		return false
	
	var stats = generated_enemy.get("stats", {})
	
	var enemy_data_dict = {
		"id": template_id + "_lv" + str(level),
		"name": generated_enemy.get("name", "敌人"),
		"rarity": "精英" if generated_enemy.get("is_elite", false) else "普通",
		"level": level,
		"health": stats.get("health", 1000),
		"attack": stats.get("attack", DEFAULT_ENEMY_ATTACK),
		"defense": stats.get("defense", 0),
		"speed": stats.get("speed", 9),
		"drops": enemy_config.get("drops", {})
	}
	
	return start_battle(enemy_data_dict)

func start_battle(enemy_data_dict: Dictionary) -> bool:
	current_enemy = enemy_data_dict.duplicate()
	current_enemy["current_health"] = enemy_data_dict.get("health", 1000)
	is_in_battle = true
	is_waiting = false
	
	player_atb = 0.0
	enemy_atb = 0.0
	tick_accumulator = 0.0
	
	_reset_combat_buffs()
	
	var player_base_max_health = player.get_combat_max_health() if player else 0
	
	battle_started.emit(current_enemy.get("name", "敌人"), current_enemy.get("is_elite", false), current_enemy.get("health", 1000), current_enemy.get("level", 1), player_base_max_health)
	
	_trigger_start_spells()
	
	if player and combat_buffs.health_bonus > 0:
		var player_combat_max_health = player.get_combat_max_health()
		battle_updated.emit(player_atb, enemy_atb, player.health, current_enemy.get("current_health", 0), player_combat_max_health, current_enemy.get("health", 0))
	
	return true

func end_lianli():
	is_in_lianli = false
	is_in_battle = false
	is_waiting = false
	is_in_tower = false
	current_tower_floor = 0
	current_enemy = {}
	tick_accumulator = 0.0
	_restore_health_after_combat()
	_reset_combat_buffs()
	_cached_spell_system = null
	lianli_ended.emit(false)

func _reset_combat_buffs():
	combat_buffs = {
		"attack_percent": 0.0,
		"defense_percent": 0.0,
		"speed_bonus": 0.0,
		"health_bonus": 0.0
	}

func _trigger_start_spells():
	var spell_system = get_spell_system()
	if not spell_system:
		return
	
	var passive_effects = spell_system.get_equipped_spell_effects_by_type(spell_system.spell_data.SpellType.PASSIVE)
	for effect_data in passive_effects:
		if effect_data.is_empty():
			continue
		
		var effect_type = effect_data.get("type", "")
		var spell_name = effect_data.get("spell_name", "被动术法")
		var spell_id = effect_data.get("spell_id", "")
		
		match effect_type:
			"start_buff":
				var buff_type = effect_data.get("buff_type", "")
				var log_effect = effect_data.get("log_effect", "")
				match buff_type:
					"defense":
						var buff_percent = effect_data.get("buff_percent", 0.0)
						combat_buffs.defense_percent += buff_percent
						log_message.emit("战斗开始，使用" + spell_name + "，" + log_effect)
					"speed":
						var buff_value = effect_data.get("buff_value", 0.0)
						combat_buffs.speed_bonus += buff_value
						log_message.emit("战斗开始，使用" + spell_name + "，" + log_effect)
					"health":
						var health_percent = effect_data.get("buff_percent", 0.0)
						if player:
							var final_max_health = player.get_final_max_health()
							var bonus_health = int(final_max_health * health_percent)
							combat_buffs.health_bonus += bonus_health
							player.set_combat_buffs(combat_buffs)
							player.health += bonus_health
						log_message.emit("战斗开始，使用" + spell_name + "，" + log_effect)
		
		if not spell_id.is_empty():
			spell_system.add_spell_use_count(spell_id)

func _process(delta: float):
	if is_waiting:
		wait_timer += delta
		var time_remaining = max(0.0, current_wait_interval - wait_timer)
		lianli_waiting.emit(time_remaining)
		
		if wait_timer >= current_wait_interval:
			wait_timer = 0.0
			is_waiting = false
			
			if player and player.health <= 0:
				is_in_lianli = false
				log_message.emit("气血不足，历练结束")
				end_lianli()
				return
			
			if is_in_tower:
				current_tower_floor += 1
				_start_tower_battle()
			else:
				if lianli_area_data and lianli_area_data.is_special_area(current_area_id):
					if player.get_daily_dungeon_count(current_area_id) <= 0:
						is_in_lianli = false
						log_message.emit("今日次数已用完，历练结束")
						end_lianli()
						return
				start_next_battle()
		return
	
	if not is_in_battle or current_enemy.is_empty():
		return
	
	if not player:
		return
	
	if player.health <= 0:
		_handle_battle_defeat()
		return
	
	tick_accumulator += delta
	
	while tick_accumulator >= TICK_INTERVAL and is_in_battle:
		tick_accumulator -= TICK_INTERVAL
		
		_process_atb_tick()
		
		if current_enemy.get("current_health", 0) <= 0:
			_handle_battle_victory()
			return
		elif player.health <= 0:
			_handle_battle_defeat()
			return

func _process_atb_tick():
	var player_speed = AttributeCalculator.calculate_combat_speed(player, combat_buffs)
	
	var enemy_speed = current_enemy.get("speed", 7)
	
	player_atb += player_speed * lianli_speed
	enemy_atb += enemy_speed * lianli_speed
	
	var player_ready = player_atb >= ATB_MAX
	var enemy_ready = enemy_atb >= ATB_MAX
	
	if player_ready and enemy_ready:
		if player_speed > enemy_speed:
			_execute_player_action()
			if is_in_battle and current_enemy.get("current_health", 0) > 0 and player.health > 0:
				_execute_enemy_action()
		elif enemy_speed > player_speed:
			_execute_enemy_action()
			if is_in_battle and current_enemy.get("current_health", 0) > 0 and player.health > 0:
				_execute_player_action()
		else:
			_execute_player_action()
			if is_in_battle and current_enemy.get("current_health", 0) > 0 and player.health > 0:
				_execute_enemy_action()
	elif player_ready:
		_execute_player_action()
	elif enemy_ready:
		_execute_enemy_action()

func _execute_player_action():
	var enemy_defense = current_enemy.get("defense", 0)
	var enemy_health = current_enemy.get("current_health", 0)
	
	var player_attack = AttributeCalculator.calculate_combat_attack(player, combat_buffs)
	
	var spell_system = get_spell_system()
	var attack_result = null
	if spell_system:
		attack_result = spell_system.trigger_attack_spell()
	
	var damage_to_enemy = 0
	var is_spell_damage = false
	var spell_name = ""
	
	if attack_result and attack_result.triggered and not attack_result.is_normal_attack:
		var effect = attack_result.effect
		var damage_percent = effect.get("damage_percent", PERCENTAGE_BASE)
		
		damage_to_enemy = AttributeCalculator.calculate_damage(player_attack, enemy_defense, damage_percent)
		
		is_spell_damage = true
		spell_name = attack_result.spell_name
	else:
		damage_to_enemy = AttributeCalculator.calculate_damage(player_attack, enemy_defense)
	
	enemy_health -= damage_to_enemy
	enemy_health = max(0.0, enemy_health)
	current_enemy["current_health"] = enemy_health
	
	player_atb -= ATB_MAX
	
	var enemy_name = current_enemy.get("name", "敌人")
	var action_log = ""
	var damage_str = AttributeCalculator.format_damage(damage_to_enemy)
	if is_spell_damage:
		action_log = "玩家使用" + spell_name + "对" + enemy_name + "造成了" + damage_str + "点伤害"
	else:
		action_log = "玩家使用普通攻击对" + enemy_name + "造成了" + damage_str + "点伤害"
	log_message.emit(action_log)
	
	battle_action_executed.emit(true, damage_to_enemy, is_spell_damage, spell_name)
	
	var player_max_health = player.get_combat_max_health() if player else 0
	var enemy_max_health = current_enemy.get("health", 0)
	battle_updated.emit(player_atb, enemy_atb, player.health, enemy_health, player_max_health, enemy_max_health)

func _execute_enemy_action():
	var enemy_attack = current_enemy.get("attack", DEFAULT_ENEMY_ATTACK)
	
	var player_defense = AttributeCalculator.calculate_combat_defense(player, combat_buffs)
	
	var damage_to_player = AttributeCalculator.calculate_damage(enemy_attack, player_defense)
	
	if player:
		player.take_damage(damage_to_player)
	
	enemy_atb -= ATB_MAX
	
	var enemy_name = current_enemy.get("name", "敌人")
	var damage_str = AttributeCalculator.format_damage(damage_to_player)
	log_message.emit(enemy_name + "对玩家造成了" + damage_str + "点伤害")
	
	battle_action_executed.emit(false, damage_to_player, false, "")
	
	var player_max_health = player.get_combat_max_health() if player else 0
	var enemy_max_health = current_enemy.get("health", 0)
	var enemy_current_health = current_enemy.get("current_health", 0)
	var player_current_health = player.health if player else 0
	battle_updated.emit(player_atb, enemy_atb, player_current_health, enemy_current_health, player_max_health, enemy_max_health)

func _restore_health_after_combat():
	if player and combat_buffs.get("health_bonus", 0.0) > 0:
		var final_max_health = player.get_final_max_health()
		player.set_health(min(player.health, final_max_health))
		player.clear_combat_buffs()

func _handle_battle_victory():
	is_in_battle = false
	
	_restore_health_after_combat()
	
	var enemy_name = current_enemy.get("name", "")

	var loot = []

	if lianli_area_data and lianli_area_data.is_single_boss_area(current_area_id):
		var special_drops = lianli_area_data.get_special_drops(current_area_id)
		for item_id in special_drops.keys():
			var amount = int(special_drops[item_id])
			loot.append({"item_id": item_id, "amount": amount})
			lianli_reward.emit(item_id, amount, "lianli")
	else:
		var drops_config = current_enemy.get("drops", {})
		for item_id in drops_config.keys():
			var drop_info = drops_config[item_id]
			var chance = drop_info.get("chance", 1.0)
			if randf() <= chance:
				var min_amount = int(drop_info.get("min", 0))
				var max_amount = int(drop_info.get("max", 0))
				var amount = randi_range(min_amount, max_amount)
				if amount > 0:
					loot.append({"item_id": item_id, "amount": amount})
					lianli_reward.emit(item_id, amount, "lianli")
	
	battle_ended.emit(true, loot, enemy_name)
	
	if is_in_tower:
		_handle_tower_victory()
		return
	
	if lianli_area_data and lianli_area_data.is_special_area(current_area_id):
		player.use_daily_dungeon_count(current_area_id)
	
	if lianli_area_data and lianli_area_data.is_single_boss_area(current_area_id):
		if continuous_lianli and player.get_daily_dungeon_count(current_area_id) > 0:
			is_waiting = true
			wait_timer = 0.0
			current_wait_interval = get_wait_interval()
			return
		else:
			is_in_lianli = false
			log_message.emit("通关成功！")
			return
	
	if continuous_lianli and is_in_lianli:
		is_waiting = true
		wait_timer = 0.0
		current_wait_interval = get_wait_interval()
	else:
		is_in_lianli = false

func _handle_battle_defeat():
	_restore_health_after_combat()
	
	if is_in_tower:
		log_message.emit("无尽塔挑战结束，最高到达第" + str(current_tower_floor) + "层")
	else:
		log_message.emit("气血不足，历练结束")
	
	battle_ended.emit(false, [], current_enemy.get("name", ""))
	end_lianli()

func _handle_tower_victory():
	if player and current_tower_floor > player.tower_highest_floor:
		player.tower_highest_floor = current_tower_floor
	
	if endless_tower_data and endless_tower_data.is_reward_floor(current_tower_floor):
		var reward = endless_tower_data.get_reward_for_floor(current_tower_floor)
		for item_id in reward.keys():
			var amount = int(reward[item_id])
			lianli_reward.emit(item_id, amount, "tower")
	
	log_message.emit("挑战第" + str(current_tower_floor) + "层成功")
	
	var max_floor = endless_tower_data.get_max_floor()
	if current_tower_floor >= max_floor:
		log_message.emit("恭喜！已通关无尽塔最高层！")
		is_in_battle = false
		is_in_lianli = false
		is_in_tower = false
		return
	
	is_in_battle = false
	
	if continuous_lianli:
		is_waiting = true
		wait_timer = 0.0
		current_wait_interval = get_wait_interval()
	else:
		is_in_lianli = false

func start_wait_for_next_battle() -> bool:
	if is_in_battle or is_waiting:
		return false
	
	if player and player.health <= 0:
		log_message.emit("气血不足，无法开始战斗，请恢复气血")
		return false
	
	if is_in_tower:
		var max_floor = endless_tower_data.get_max_floor()
		if current_tower_floor + 1 > max_floor:
			return false
	else:
		if lianli_area_data and lianli_area_data.is_special_area(current_area_id):
			if player.get_daily_dungeon_count(current_area_id) <= 0:
				log_message.emit("今日次数已用完")
				return false
	
	is_in_lianli = true
	is_waiting = true
	wait_timer = 0.0
	current_wait_interval = get_wait_interval()
	return true

func get_current_enemy_drops() -> Dictionary:
	if current_enemy.is_empty():
		return {}
	return current_enemy.get("drops", {})

func exit_tower():
	if is_in_tower:
		log_message.emit("退出无尽塔，最高到达第" + str(current_tower_floor) + "层")
		end_lianli()

func get_spell_system() -> Node:
	if _cached_spell_system != null and is_instance_valid(_cached_spell_system):
		return _cached_spell_system
	
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		_cached_spell_system = game_manager.get_spell_system()
		return _cached_spell_system
	
	if Engine.has_singleton("GameManager"):
		game_manager = Engine.get_singleton("GameManager")
		_cached_spell_system = game_manager.get_spell_system()
		return _cached_spell_system
	
	return null

func get_wait_interval() -> float:
	var interval = randf_range(base_wait_interval_min, base_wait_interval_max)
	return max(min_wait_time, interval * wait_time_multiplier)
