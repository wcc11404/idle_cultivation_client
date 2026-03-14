extends GutTest

## SaveManager 单元测试

var save_manager: SaveManager = null
var test_save_path: String = "res://user_data/test_save.json"

func before_all():
	await get_tree().process_frame

func before_each():
	save_manager = SaveManager.new()
	save_manager.save_file_path = test_save_path
	
	add_child(save_manager)
	await get_tree().process_frame
	
	_cleanup_test_save()

func after_each():
	_cleanup_test_save()
	if save_manager:
		save_manager.queue_free()

func _cleanup_test_save():
	if FileAccess.file_exists(test_save_path):
		DirAccess.remove_absolute(test_save_path)

#region 初始化测试

func test_initial_state():
	assert_eq(save_manager.current_save_data, {}, "初始存档数据应为空")

func test_save_version():
	assert_eq(save_manager.SAVE_VERSION, "1.3", "存档版本应为1.3")

func test_user_data_dir():
	assert_eq(save_manager.USER_DATA_DIR, "res://user_data", "用户数据目录应正确")

func test_signals_exist():
	assert_true(save_manager.has_signal("save_completed"), "应有save_completed信号")
	assert_true(save_manager.has_signal("load_completed"), "应有load_completed信号")
	assert_true(save_manager.has_signal("load_failed"), "应有load_failed信号")

#endregion

#region 存档路径测试

func test_set_save_path():
	save_manager.set_save_path("test_slot.json")
	assert_eq(save_manager.get_save_path(), "res://user_data/test_slot.json", "存档路径应正确")

func test_get_save_path_empty():
	save_manager.save_file_path = ""
	assert_eq(save_manager.get_save_path(), "", "空路径应返回空")

#endregion

#region 存档存在性测试

func test_has_save_false():
	assert_false(save_manager.has_save(), "无存档时应返回false")

func test_has_save_true():
	var file = FileAccess.open(test_save_path, FileAccess.WRITE)
	file.store_string("{}")
	file.close()
	assert_true(save_manager.has_save(), "有存档时应返回true")

#endregion

#region 删除存档测试

func test_delete_save():
	var file = FileAccess.open(test_save_path, FileAccess.WRITE)
	file.store_string("{}")
	file.close()
	
	var result = save_manager.delete_save()
	assert_true(result, "删除应成功")
	assert_false(save_manager.has_save(), "删除后不应有存档")

func test_delete_save_not_exist():
	var result = save_manager.delete_save()
	assert_false(result, "删除不存在的存档应返回false")

#endregion

#region 存档信息测试

func test_get_save_info_empty():
	var info = save_manager.get_save_info()
	assert_eq(info, {}, "无存档时应返回空字典")

func test_get_save_info_valid():
	var save_data = {
		"timestamp": 1234567890,
		"version": "1.3"
	}
	var file = FileAccess.open(test_save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(save_data))
	file.close()
	
	var info = save_manager.get_save_info()
	assert_eq(info.timestamp, 1234567890, "时间戳应正确")
	assert_eq(info.version, "1.3", "版本应正确")

func test_get_save_info_invalid_json():
	var file = FileAccess.open(test_save_path, FileAccess.WRITE)
	file.store_string("invalid json")
	file.close()
	
	var info = save_manager.get_save_info()
	assert_eq(info, {}, "无效JSON应返回空字典")

#endregion

#region 加载存档测试

func test_load_game_not_exist():
	var result = save_manager.load_game()
	assert_false(result, "加载不存在的存档应失败")

func test_load_game_valid():
	var save_data = {
		"player": {"realm": "筑基期", "realm_level": 5},
		"inventory": {"slots": [], "capacity": 50},
		"timestamp": 1234567890,
		"version": "1.3"
	}
	var file = FileAccess.open(test_save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(save_data))
	file.close()
	
	var result = save_manager.load_game()
	assert_true(result, "加载有效存档应成功")
	assert_eq(save_manager.current_save_data.player.realm, "筑基期", "存档数据应正确")

func test_load_game_invalid_json():
	var file = FileAccess.open(test_save_path, FileAccess.WRITE)
	file.store_string("invalid json")
	file.close()
	
	var result = save_manager.load_game()
	assert_false(result, "加载无效JSON应失败")

func test_load_game_not_dictionary():
	var file = FileAccess.open(test_save_path, FileAccess.WRITE)
	file.store_string("[]")
	file.close()
	
	var result = save_manager.load_game()
	assert_false(result, "加载非字典数据应失败")

#endregion

#region 用户数据目录测试

func test_ensure_user_data_dir():
	save_manager.ensure_user_data_dir()
	assert_true(DirAccess.dir_exists_absolute("res://user_data"), "用户数据目录应存在")

#endregion

#region 当前存档数据测试

func test_current_save_data():
	save_manager.current_save_data = {"test": "data"}
	assert_eq(save_manager.current_save_data.test, "data", "当前存档数据应正确")

#endregion
