extends GutTest

## ItemData 单元测试

var item_data: ItemData = null

func before_all():
	await get_tree().process_frame

func before_each():
	item_data = ItemData.new()
	
	add_child(item_data)
	await get_tree().process_frame
	
	# 在 _ready 之后设置 mock 数据
	_setup_mock_data()

func after_each():
	if item_data:
		item_data.queue_free()

func _setup_mock_data():
	item_data.item_data = {
		"spirit_stone": {
			"name": "灵石",
			"description": "修仙者的通用货币",
			"type": ItemData.ItemType.CURRENCY,
			"max_stack": 999,
			"quality": 0,
			"icon": "res://icons/spirit_stone.png"
		},
		"herb": {
			"name": "灵草",
			"description": "炼丹的基础材料",
			"type": ItemData.ItemType.MATERIAL,
			"max_stack": 99,
			"quality": 1
		},
		"healing_pill": {
			"name": "疗伤丹",
			"description": "恢复气血",
			"type": ItemData.ItemType.CONSUMABLE,
			"max_stack": 10,
			"quality": 2,
			"effect": {"type": "heal", "value": 100}
		},
		"gift_box": {
			"name": "礼包",
			"description": "打开获得奖励",
			"type": ItemData.ItemType.GIFT,
			"max_stack": 1,
			"quality": 3
		}
	}

#region 初始化测试

func test_initial_item_data():
	assert_eq(item_data.item_data.size(), 4, "应有4个物品")

func test_item_type_enum():
	assert_eq(item_data.ItemType.CURRENCY, 0, "货币类型应为0")
	assert_eq(item_data.ItemType.MATERIAL, 1, "材料类型应为1")
	assert_eq(item_data.ItemType.CONSUMABLE, 2, "消耗品类型应为2")
	assert_eq(item_data.ItemType.GIFT, 3, "礼包类型应为3")

func test_quality_colors():
	assert_eq(item_data.QUALITY_COLORS.size(), 5, "应有5种品质颜色")

#endregion

#region 获取物品数据测试

func test_get_item_data():
	var data = item_data.get_item_data("spirit_stone")
	assert_eq(data.get("name", ""), "灵石", "物品名称应正确")

func test_get_item_data_invalid():
	var data = item_data.get_item_data("invalid_item")
	assert_eq(data, {}, "无效物品应返回空字典")

func test_get_item_name():
	var name = item_data.get_item_name("spirit_stone")
	assert_eq(name, "灵石", "物品名称应正确")

func test_get_item_name_invalid():
	var name = item_data.get_item_name("invalid_item")
	assert_eq(name, "未知物品", "无效物品应返回未知物品")

func test_get_item_description():
	var desc = item_data.get_item_description("spirit_stone")
	assert_eq(desc, "修仙者的通用货币", "物品描述应正确")

func test_get_item_description_invalid():
	var desc = item_data.get_item_description("invalid_item")
	assert_eq(desc, "", "无效物品应返回空描述")

func test_get_item_icon():
	var icon = item_data.get_item_icon("spirit_stone")
	assert_eq(icon, "res://icons/spirit_stone.png", "物品图标应正确")

func test_get_item_icon_invalid():
	var icon = item_data.get_item_icon("invalid_item")
	assert_eq(icon, "", "无效物品应返回空图标")

#endregion

#region 物品类型测试

func test_get_item_type():
	var type = item_data.get_item_type("spirit_stone")
	assert_eq(type, ItemData.ItemType.CURRENCY, "灵石应为货币类型")

func test_get_item_type_material():
	var type = item_data.get_item_type("herb")
	assert_eq(type, ItemData.ItemType.MATERIAL, "灵草应为材料类型")

func test_get_item_type_consumable():
	var type = item_data.get_item_type("healing_pill")
	assert_eq(type, ItemData.ItemType.CONSUMABLE, "疗伤丹应为消耗品类型")

func test_get_item_type_gift():
	var type = item_data.get_item_type("gift_box")
	assert_eq(type, ItemData.ItemType.GIFT, "礼包应为礼包类型")

func test_get_item_type_invalid():
	var type = item_data.get_item_type("invalid_item")
	assert_eq(type, ItemData.ItemType.MATERIAL, "无效物品应返回材料类型")

#endregion

#region 堆叠测试

func test_get_max_stack():
	var max_stack = item_data.get_max_stack("spirit_stone")
	assert_eq(max_stack, 999, "灵石最大堆叠应为999")

func test_get_max_stack_small():
	var max_stack = item_data.get_max_stack("healing_pill")
	assert_eq(max_stack, 10, "疗伤丹最大堆叠应为10")

func test_get_max_stack_invalid():
	var max_stack = item_data.get_max_stack("invalid_item")
	assert_eq(max_stack, 1, "无效物品最大堆叠应为1")

func test_can_stack_true():
	var can_stack = item_data.can_stack("spirit_stone")
	assert_true(can_stack, "灵石应可堆叠")

func test_can_stack_false():
	var can_stack = item_data.can_stack("gift_box")
	assert_false(can_stack, "礼包不可堆叠")

func test_can_stack_invalid():
	var can_stack = item_data.can_stack("invalid_item")
	assert_false(can_stack, "无效物品不可堆叠")

#endregion

#region 品质测试

func test_get_item_quality():
	var quality = item_data.get_item_quality("spirit_stone")
	assert_eq(quality, 0, "灵石品质应为0")

func test_get_item_quality_rare():
	var quality = item_data.get_item_quality("healing_pill")
	assert_eq(quality, 2, "疗伤丹品质应为2")

func test_get_item_quality_invalid():
	var quality = item_data.get_item_quality("invalid_item")
	assert_eq(quality, 0, "无效物品品质应为0")

func test_get_item_quality_color():
	var color = item_data.get_item_quality_color(0)
	assert_eq(color, Color("#D3D3D3"), "品质0颜色应正确")

func test_get_item_quality_color_rare():
	var color = item_data.get_item_quality_color(2)
	assert_eq(color, Color("#00BFFF"), "品质2颜色应正确")

func test_get_item_quality_color_invalid():
	var color = item_data.get_item_quality_color(999)
	assert_eq(color, Color("#D3D3D3"), "无效品质应返回默认颜色")

#endregion

#region 使用文本测试

func test_get_use_text_gift():
	var text = item_data.get_use_text("gift_box")
	assert_eq(text, "打开", "礼包使用文本应为打开")

func test_get_use_text_consumable():
	var text = item_data.get_use_text("healing_pill")
	assert_eq(text, "使用", "消耗品使用文本应为使用")

func test_get_use_text_material():
	var text = item_data.get_use_text("herb")
	assert_eq(text, "", "材料使用文本应为空")

func test_get_use_text_invalid():
	var text = item_data.get_use_text("invalid_item")
	assert_eq(text, "", "无效物品使用文本应为空")

#endregion

#region 重要物品测试

func test_is_important_high_quality():
	item_data.item_data["rare_item"] = {"quality": 4, "type": ItemData.ItemType.MATERIAL}
	var is_important = item_data.is_important("rare_item")
	assert_true(is_important, "高品质物品应为重要物品")

func test_is_important_unlock_type():
	item_data.item_data["unlock_item"] = {"quality": 0, "type": ItemData.ItemType.UNLOCK}
	var is_important = item_data.is_important("unlock_item")
	assert_true(is_important, "解锁类型物品应为重要物品")

func test_is_important_normal():
	var is_important = item_data.is_important("herb")
	assert_false(is_important, "普通物品不应为重要物品")

#endregion
