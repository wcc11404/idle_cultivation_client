extends GutTest

## EnemyData 单元测试

var enemy_data: EnemyData = null

func before_all():
	await get_tree().process_frame

func before_each():
	enemy_data = EnemyData.new()
	
	add_child(enemy_data)
	await get_tree().process_frame
	
	# 在 _ready 之后设置 mock 数据
	_setup_mock_data()

func after_each():
	if enemy_data:
		enemy_data.free()
		enemy_data = null
	await get_tree().process_frame

func _setup_mock_data():
	enemy_data.ENEMY_TEMPLATES = {
		"qi_monster": {
			"name": "炼气期妖兽",
			"name_variants": ["炼气期妖兽", "野生妖兽"],
			"is_elite": false,
			"growth": {
				"health_base": 100,
				"health_growth": 1.1,
				"attack_base": 20,
				"attack_growth": 1.08,
				"defense_base": 5,
				"defense_growth": 1.05,
				"speed_base": 5,
				"speed_growth": 0.02
			}
		},
		"elite_monster": {
			"name": "精英妖兽",
			"is_elite": true,
			"growth": {
				"health_base": 500,
				"health_growth": 1.15,
				"attack_base": 50,
				"attack_growth": 1.1,
				"defense_base": 20,
				"defense_growth": 1.08,
				"speed_base": 7,
				"speed_growth": 0.03
			}
		}
	}

#region 初始化测试

func test_initial_templates():
	assert_eq(enemy_data.ENEMY_TEMPLATES.size(), 2, "应有2个敌人模板")

#endregion

#region 生成敌人测试

func test_generate_enemy_basic():
	var enemy = enemy_data.generate_enemy("qi_monster", 1)
	assert_false(enemy.is_empty(), "应生成敌人")
	assert_eq(enemy.level, 1, "等级应为1")
	assert_false(enemy.is_elite, "不应是精英")

func test_generate_enemy_level_5():
	var enemy = enemy_data.generate_enemy("qi_monster", 5)
	assert_eq(enemy.level, 5, "等级应为5")
	assert_gt(enemy.stats.health, 100, "高等级应有更高气血")

func test_generate_enemy_elite():
	var enemy = enemy_data.generate_enemy("elite_monster", 1)
	assert_true(enemy.is_elite, "应是精英")

func test_generate_enemy_invalid_template():
	var enemy = enemy_data.generate_enemy("invalid_template", 1)
	assert_eq(enemy, {}, "无效模板应返回空字典")

func test_generate_enemy_has_stats():
	var enemy = enemy_data.generate_enemy("qi_monster", 1)
	assert_true(enemy.has("stats"), "应有属性数据")
	assert_true(enemy.stats.has("health"), "应有气血")
	assert_true(enemy.stats.has("attack"), "应有攻击")
	assert_true(enemy.stats.has("defense"), "应有防御")
	assert_true(enemy.stats.has("speed"), "应有速度")

func test_generate_enemy_health_growth():
	var enemy1 = enemy_data.generate_enemy("qi_monster", 1)
	var enemy5 = enemy_data.generate_enemy("qi_monster", 5)
	assert_gt(enemy5.stats.health, enemy1.stats.health, "高等级应有更高气血")

func test_generate_enemy_attack_growth():
	var enemy1 = enemy_data.generate_enemy("qi_monster", 1)
	var enemy5 = enemy_data.generate_enemy("qi_monster", 5)
	assert_gt(enemy5.stats.attack, enemy1.stats.attack, "高等级应有更高攻击")

func test_generate_enemy_defense_growth():
	var enemy1 = enemy_data.generate_enemy("qi_monster", 1)
	var enemy5 = enemy_data.generate_enemy("qi_monster", 5)
	assert_gt(enemy5.stats.defense, enemy1.stats.defense, "高等级应有更高防御")

func test_generate_enemy_template_id():
	var enemy = enemy_data.generate_enemy("qi_monster", 1)
	assert_eq(enemy.template_id, "qi_monster", "模板ID应正确")

#endregion

#region 敌人名称测试

func test_generate_enemy_name():
	var enemy = enemy_data.generate_enemy("qi_monster", 1)
	assert_true(enemy.name in ["炼气期妖兽", "野生妖兽"], "名称应为变体之一")

func test_generate_enemy_elite_name():
	var enemy = enemy_data.generate_enemy("elite_monster", 1)
	assert_eq(enemy.name, "精英妖兽", "精英名称应正确")

#endregion

#region 模板信息测试

func test_get_template_name():
	var name = enemy_data.get_template_name("qi_monster")
	assert_eq(name, "炼气期妖兽", "模板名称应正确")

func test_get_template_name_invalid():
	var name = enemy_data.get_template_name("invalid_template")
	assert_eq(name, "未知敌人", "无效模板应返回未知敌人")

func test_is_elite_template_true():
	var is_elite = enemy_data.is_elite_template("elite_monster")
	assert_true(is_elite, "精英模板应返回true")

func test_is_elite_template_false():
	var is_elite = enemy_data.is_elite_template("qi_monster")
	assert_false(is_elite, "普通模板应返回false")

func test_is_elite_template_invalid():
	var is_elite = enemy_data.is_elite_template("invalid_template")
	assert_false(is_elite, "无效模板应返回false")

func test_get_all_template_ids():
	var ids = enemy_data.get_all_template_ids()
	assert_eq(ids.size(), 2, "应有2个模板ID")

#endregion
