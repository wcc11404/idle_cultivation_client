class_name PlayerData extends Node

const ATTRIBUTE_CALCULATOR = preload("res://scripts/core/shared/AttributeCalculator.gd")

var realm: String = "炼气期"
var realm_level: int = 1

# 基础属性值（不包含任何加成）- 全部使用 float
var health: float = 50.0
var spirit_energy: float = 0.0
var max_spirit_energy: float = 5.0



# 基础属性（随境界变化）
var base_max_health: float = 50.0
var base_max_spirit: float = 5.0
var base_attack: float = 5.0
var base_defense: float = 2.0
var base_speed: float = 5.0
var base_health_regen: float = 1.0
var base_spirit_gain: float = 1.0

# 静态最终属性（基础属性 + 术法等永久加成）
var static_max_health: float = 50.0
var static_max_spirit_energy: float = 5.0
var static_attack: float = 5.0
var static_defense: float = 2.0
var static_speed: float = 5.0
var static_health_regen_per_second: float = 1.0
var static_spirit_gain_speed: float = 1.0

var cultivation_active: bool = false

# 战斗临时Buff（由LianliSystem管理）
var combat_buffs: Dictionary = {}

func _ready():
	add_to_group("player")
	# 初始化默认值
	health = 50.0
	base_max_health = 50.0
	reload_attributes()

func _load_base_attributes():
	var realm_system = get_node_or_null("/root/GameManager").get_realm_system() if get_node_or_null("/root/GameManager") else null
	
	if realm_system:
		var level_info = realm_system.get_level_info(realm, realm_level)
		base_max_health = float(level_info.get("health", 50))
		base_attack = float(level_info.get("attack", 5))
		base_defense = float(level_info.get("defense", 2))
		base_max_spirit = float(level_info.get("max_spirit_energy", 5))
		base_health_regen = float(level_info.get("health_regen", 1.0))
		max_spirit_energy = base_max_spirit
		# 从境界配置获取速度
		var realm_info = realm_system.get_realm_info(realm)
		base_speed = float(realm_info.get("speed", 5.0))
		base_spirit_gain = float(realm_info.get("spirit_gain_speed", 1.0))
	else:
		# 备用逻辑：使用默认属性
		var realm_info = get_default_realm_info()
		base_max_health = float(realm_info.get("health", 50))
		base_attack = float(realm_info.get("attack", 5))
		base_defense = float(realm_info.get("defense", 2))
		base_max_spirit = 5.0
		base_health_regen = 1.0
		max_spirit_energy = base_max_spirit
		base_speed = 5.0
		base_spirit_gain = 1.0

func _load_static_attributes():
	static_max_health = ATTRIBUTE_CALCULATOR.calculate_final_max_health(self)
	static_max_spirit_energy = ATTRIBUTE_CALCULATOR.calculate_final_max_spirit_energy(self)
	static_attack = ATTRIBUTE_CALCULATOR.calculate_final_attack(self)
	static_defense = ATTRIBUTE_CALCULATOR.calculate_final_defense(self)
	static_speed = ATTRIBUTE_CALCULATOR.calculate_final_speed(self)
	static_health_regen_per_second = base_health_regen
	static_spirit_gain_speed = ATTRIBUTE_CALCULATOR.calculate_final_spirit_gain_speed(self)
	
	health = min(health, static_max_health)

func apply_realm_stats():
	reload_attributes()

func reload_attributes():
	_load_base_attributes()
	_load_static_attributes()

func get_default_realm_info() -> Dictionary:
	return {"health": 50, "attack": 5, "defense": 2}

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
		"base_health_regen": base_health_regen,
		"base_spirit_gain": base_spirit_gain,
		# 最终属性（供UI显示使用）
		"final_max_health": static_max_health,
		"final_max_spirit": static_max_spirit_energy,
		"final_attack": static_attack,
		"final_defense": static_defense,
		"final_speed": static_speed,
		"final_health_regen": static_health_regen_per_second,
		"final_spirit_gain": static_spirit_gain_speed,
		"spirit_stone": actual_spirit_stone
	}

func get_status_dict() -> Dictionary:
	var status = get_display_dict()
	status["is_cultivating"] = cultivation_active
	status["can_breakthrough"] = get_breakthrough_display_hint()
	return status

func get_breakthrough_display_hint() -> Dictionary:
	var realm_system = get_node_or_null("/root/GameManager").get_realm_system() if get_node_or_null("/root/GameManager") else null
	if not realm_system:
		return {}
	var realm_info = realm_system.get_realm_info(realm)
	var max_level = int(realm_info.get("max_level", 0))
	if max_level > 0 and realm_level >= max_level:
		return {"type": "realm"}
	return {"type": "level"}

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
	return static_attack

func get_final_defense() -> float:
	return static_defense

func get_final_speed() -> float:
	return static_speed

func get_final_max_health() -> float:
	return static_max_health

func get_final_max_spirit_energy() -> float:
	return static_max_spirit_energy

func get_final_spirit_gain_speed() -> float:
	return static_spirit_gain_speed

func get_base_health_regen_per_second() -> float:
	return base_health_regen

func get_base_spirit_gain_speed() -> float:
	return base_spirit_gain

func get_static_health_regen_per_second() -> float:
	return static_health_regen_per_second

# ==================== 战斗最终能力值计算 ====================
# 战斗最终能力值 = 静态最终能力值 + 战斗临时Buff

func get_combat_attack() -> float:
	return ATTRIBUTE_CALCULATOR.calculate_combat_attack(self, combat_buffs)

func get_combat_defense() -> float:
	return ATTRIBUTE_CALCULATOR.calculate_combat_defense(self, combat_buffs)

func get_combat_speed() -> float:
	return ATTRIBUTE_CALCULATOR.calculate_combat_speed(self, combat_buffs)

func get_combat_max_health() -> float:
	return ATTRIBUTE_CALCULATOR.calculate_combat_max_health(self, combat_buffs)

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

func get_save_data() -> Dictionary:
	return {
		"realm": realm,
		"realm_level": realm_level,
		"health": health,
		"spirit_energy": spirit_energy,
		"max_spirit_energy": max_spirit_energy,
		"is_cultivating": cultivation_active
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
	if data.has("max_spirit_energy"):
		max_spirit_energy = float(data["max_spirit_energy"])
	if data.has("is_cultivating"):
		cultivation_active = bool(data["is_cultivating"])
	else:
		cultivation_active = false

	# 重新计算可计算属性
	apply_realm_stats()
