extends Node

var helper: Node = null
var test_item_data: Node = null

func _ready():
	helper = load("res://tests/test_helper.gd").new()
	add_child(helper)

func run_tests():
	print("\n=== ItemData 单元测试 ===")
	helper.reset_stats()
	
	test_item_data = load("res://scripts/core/ItemData.gd").new()
	add_child(test_item_data)
	
	test_module_loading()
	test_item_names()
	test_max_stack()
	test_can_stack()
	test_quality_colors()
	test_starter_pack()
	
	return helper.failed_count == 0

func test_module_loading():
	helper.assert_true(test_item_data != null, "ItemData", "模块初始化")

func test_item_names():
	var name = test_item_data.get_item_name("spirit_stone")
	helper.assert_eq(name, "灵石", "ItemData", "获取物品名称-灵石")
	
	name = test_item_data.get_item_name("health_pill")
	helper.assert_eq(name, "补血丹", "ItemData", "获取物品名称-补血丹")
	
	name = test_item_data.get_item_name("unknown_item")
	helper.assert_eq(name, "未知物品", "ItemData", "获取未知物品名称")

func test_max_stack():
	var max_stack = test_item_data.get_max_stack("spirit_stone")
	helper.assert_eq(max_stack, 999999999, "ItemData", "灵石最大堆叠")
	
	max_stack = test_item_data.get_max_stack("mat_iron")
	helper.assert_eq(max_stack, 99, "ItemData", "玄铁最大堆叠")
	
	max_stack = test_item_data.get_max_stack("health_pill")
	helper.assert_eq(max_stack, 99, "ItemData", "补血丹最大堆叠")

func test_can_stack():
	var can_stack = test_item_data.can_stack("spirit_stone")
	helper.assert_true(can_stack == true, "ItemData", "灵石可堆叠")
	
	can_stack = test_item_data.can_stack("health_pill")
	helper.assert_true(can_stack == true, "ItemData", "补血丹可堆叠")

func test_quality_colors():
	var color = test_item_data.get_item_quality_color(0)
	helper.assert_true(color == Color("#D3D3D3"), "ItemData", "灰色品质颜色")
	
	color = test_item_data.get_item_quality_color(2)
	helper.assert_true(color == Color("#00BFFF"), "ItemData", "蓝色品质颜色")

func test_starter_pack():
	var starter_pack_data = test_item_data.get_item_data("starter_pack")
	helper.assert_true(!starter_pack_data.is_empty(), "ItemData", "新手礼包数据加载")
	
	var pack_name = test_item_data.get_item_name("starter_pack")
	helper.assert_eq(pack_name, "新手礼包Ⅰ", "ItemData", "新手礼包名称")
	
	var pack_type = starter_pack_data.get("type", -1)
	helper.assert_eq(pack_type, 3, "ItemData", "新手礼包类型")
	
	var pack_content = starter_pack_data.get("content", {})
	helper.assert_true(!pack_content.is_empty(), "ItemData", "新手礼包内容")
