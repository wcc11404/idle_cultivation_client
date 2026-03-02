class_name PlayerData extends Node

const AttributeCalculator = preload("res://scripts/core/AttributeCalculator.gd")

signal realm_breakthrough(new_realm: String, new_level: int)
signal breakthrough_failed(message: String)

var realm: String = "炼气期"
var realm_level: int = 1

# 基础属性值（不包含任何加成）- 全部使用 float
var health: float = 500.0
var spirit_energy: float = 0.0

# 基础属性（随境界变化）
var base_max_health: float = 500.0
var base_max_spirit: float = 100.0
var base_attack: float = 50.0
var base_defense: float = 25.0
var base_speed: float = 5.0
var base_spirit_gain: float = 1.0

var cultivation_active: bool = false

# 无尽塔数据
var tower_highest_floor: int = 0  # 最高通关层数

# 炼丹系统数据
var learned_recipes: Array = []  # 已学会的丹方ID列表
var has_alchemy_furnace: bool = false  # 是否拥有丹炉

# 战斗临时Buff（由LianliSystem管理）
var combat_buffs: Dictionary = {}

# 每日副本数据
var daily_dungeon_data: Dictionary = {}

const DAILY_DUNGEON_MAX_COUNT: int = 3
const DAILY_RESET_HOUR: int = 4

func _ready():
	add_to_group("player")
	apply_realm_stats()

func apply_realm_stats():
	var realm_system = get_node_or_null("/root/GameManager").get_realm_system() if get_node_or_null("/root/GameManager") else null
	
	var old_max_health = base_max_health
	
	if realm_system:
		var level_info = realm_system.get_level_info(realm, realm_level)
		base_max_health = float(level_info.get("health", 500))
		base_attack = float(level_info.get("attack", 50))
		base_defense = float(level_info.get("defense", 25))
		base_max_spirit = float(level_info.get("max_spirit_energy", 10))
		# 从境界配置获取速度
		var realm_info = realm_system.get_realm_info(realm)
		base_speed = float(realm_info.get("speed", 5.0))
		base_spirit_gain = float(realm_info.get("spirit_gain_speed", 1.0))
	else:
		# 备用逻辑：使用默认属性
		var realm_info = get_default_realm_info()
		base_max_health = float(realm_info.get("health", 500))
		base_attack = float(realm_info.get("attack", 50))
		base_defense = float(realm_info.get("defense", 25))
		base_max_spirit = 10.0
		base_speed = 5.0
		base_spirit_gain = 1.0
	
	# 同步更新当前气血（保持满血状态或按比例调整）
	if old_max_health > 0:
		# 按比例调整当前气血
		health = health * base_max_health / old_max_health
	else:
		# 初始状态，设置为满血
		health = get_final_max_health()
	
	# 确保当前气血不超过最终上限（包含术法加成）
	health = min(health, get_final_max_health())

func get_default_realm_info() -> Dictionary:
	return {"health": 500, "attack": 50, "defense": 25}

func get_display_dict() -> Dictionary:
	# 获取实际的灵石数量
	var game_manager = get_node_or_null("/root/GameManager")
	var inventory = game_manager.get_inventory() if game_manager else null
	var actual_spirit_stone = inventory.get_item_count("spirit_stone") if inventory else 0
	
	return {
		"realm": realm,
		"realm_level": realm_level,
		"health": health,
		"spirit_energy": spirit_energy,
		# 基础属性
		"base_max_health": base_max_health,
		"base_max_spirit": base_max_spirit,
		"base_attack": base_attack,
		"base_defense": base_defense,
		"base_speed": base_speed,
		"base_spirit_gain": base_spirit_gain,
		# 最终属性（供UI显示使用）
		"final_max_health": get_final_max_health(),
		"final_max_spirit": get_final_max_spirit_energy(),
		"final_attack": get_final_attack(),
		"final_defense": get_final_defense(),
		"final_speed": get_final_speed(),
		"final_spirit_gain": get_final_spirit_gain_speed(),
		"spirit_stone": actual_spirit_stone
	}

func get_status_dict() -> Dictionary:
	var status = get_display_dict()
	status["is_cultivating"] = cultivation_active
	status["can_breakthrough"] = can_breakthrough()
	return status

func get_is_cultivating() -> bool:
	return cultivation_active

# 获取术法系统
func get_spell_system():
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		return game_manager.get_spell_system()
	return null

# 获取术法属性加成
func get_spell_bonuses() -> Dictionary:
	var spell_system = get_spell_system()
	if spell_system:
		return spell_system.get_attribute_bonuses()
	return {"attack": 1.0, "defense": 1.0, "health": 1.0, "spirit_gain": 1.0, "speed": 0.0}

# ==================== 最终属性计算（委托给AttributeCalculator） ====================
# 静态最终能力值 = 基础值 + 境界加成 + 术法加成 + 装备加成 + 功法加成 + 丹药加成

func get_final_attack() -> float:
	return AttributeCalculator.calculate_final_attack(self)

func get_final_defense() -> float:
	return AttributeCalculator.calculate_final_defense(self)

func get_final_speed() -> float:
	return AttributeCalculator.calculate_final_speed(self)

func get_final_max_health() -> float:
	return AttributeCalculator.calculate_final_max_health(self)

func get_final_max_spirit_energy() -> float:
	return AttributeCalculator.calculate_final_max_spirit_energy(self)

func get_final_spirit_gain_speed() -> float:
	return AttributeCalculator.calculate_final_spirit_gain_speed(self)

# ==================== 战斗最终能力值计算 ====================
# 战斗最终能力值 = 静态最终能力值 + 战斗临时Buff

func get_combat_attack() -> float:
	return AttributeCalculator.calculate_combat_attack(self, combat_buffs)

func get_combat_defense() -> float:
	return AttributeCalculator.calculate_combat_defense(self, combat_buffs)

func get_combat_speed() -> float:
	return AttributeCalculator.calculate_combat_speed(self, combat_buffs)

func get_combat_max_health() -> float:
	return AttributeCalculator.calculate_combat_max_health(self, combat_buffs)

# ==================== 气血管理方法 ====================

## 受到伤害
func take_damage(damage: float) -> float:
	health = max(0.0, health - damage)
	return health

## 恢复气血
func heal(amount: float) -> float:
	var max_health = get_final_max_health()
	health = min(max_health, health + amount)
	return health

## 设置当前气血（用于战斗同步）
func set_health(value: float) -> void:
	health = max(0.0, value)

# ==================== 灵气管理方法 ====================

## 消耗灵气
func consume_spirit(amount: float) -> bool:
	if spirit_energy >= amount:
		spirit_energy -= amount
		return true
	return false

## 增加灵气
func add_spirit(amount: float) -> float:
	var max_spirit = get_final_max_spirit_energy()
	# 如果当前灵气已经超过上限，直接返回，不丢失灵气
	if spirit_energy >= max_spirit:
		return spirit_energy
	spirit_energy = min(max_spirit, spirit_energy + amount)
	return spirit_energy

## 设置当前灵气
func set_spirit(value: float) -> void:
	spirit_energy = max(0.0, value)

# ==================== 战斗Buff管理 ====================

## 设置战斗Buff（由LianliSystem调用）
func set_combat_buffs(buffs: Dictionary):
	combat_buffs = buffs

## 获取战斗Buff
func get_combat_buffs() -> Dictionary:
	return combat_buffs

## 清除战斗Buff
func clear_combat_buffs():
	combat_buffs = {}

# 获取灵气获取速度
func get_spirit_gain_speed() -> float:
	var game_manager = get_node_or_null("/root/GameManager")
	var realm_system = game_manager.get_realm_system() if game_manager else null
	
	if realm_system:
		return realm_system.get_spirit_gain_speed(realm)
	return 1.0

func add_spirit_energy(amount: float):
	# 如果当前灵气已满，不增加
	if spirit_energy >= get_final_max_spirit_energy():
		return
	# 否则增加灵气，但不超过最终上限（包含术法加成）
	spirit_energy = min(spirit_energy + amount, get_final_max_spirit_energy())

# bug丹专用：增加灵气，可以超过上限
func add_spirit_energy_unlimited(amount: float):
	spirit_energy += amount

func can_breakthrough() -> Dictionary:
	var realm_system = get_node_or_null("/root/GameManager").get_realm_system() if get_node_or_null("/root/GameManager") else null
	if not realm_system:
		return {"can": false, "reason": "境界系统未初始化"}
	
	var game_manager = get_node_or_null("/root/GameManager")
	var inv = game_manager.get_inventory() if game_manager else null
	var current_stone = inv.get_item_count("spirit_stone") if inv else 0
	
	# 动态获取当前突破需要的所有材料
	var inventory_items = {}
	if inv:
		# 判断是否是大境界突破
		var realm_info = realm_system.get_realm_info(realm)
		var max_level = realm_info.get("max_level", 0)
		var is_realm_breakthrough = (realm_level >= max_level)
		
		# 获取当前需要的材料配置
		var required_materials = realm_system.get_breakthrough_materials(realm, realm_level, is_realm_breakthrough)
		# 只读取配置中需要的材料数量
		for material_id in required_materials.keys():
			inventory_items[material_id] = inv.get_item_count(material_id)
	
	return realm_system.can_breakthrough(realm, realm_level, current_stone, spirit_energy, inventory_items)

func attempt_breakthrough() -> Dictionary:
	var result = can_breakthrough()
	var stone_cost = result.get("stone_cost", 0)
	var energy_cost = result.get("energy_cost", 0)
	var materials = result.get("materials", {})
	
	if not result.get("can", false):
		var fail_reason = result.get("reason", "无法突破")
		breakthrough_failed.emit(fail_reason)
		return {
			"success": false, 
			"reason": fail_reason,
			"stone_cost": stone_cost,
			"energy_cost": energy_cost,
			"stone_current": result.get("stone_current", 0),
			"energy_current": result.get("energy_current", 0),
			"materials": materials
		}
	
	var type = result.get("type", "level")
	var old_realm = realm
	var old_level = realm_level
	
	# 消耗灵石、灵气和材料
	var game_manager = get_node_or_null("/root/GameManager")
	var inv = game_manager.get_inventory() if game_manager else null
	if inv and inv.has_item("spirit_stone", stone_cost):
		inv.remove_item("spirit_stone", stone_cost)
	spirit_energy = max(0, spirit_energy - energy_cost)
	
	# 消耗突破材料
	for material_id in materials.keys():
		var material_info = materials[material_id]
		var required_count = int(material_info.get("required", 0))
		if required_count > 0 and inv:
			inv.remove_item(material_id, required_count)
	
	if type == "level":
		realm_level += 1
		apply_realm_stats()
		realm_breakthrough.emit(realm, realm_level)
		return {"success": true, "type": "level", "old_realm": old_realm, "old_level": old_level, "new_level": realm_level, "stone_cost": stone_cost, "energy_cost": energy_cost, "materials": materials}
	elif type == "realm":
		var next_realm = result.get("next_realm", "")
		realm = next_realm
		realm_level = 1
		apply_realm_stats()
		realm_breakthrough.emit(realm, realm_level)
		return {"success": true, "type": "realm", "old_realm": old_realm, "new_realm": realm, "stone_cost": stone_cost, "energy_cost": energy_cost, "materials": materials}
	
	# 未知类型，突破失败
	breakthrough_failed.emit("突破类型错误")
	return {"success": false, "reason": "突破类型错误", "stone_cost": stone_cost, "energy_cost": energy_cost, "materials": materials}

func get_save_data() -> Dictionary:
	return {
		"realm": realm,
		"realm_level": realm_level,
		"health": AttributeCalculator.format_for_save(health),
		"spirit_energy": AttributeCalculator.format_for_save(spirit_energy),
		"tower_highest_floor": tower_highest_floor,
		"learned_recipes": learned_recipes,
		"has_alchemy_furnace": has_alchemy_furnace,
		"daily_dungeon_data": daily_dungeon_data.duplicate()
	}

func apply_save_data(data: Dictionary):
	if data.has("realm"):
		realm = data["realm"]
	if data.has("realm_level"):
		realm_level = data["realm_level"]
	if data.has("health"):
		health = float(data["health"])
	if data.has("spirit_energy"):
		spirit_energy = float(data["spirit_energy"])
	if data.has("tower_highest_floor"):
		tower_highest_floor = data["tower_highest_floor"]
	if data.has("learned_recipes"):
		learned_recipes = data["learned_recipes"]
	if data.has("has_alchemy_furnace"):
		has_alchemy_furnace = data["has_alchemy_furnace"]
	if data.has("daily_dungeon_data"):
		daily_dungeon_data = data["daily_dungeon_data"].duplicate()
	
	check_and_reset_daily_dungeons()

	# 重新计算可计算属性
	apply_realm_stats()

# ==================== 每日副本功能 ====================

func get_daily_dungeon_count(dungeon_id: String) -> int:
	_ensure_daily_dungeon_data(dungeon_id)
	return daily_dungeon_data[dungeon_id]["enter_count"]

func use_daily_dungeon_count(dungeon_id: String) -> bool:
	_ensure_daily_dungeon_data(dungeon_id)
	if daily_dungeon_data[dungeon_id]["enter_count"] <= 0:
		return false
	daily_dungeon_data[dungeon_id]["enter_count"] -= 1
	return true

func _ensure_daily_dungeon_data(dungeon_id: String):
	if not daily_dungeon_data.has(dungeon_id):
		daily_dungeon_data[dungeon_id] = {
			"enter_count": DAILY_DUNGEON_MAX_COUNT,
			"last_reset_date": _get_today_string()
		}

func check_and_reset_daily_dungeons():
	var today = _get_today_string()
	var now = Time.get_datetime_dict_from_system()
	var current_hour = now.hour
	
	for dungeon_id in daily_dungeon_data.keys():
		var last_reset = daily_dungeon_data[dungeon_id].get("last_reset_date", "")
		var need_reset = false
		
		if last_reset == "":
			need_reset = true
		elif last_reset != today:
			if current_hour >= DAILY_RESET_HOUR:
				need_reset = true
			else:
				need_reset = true
		
		if need_reset:
			daily_dungeon_data[dungeon_id]["enter_count"] = DAILY_DUNGEON_MAX_COUNT
			daily_dungeon_data[dungeon_id]["last_reset_date"] = today

func _get_today_string() -> String:
	var datetime = Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d" % [datetime.year, datetime.month, datetime.day]
