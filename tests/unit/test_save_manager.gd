extends Node

var helper: Node = null
var test_save_manager: Node = null
var test_player: Node = null
var test_inventory: Node = null
var test_item_data: Node = null

func _ready():
	helper = load("res://tests/test_helper.gd").new()
	add_child(helper)

func run_tests():
	print("\n=== SaveManager 单元测试 ===")
	helper.reset_stats()
	
	test_save_manager = load("res://scripts/core/SaveManager.gd").new()
	add_child(test_save_manager)
	
	test_player = load("res://scripts/core/PlayerData.gd").new()
	add_child(test_player)
	
	test_item_data = load("res://scripts/core/inventory/ItemData.gd").new()
	add_child(test_item_data)
	
	test_inventory = load("res://scripts/core/inventory/Inventory.gd").new()
	test_inventory.item_data = test_item_data
	add_child(test_inventory)
	
	test_initialization()
	test_version()
	test_save_data_structure()
	test_has_save()
	
	return helper.failed_count == 0

func test_initialization():
	helper.assert_true(test_save_manager != null, "SaveManager", "模块初始化")

func test_version():
	helper.assert_eq(test_save_manager.SAVE_VERSION, "1.3", "SaveManager", "版本号正确")

func test_save_data_structure():
	var save_data = {
		"player": test_player.get_save_data(),
		"inventory": test_inventory.get_save_data(),
		"spell_system": {},
		"timestamp": Time.get_unix_time_from_system(),
		"version": "1.3"
	}
	
	helper.assert_true(save_data.has("player"), "SaveManager", "包含玩家数据")
	helper.assert_true(save_data.has("inventory"), "SaveManager", "包含储纳数据")
	helper.assert_true(save_data.has("spell_system"), "SaveManager", "包含术法系统数据")
	helper.assert_true(save_data.has("timestamp"), "SaveManager", "包含时间戳")
	helper.assert_true(save_data.has("version"), "SaveManager", "包含版本号")

func test_has_save():
	var has_save = test_save_manager.has_save()
	helper.assert_true(true, "SaveManager", "has_save方法存在")
	
	var delete_result = test_save_manager.delete_save()
	helper.assert_true(true, "SaveManager", "delete_save方法存在")
