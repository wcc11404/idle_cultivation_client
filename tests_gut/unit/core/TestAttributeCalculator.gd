extends GutTest

## AttributeCalculator 单元测试

#region 格式化函数测试

func test_format_default_with_decimals():
	var result = AttributeCalculator.format_default(1.50)
	assert_eq(result, "1.5", "1.50 应格式化为 1.5")

func test_format_default_whole_number():
	var result = AttributeCalculator.format_default(2.00)
	assert_eq(result, "2", "2.00 应格式化为 2")

func test_format_default_small_decimal():
	var result = AttributeCalculator.format_default(1.05)
	assert_eq(result, "1.05", "1.05 应保持不变")

func test_format_percent_basic():
	var result = AttributeCalculator.format_percent(0.15)
	assert_eq(result, "15%", "0.15 应格式化为 15%")

func test_format_percent_small():
	var result = AttributeCalculator.format_percent(0.005)
	assert_eq(result, "0.5%", "0.005 应格式化为 0.5%")

func test_format_percent_over_100():
	var result = AttributeCalculator.format_percent(1.10)
	assert_eq(result, "110%", "1.10 应格式化为 110%")

func test_format_one_decimal_with_decimal():
	var result = AttributeCalculator.format_one_decimal(50.5)
	assert_eq(result, "50.5", "50.5 应保持不变")

func test_format_one_decimal_whole():
	var result = AttributeCalculator.format_one_decimal(50.0)
	assert_eq(result, "50", "50.0 应格式化为 50")

func test_format_integer():
	var result = AttributeCalculator.format_integer(255.7)
	assert_eq(result, "256", "255.7 应四舍五入为 256")

func test_format_integer_exact():
	var result = AttributeCalculator.format_integer(100.0)
	assert_eq(result, "100", "100.0 应格式化为 100")

func test_format_attack_defense_small():
	var result = AttributeCalculator.format_attack_defense(500.5)
	assert_eq(result, "500.5", "<=1000 应保留一位小数")

func test_format_attack_defense_large():
	var result = AttributeCalculator.format_attack_defense(1500.7)
	assert_eq(result, "1.5K", ">=1000 应转K/M并保留一位小数去尾0")

func test_format_damage_small():
	var result = AttributeCalculator.format_damage(999.5)
	assert_eq(result, "999.5", "<=1000 伤害保留一位小数")

func test_format_damage_large():
	var result = AttributeCalculator.format_damage(1000.5)
	assert_eq(result, "1K", ">=1000 伤害应转K/M并保留一位小数去尾0")

func test_format_for_save_trailing_zeros():
	var result = AttributeCalculator.format_for_save(50.5000)
	assert_eq(result, "50.5", "应去除尾随零")

func test_format_for_save_whole():
	var result = AttributeCalculator.format_for_save(100.0000)
	assert_eq(result, "100", "整数应无小数点")

func test_format_for_save_small_decimal():
	var result = AttributeCalculator.format_for_save(0.0020)
	assert_eq(result, "0.002", "应保留有效小数")

#endregion

#region 伤害计算测试

func test_calculate_damage_basic():
	var damage = AttributeCalculator.calculate_damage(100.0, 30.0)
	assert_true(abs(damage - 76.9230769) < 0.001, "应按减伤公式计算基础伤害")

func test_calculate_damage_with_percent():
	var damage = AttributeCalculator.calculate_damage(100.0, 30.0, 1.5)
	assert_true(abs(damage - 115.3846154) < 0.001, "150%伤害应按减伤后结果放大")

func test_calculate_damage_minimum():
	var damage = AttributeCalculator.calculate_damage(10.0, 50.0)
	assert_true(abs(damage - 6.6666667) < 0.001, "应按减伤公式计算伤害")

func test_calculate_damage_zero_defense():
	var damage = AttributeCalculator.calculate_damage(100.0, 0.0)
	assert_eq(damage, 100.0, "零防御时应为全额伤害")

func test_calculate_damage_high_defense():
	var damage = AttributeCalculator.calculate_damage(50.0, 100.0)
	assert_true(abs(damage - 25.0) < 0.001, "高防御场景仍应按减伤公式计算")

func test_calculate_damage_with_small_percent():
	var damage = AttributeCalculator.calculate_damage(100.0, 0.0, 0.5)
	assert_eq(damage, 50.0, "50%伤害应正确计算")

#endregion

#region 最终属性计算测试 - 空玩家

func test_calculate_final_attack_null_player():
	var attack = AttributeCalculator.calculate_final_attack(null)
	assert_eq(attack, 0.0, "空玩家攻击力应为0")

func test_calculate_final_defense_null_player():
	var defense = AttributeCalculator.calculate_final_defense(null)
	assert_eq(defense, 0.0, "空玩家防御力应为0")

func test_calculate_final_speed_null_player():
	var speed = AttributeCalculator.calculate_final_speed(null)
	assert_eq(speed, 0.0, "空玩家速度应为0")

func test_calculate_final_max_health_null_player():
	var health = AttributeCalculator.calculate_final_max_health(null)
	assert_eq(health, 0.0, "空玩家最大气血应为0")

func test_calculate_final_max_spirit_energy_null_player():
	var spirit = AttributeCalculator.calculate_final_max_spirit_energy(null)
	assert_eq(spirit, 0.0, "空玩家最大灵气应为0")

func test_calculate_final_spirit_gain_speed_null_player():
	var speed = AttributeCalculator.calculate_final_spirit_gain_speed(null)
	assert_eq(speed, 1.0, "空玩家灵气获取速度应为1.0")

func test_calculate_final_spirit_gain_speed_uses_player_base_speed():
	var player = _create_simple_mock_player(100.0, 50.0, 5.0)
	player.base_spirit_gain = 2.5
	var speed = AttributeCalculator.calculate_final_spirit_gain_speed(player)
	assert_eq(speed, 2.5, "应优先使用玩家当前基础灵气获取速度")
	player.free()

#endregion

#region 战斗属性计算测试 - 使用模拟对象

func test_calculate_combat_attack_empty_buffs():
	var player = _create_simple_mock_player(100.0, 50.0, 5.0)
	var attack = AttributeCalculator.calculate_combat_attack(player, {})
	assert_eq(attack, 100.0, "无Buff时攻击力等于基础值")
	player.free()

func test_calculate_combat_attack_with_buff():
	var player = _create_simple_mock_player(100.0, 50.0, 5.0)
	var buffs = {"attack_percent": 0.2}
	var attack = AttributeCalculator.calculate_combat_attack(player, buffs)
	assert_eq(attack, 120.0, "20%攻击加成应正确计算")
	player.free()

func test_calculate_combat_defense_empty_buffs():
	var player = _create_simple_mock_player(100.0, 50.0, 5.0)
	var defense = AttributeCalculator.calculate_combat_defense(player, {})
	assert_eq(defense, 50.0, "无Buff时防御力等于基础值")
	player.free()

func test_calculate_combat_defense_with_buff():
	var player = _create_simple_mock_player(100.0, 50.0, 5.0)
	var buffs = {"defense_percent": 0.3}
	var defense = AttributeCalculator.calculate_combat_defense(player, buffs)
	assert_eq(defense, 65.0, "30%防御加成应正确计算")
	player.free()

func test_calculate_combat_speed_empty_buffs():
	var player = _create_simple_mock_player(100.0, 50.0, 5.0)
	var speed = AttributeCalculator.calculate_combat_speed(player, {})
	assert_eq(speed, 5.0, "无Buff时速度等于基础值")
	player.free()

func test_calculate_combat_speed_with_buff():
	var player = _create_simple_mock_player(100.0, 50.0, 5.0)
	var buffs = {"speed_bonus": 3.0}
	var speed = AttributeCalculator.calculate_combat_speed(player, buffs)
	assert_eq(speed, 8.0, "速度加成应为加法")
	player.free()

func test_calculate_combat_max_health_empty_buffs():
	var player = _create_simple_mock_player(100.0, 50.0, 5.0)
	player.base_max_health = 500.0
	var health = AttributeCalculator.calculate_combat_max_health(player, {})
	assert_eq(health, 500.0, "无Buff时最大气血等于基础值")
	player.free()

func test_calculate_combat_max_health_with_buff():
	var player = _create_simple_mock_player(100.0, 50.0, 5.0)
	player.base_max_health = 500.0
	var buffs = {"health_bonus": 100.0}
	var health = AttributeCalculator.calculate_combat_max_health(player, buffs)
	assert_eq(health, 600.0, "气血加成应为加法")
	player.free()

#endregion

#region 辅助函数

func _create_simple_mock_player(attack: float, defense: float, speed: float) -> Node:
	var script = GDScript.new()
	script.source_code = """
extends Node
var base_attack: float = 0.0
var base_defense: float = 0.0
var base_speed: float = 0.0
var base_max_health: float = 500.0
var base_max_spirit: float = 100.0
var base_spirit_gain: float = 1.0
func get_spell_system(): return null
"""
	script.reload()
	
	var player = Node.new()
	player.set_script(script)
	player.base_attack = attack
	player.base_defense = defense
	player.base_speed = speed
	
	return player

#endregion
