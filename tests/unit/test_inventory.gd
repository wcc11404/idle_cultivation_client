extends Node

var helper: Node = null
var test_inventory: Node = null
var test_item_data: Node = null

func _ready():
	helper = load("res://tests/test_helper.gd").new()
	add_child(helper)

func run_tests():
	print("\n=== Inventory 单元测试 ===")
	helper.reset_stats()
	
	test_item_data = load("res://scripts/core/ItemData.gd").new()
	add_child(test_item_data)
	
	test_inventory = load("res://scripts/core/inventory/Inventory.gd").new()
	test_inventory.item_data = test_item_data
	add_child(test_inventory)
	
	test_initialization()
	test_add_remove_items()
	test_has_item()
	test_stacking_items()
	test_order_preservation()
	test_save_load()
	
	return helper.failed_count == 0

func test_initialization():
	helper.assert_true(test_inventory != null, "Inventory", "模块初始化")
	
	var item_list = test_inventory.get_item_list()
	helper.assert_eq(item_list.size(), 50, "Inventory", "物品列表大小")

func test_add_remove_items():
	test_inventory.clear()
	
	var add_result = test_inventory.add_item("spirit_stone", 100)
	helper.assert_true(add_result == true, "Inventory", "添加灵石")
	
	var stone_count = test_inventory.get_item_count("spirit_stone")
	helper.assert_eq(stone_count, 100, "Inventory", "灵石数量")
	
	var remove_result = test_inventory.remove_item("spirit_stone", 30)
	helper.assert_true(remove_result == true, "Inventory", "移除灵石")
	
	stone_count = test_inventory.get_item_count("spirit_stone")
	helper.assert_eq(stone_count, 70, "Inventory", "移除后数量")

func test_has_item():
	test_inventory.clear()
	test_inventory.add_item("spirit_stone", 100)
	
	var has_stone = test_inventory.has_item("spirit_stone", 50)
	helper.assert_true(has_stone == true, "Inventory", "拥有足够灵石")
	
	has_stone = test_inventory.has_item("spirit_stone", 200)
	helper.assert_true(has_stone == false, "Inventory", "拥有不足灵石")

func test_stacking_items():
	test_inventory.clear()
	
	test_inventory.add_item("spirit_stone", 500)
	test_inventory.add_item("spirit_stone", 300)
	
	var stone_count = test_inventory.get_item_count("spirit_stone")
	helper.assert_eq(stone_count, 800, "Inventory", "灵石堆叠")
	
	var item_list = test_inventory.get_item_list()
	var non_empty_count = 0
	for item in item_list:
		if !item.get("empty", true):
			non_empty_count += 1
	helper.assert_eq(non_empty_count, 1, "Inventory", "只占一个格子")

func test_order_preservation():
	test_inventory.clear()
	
	test_inventory.add_item("spirit_stone", 1)
	test_inventory.add_item("mat_iron", 1)
	test_inventory.add_item("health_pill", 1)
	
	var item_list = test_inventory.get_item_list()
	
	var first_item = item_list[0]
	var second_item = item_list[1]
	var third_item = item_list[2]
	
	helper.assert_eq(first_item.get("id", ""), "spirit_stone", "Inventory", "第一个是灵石")
	helper.assert_eq(second_item.get("id", ""), "mat_iron", "Inventory", "第二个是玄铁")
	helper.assert_eq(third_item.get("id", ""), "health_pill", "Inventory", "第三个是补血丹")

func test_save_load():
	test_inventory.clear()
	test_inventory.add_item("spirit_stone", 500)
	test_inventory.add_item("mat_iron", 5)
	test_inventory.add_item("starter_pack", 1)
	
	var inventory_data = test_inventory.get_save_data()
	helper.assert_true(!inventory_data.is_empty(), "Inventory", "存档数据不为空")
	
	var slots = inventory_data.get("slots", [])
	helper.assert_true(slots.size() > 0, "Inventory", "存档包含slots")
	
	var stone_count_in_save = 0
	for slot in slots:
		if slot.get("id", "") == "spirit_stone":
			stone_count_in_save += slot.get("count", 0)
	helper.assert_eq(stone_count_in_save, 500, "Inventory", "灵石数量保存正确")
	
	var new_inventory = load("res://scripts/core/inventory/Inventory.gd").new()
	new_inventory.item_data = test_item_data
	new_inventory.apply_save_data(inventory_data)
	
	var new_stone_count = new_inventory.get_item_count("spirit_stone")
	helper.assert_eq(new_stone_count, 500, "Inventory", "灵石数量恢复")
