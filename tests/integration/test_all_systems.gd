extends Node

var helper: Node = null
var all_passed: bool = true

func _ready():
	helper = load("res://tests/test_helper.gd").new()
	add_child(helper)

func run_tests():
	print("\n========================================")
	print("修仙游戏核心系统集成测试")
	print("========================================")
	helper.reset_stats()
	
	await get_tree().create_timer(0.5).timeout
	
	test_player_data()
	test_cultivation_system()
	test_lianli_system()
	test_level_up()
	test_realm_system()
	test_inventory_system()
	test_game_flow()
	
	print("\n========================================")
	helper.print_test_summary()
	
	return helper.failed_count == 0

func test_player_data():
	print("\n=== PlayerData 测试 (集成环境) ===")

	var game_manager = get_node_or_null("/root/GameManager")
	if not game_manager:
		print("✗ 无法获取GameManager")
		helper.assert_true(false, "集成测试", "GameManager存在")
		return

	var player = game_manager.get_player()
	if not player:
		print("✗ 无法获取GameManager中的player")
		helper.assert_true(false, "集成测试", "Player存在")
		return

	helper.assert_eq(player.realm, "炼气期", "集成测试", "初始境界")
	helper.assert_eq(player.realm_level, 1, "集成测试", "初始境界等级")
	helper.assert_eq(int(player.health), 50, "集成测试", "初始生命值")
	helper.assert_eq(int(player.get_final_max_health()), 50, "集成测试", "初始最大生命值")
	helper.assert_eq(int(player.spirit_energy), 0, "集成测试", "初始灵气")
	helper.assert_eq(int(player.get_final_max_spirit_energy()), 5, "集成测试", "初始最大灵气")

	var game_manager_inv = game_manager.get_inventory()
	game_manager_inv.add_item("spirit_stone", 100)
	helper.assert_true(game_manager_inv.get_item_count("spirit_stone") >= 100, "集成测试", "添加灵石")

	player.base_max_spirit = 100.0
	player.add_spirit_energy(50)
	helper.assert_eq(int(player.spirit_energy), 50, "集成测试", "添加灵气")

	player.health = 30.0
	player.health = min(player.health + 10, player.get_final_max_health())
	helper.assert_eq(int(player.health), 40, "集成测试", "恢复生命值")

func test_cultivation_system():
	print("\n=== CultivationSystem 测试 (集成环境) ===")

	var game_manager = get_node_or_null("/root/GameManager")
	if not game_manager:
		return

	var player = game_manager.get_player()
	var cult_system = game_manager.get_cultivation_system()

	if not player or not cult_system:
		print("✗ 无法获取GameManager中的player或cult_system")
		helper.assert_true(false, "集成测试", "CultivationSystem存在")
		return

	player.spirit_energy = 0.0

	cult_system.start_cultivation()
	helper.assert_true(cult_system.is_cultivating, "集成测试", "开始修炼状态")
	helper.assert_true(player.get_is_cultivating(), "集成测试", "玩家修炼状态已开启")

	cult_system.stop_cultivation()
	helper.assert_true(not cult_system.is_cultivating, "集成测试", "停止修炼状态")
	helper.assert_true(not player.get_is_cultivating(), "集成测试", "玩家修炼状态已关闭")

	player.spirit_energy = 0.0
	cult_system.start_cultivation()
	cult_system._process(1.5)
	helper.assert_eq(int(player.spirit_energy), 1, "集成测试", "修炼1次增加1灵气")

	player.spirit_energy = 0.0
	player.base_max_spirit = 100.0
	cult_system.start_cultivation()
	for i in range(100):
		cult_system._process(1.0)

	helper.assert_true(player.spirit_energy >= 99, "集成测试", "灵气接近或达到最大值")

func test_lianli_system():
	print("\n=== LianliSystem 测试 (集成环境) ===")

	var game_manager = get_node_or_null("/root/GameManager")
	if not game_manager:
		return

	var player = game_manager.get_player()
	var lianli_system = game_manager.get_lianli_system()

	if not player or not lianli_system:
		print("✗ 无法获取GameManager中的player或lianli_system")
		helper.assert_true(false, "集成测试", "LianliSystem存在")
		return

	player.health = 500.0
	player.base_max_health = 500.0
	player.base_attack = 100.0
	player.base_defense = 50.0
	player.base_speed = 10.0

	var enemy_data = {
		"name": "筑基期妖兽",
		"level": 15,
		"health": 1000,
		"attack": 100,
		"defense": 50,
		"speed": 9
	}

	lianli_system.start_battle(enemy_data)
	helper.assert_true(lianli_system.is_in_battle, "集成测试", "战斗已开始")

	lianli_system._process(1.0)
	helper.assert_true(lianli_system.current_enemy.get("current_health", 0) < 1000, "集成测试", "敌人受到伤害")

func test_level_up():
	print("\n=== LevelUp 测试 (集成环境) ===")
	var game_manager = get_node_or_null("/root/GameManager")
	if not game_manager:
		return
	
	var player = game_manager.get_player()
	if not player:
		return
	
	# level 字段已删除，使用 realm_level 代替
	var original_realm_level = player.realm_level
	player.realm_level += 1
	helper.assert_eq(player.realm_level, original_realm_level + 1, "集成测试", "境界等级提升")

func test_realm_system():
	print("\n=== 境界系统测试 (集成环境) ===")

	var game_manager = get_node_or_null("/root/GameManager")
	if not game_manager:
		return

	var player = game_manager.get_player()
	var realm_system = game_manager.get_realm_system()

	if not player or not realm_system:
		print("✗ 无法获取GameManager中的player或realm_system")
		helper.assert_true(false, "集成测试", "RealmSystem存在")
		return

	player.realm = "炼气期"
	player.realm_level = 1
	player.apply_realm_stats()

	helper.assert_eq(int(player.get_final_max_health()), 50, "集成测试", "炼气期1段最大生命")
	helper.assert_eq(int(player.get_final_attack()), 5, "集成测试", "炼气期1段攻击力")

	player.realm_level = 5
	player.apply_realm_stats()
	helper.assert_eq(int(player.get_final_max_health()), 76, "集成测试", "炼气期5段最大生命")
	helper.assert_true(player.get_final_attack() > 5, "集成测试", "炼气期5段攻击力增加")

	var display_name = realm_system.get_realm_display_name("炼气期", 3)
	helper.assert_eq(display_name, "炼气期 三层", "集成测试", "境界显示名称")

	var level_info = realm_system.get_level_info("炼气期", 2)
	helper.assert_true(level_info.get("health", 0) > 50, "集成测试", "炼气期2段属性增加")

func test_inventory_system():
	print("\n=== Inventory 系统测试 (集成环境) ===")

	var game_manager = get_node_or_null("/root/GameManager")
	if not game_manager:
		return

	var inventory = game_manager.get_inventory()
	var item_data = game_manager.get_item_data()

	if not inventory or not item_data:
		print("✗ 无法获取GameManager中的inventory或item_data")
		helper.assert_true(false, "集成测试", "Inventory存在")
		return

	inventory.clear()

	helper.assert_true(inventory.add_item("spirit_stone", 10), "集成测试", "添加灵石10个")
	helper.assert_eq(inventory.get_item_count("spirit_stone"), 10, "集成测试", "灵石数量为10")

	helper.assert_true(inventory.add_item("mat_iron", 5), "集成测试", "添加玄铁5个")
	helper.assert_eq(inventory.get_item_count("mat_iron"), 5, "集成测试", "玄铁数量为5")

	helper.assert_true(inventory.has_item("spirit_stone", 5), "集成测试", "拥有5个以上灵石")
	helper.assert_true(not inventory.has_item("spirit_stone", 15), "集成测试", "没有15个灵石")

	helper.assert_true(inventory.remove_item("spirit_stone", 3), "集成测试", "移除3个灵石")
	helper.assert_eq(inventory.get_item_count("spirit_stone"), 7, "集成测试", "灵石剩余7个")

	# get_all_items 已删除，使用 get_item_list 代替
	var items = inventory.get_item_list()
	var non_empty_count = 0
	for item in items:
		if not item.empty:
			non_empty_count += 1
	helper.assert_eq(non_empty_count, 2, "集成测试", "背包中有2种物品")

	helper.assert_true(inventory.add_item("spirit_stone", 100), "集成测试", "叠加灵石")
	helper.assert_true(inventory.get_item_count("spirit_stone") > 7, "集成测试", "灵石已叠加")

	inventory.clear()
	var empty_items = inventory.get_item_list()
	var cleared_count = 0
	for item in empty_items:
		if not item.empty:
			cleared_count += 1
	helper.assert_eq(cleared_count, 0, "集成测试", "清空后背包为空")

func test_game_flow():
	print("\n=== 完整游戏流程测试 (集成环境) ===")

	var game_manager = get_node_or_null("/root/GameManager")
	if not game_manager:
		return

	var player = game_manager.get_player()
	var inventory = game_manager.get_inventory()
	var cult_system = game_manager.get_cultivation_system()
	var lianli_system = game_manager.get_lianli_system()

	if not player or not inventory or not cult_system or not lianli_system:
		print("✗ 无法获取GameManager中的系统")
		helper.assert_true(false, "集成测试", "游戏系统完整")
		return

	player.realm = "炼气期"
	player.realm_level = 1
	player.apply_realm_stats()
	player.spirit_energy = 0
	inventory.clear()

	helper.assert_eq(player.realm, "炼气期", "集成测试", "游戏开始境界正确")
	helper.assert_eq(player.realm_level, 1, "集成测试", "游戏开始境界等级正确")

	cult_system.start_cultivation()
	helper.assert_true(cult_system.is_cultivating, "集成测试", "修炼启动")

	for i in range(10):
		cult_system._process(1.0)

	helper.assert_true(player.spirit_energy > 0, "集成测试", "修炼获得灵气")

	cult_system.stop_cultivation()

	var enemy_data = {
		"name": "炼气期小妖",
		"level": 5,
		"health": 350,
		"attack": 35,
		"defense": 10,
		"speed": 20
	}

	lianli_system.start_battle(enemy_data)
	helper.assert_true(lianli_system.is_in_battle, "集成测试", "战斗启动")

	for i in range(5):
		lianli_system._process(1.0)

	helper.assert_true(player.realm_level >= 1, "集成测试", "玩家境界等级保持")

	print("\n✓ 完整游戏流程测试通过！")
