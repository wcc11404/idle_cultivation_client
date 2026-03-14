extends GutTest

## Inventory 单元测试

var inventory: Inventory = null

func before_all():
	await get_tree().process_frame

func before_each():
	inventory = Inventory.new()
	inventory.init_slots()
	
	add_child(inventory)
	await get_tree().process_frame
	
	# 在 _ready 之后重新设置 mock，覆盖可能从 GameManager 获取的 item_data
	var mock_item_data = _create_mock_item_data()
	add_child(mock_item_data)
	# 在 add_child 后重新设置数据，因为 _ready 会覆盖
	mock_item_data.item_data = {
		"spirit_stone": {"name": "灵石", "max_stack": 999},
		"herb": {"name": "灵草", "max_stack": 99},
		"potion": {"name": "丹药", "max_stack": 10},
		"unique_item": {"name": "唯一物品", "max_stack": 1}
	}
	inventory.item_data = mock_item_data

func after_each():
	if inventory:
		inventory.queue_free()

func _create_mock_item_data() -> ItemData:
	var mock = ItemData.new()
	mock.item_data = {
		"spirit_stone": {"name": "灵石", "max_stack": 999},
		"herb": {"name": "灵草", "max_stack": 99},
		"potion": {"name": "丹药", "max_stack": 10},
		"unique_item": {"name": "唯一物品", "max_stack": 1}
	}
	return mock

#region 初始化测试

func test_init_slots():
	assert_eq(inventory.slots.size(), Inventory.MAX_SIZE, "槽位数量应为最大值")
	for i in range(inventory.slots.size()):
		assert_true(inventory.slots[i]["empty"], "初始槽位应为空")

func test_default_capacity():
	assert_eq(inventory.capacity, Inventory.DEFAULT_SIZE, "默认容量应为50")

func test_get_used_slots_empty():
	var used = inventory.get_used_slots()
	assert_eq(used, 0, "空背包已用槽位应为0")

#endregion

#region 添加物品测试

func test_add_item_single():
	var result = inventory.add_item("spirit_stone", 1)
	assert_true(result, "添加单个物品应成功")
	assert_eq(inventory.get_item_count("spirit_stone"), 1, "物品数量应为1")

func test_add_item_multiple():
	var result = inventory.add_item("spirit_stone", 10)
	assert_true(result, "添加多个物品应成功")
	assert_eq(inventory.get_item_count("spirit_stone"), 10, "物品数量应为10")

func test_add_item_zero():
	var result = inventory.add_item("spirit_stone", 0)
	assert_false(result, "添加0个物品应失败")

func test_add_item_negative():
	var result = inventory.add_item("spirit_stone", -5)
	assert_false(result, "添加负数物品应失败")

func test_add_item_invalid_id():
	var result = inventory.add_item("invalid_item", 1)
	assert_false(result, "添加无效物品ID应失败")

func test_add_item_stacking():
	inventory.add_item("spirit_stone", 5)
	inventory.add_item("spirit_stone", 5)
	assert_eq(inventory.get_item_count("spirit_stone"), 10, "相同物品应叠加")

func test_add_item_no_stack():
	inventory.add_item("unique_item", 1)
	assert_eq(inventory.get_item_count("unique_item"), 1, "第一次添加应成功")
	inventory.add_item("unique_item", 1)
	assert_eq(inventory.get_item_count("unique_item"), 2, "不可叠加物品应占用不同槽位")

#endregion

#region 移除物品测试

func test_remove_item_single():
	inventory.add_item("spirit_stone", 10)
	var result = inventory.remove_item("spirit_stone", 1)
	assert_true(result, "移除物品应成功")
	assert_eq(inventory.get_item_count("spirit_stone"), 9, "剩余数量应为9")

func test_remove_item_multiple():
	inventory.add_item("spirit_stone", 10)
	var result = inventory.remove_item("spirit_stone", 5)
	assert_true(result, "移除多个物品应成功")
	assert_eq(inventory.get_item_count("spirit_stone"), 5, "剩余数量应为5")

func test_remove_item_all():
	inventory.add_item("spirit_stone", 10)
	var result = inventory.remove_item("spirit_stone", 10)
	assert_true(result, "移除全部物品应成功")
	assert_eq(inventory.get_item_count("spirit_stone"), 0, "剩余数量应为0")

func test_remove_item_insufficient():
	inventory.add_item("spirit_stone", 5)
	var result = inventory.remove_item("spirit_stone", 10)
	assert_true(result, "移除超过持有量应部分成功")
	assert_eq(inventory.get_item_count("spirit_stone"), 0, "物品应被清空")

func test_remove_item_not_exist():
	var result = inventory.remove_item("spirit_stone", 1)
	assert_false(result, "移除不存在的物品应失败")

func test_remove_item_zero():
	inventory.add_item("spirit_stone", 5)
	var result = inventory.remove_item("spirit_stone", 0)
	assert_false(result, "移除0个物品应失败")

#endregion

#region 检查物品测试

func test_has_item_true():
	inventory.add_item("spirit_stone", 10)
	assert_true(inventory.has_item("spirit_stone", 5), "应有足够物品")
	assert_true(inventory.has_item("spirit_stone", 10), "应正好有物品")

func test_has_item_false():
	inventory.add_item("spirit_stone", 5)
	assert_false(inventory.has_item("spirit_stone", 10), "不应有足够物品")

func test_has_item_zero():
	inventory.add_item("spirit_stone", 5)
	assert_true(inventory.has_item("spirit_stone", 0), "检查0个物品应为true")

func test_has_item_not_exist():
	assert_false(inventory.has_item("spirit_stone", 1), "不存在的物品应为false")

func test_get_item_count_empty():
	assert_eq(inventory.get_item_count("spirit_stone"), 0, "空背包数量应为0")

func test_get_item_count_multiple_slots():
	inventory.add_item("spirit_stone", 50)
	inventory.add_item("spirit_stone", 50)
	assert_eq(inventory.get_item_count("spirit_stone"), 100, "多槽位物品数量应正确")

#endregion

#region 容量测试

func test_get_capacity():
	assert_eq(inventory.get_capacity(), Inventory.DEFAULT_SIZE, "容量应正确")

func test_can_expand_true():
	assert_true(inventory.can_expand(), "初始应可扩展")

func test_can_expand_false():
	inventory.capacity = Inventory.MAX_SIZE
	assert_false(inventory.can_expand(), "最大容量时不可扩展")

func test_expand_capacity():
	var old_capacity = inventory.capacity
	var result = inventory.expand_capacity()
	assert_true(result, "扩展应成功")
	assert_eq(inventory.capacity, old_capacity + Inventory.EXPAND_STEP, "容量应增加")

func test_expand_capacity_to_max():
	inventory.capacity = Inventory.MAX_SIZE - 5
	inventory.expand_capacity()
	assert_lte(inventory.capacity, Inventory.MAX_SIZE, "容量不应超过最大值")

func test_expand_capacity_at_max():
	inventory.capacity = Inventory.MAX_SIZE
	var result = inventory.expand_capacity()
	assert_false(result, "最大容量时扩展应失败")

#endregion

#region 清空和排序测试

func test_clear():
	inventory.add_item("spirit_stone", 10)
	inventory.add_item("herb", 5)
	inventory.clear()
	assert_eq(inventory.get_used_slots(), 0, "清空后应为空")
	assert_eq(inventory.get_item_count("spirit_stone"), 0, "清空后物品应为0")

func test_sort_by_id():
	inventory.add_item("herb", 5)
	inventory.add_item("spirit_stone", 10)
	inventory.sort_by_id()
	
	var items = inventory.get_item_list()
	var first_non_empty = -1
	for item in items:
		if not item.empty:
			first_non_empty = item.index
			break
	
	assert_ne(first_non_empty, -1, "排序后应有物品")

#endregion

#region 存档数据测试

func test_get_save_data():
	inventory.add_item("spirit_stone", 10)
	inventory.add_item("herb", 5)
	
	var data = inventory.get_save_data()
	assert_true(data.has("slots"), "存档应有槽位数据")
	assert_true(data.has("capacity"), "存档应有容量数据")
	assert_eq(data.capacity, Inventory.DEFAULT_SIZE, "存档容量应正确")
	assert_eq(typeof(data.slots), TYPE_DICTIONARY, "槽位数据应为字典格式（稀疏存储）")

func test_get_save_data_sparse():
	inventory.add_item("spirit_stone", 10)
	inventory.add_item("herb", 5)
	
	var data = inventory.get_save_data()
	assert_true(data.slots.has("0"), "第一个槽位应有数据")
	assert_true(data.slots.has("1"), "第二个槽位应有数据")
	assert_eq(data.slots["0"].id, "spirit_stone", "第一个槽位物品ID应正确")
	assert_eq(data.slots["0"].count, 10, "第一个槽位数量应正确")

func test_apply_save_data_sparse():
	var save_data = {
		"capacity": 60,
		"slots": {
			"0": {"id": "spirit_stone", "count": 100},
			"1": {"id": "herb", "count": 50}
		}
	}
	
	inventory.apply_save_data(save_data)
	
	assert_eq(inventory.capacity, 60, "加载后容量应正确")
	assert_eq(inventory.get_item_count("spirit_stone"), 100, "加载后灵石数量应正确")
	assert_eq(inventory.get_item_count("herb"), 50, "加载后灵草数量应正确")

func test_apply_save_data_legacy_array():
	var save_data = {
		"capacity": 60,
		"slots": []
	}
	
	for i in range(Inventory.MAX_SIZE):
		if i == 0:
			save_data.slots.append({"empty": false, "id": "spirit_stone", "count": 100})
		elif i == 1:
			save_data.slots.append({"empty": false, "id": "herb", "count": 50})
		else:
			save_data.slots.append({"empty": true, "id": "", "count": 0})
	
	inventory.apply_save_data(save_data)
	
	assert_eq(inventory.capacity, 60, "加载后容量应正确")
	assert_eq(inventory.get_item_count("spirit_stone"), 100, "加载后灵石数量应正确（兼容旧格式）")
	assert_eq(inventory.get_item_count("herb"), 50, "加载后灵草数量应正确（兼容旧格式）")

func test_apply_save_data_empty_slots():
	var save_data = {
		"capacity": 50,
		"slots": {}
	}
	
	inventory.apply_save_data(save_data)
	
	assert_eq(inventory.get_used_slots(), 0, "空槽位存档加载后应为空背包")

#endregion
