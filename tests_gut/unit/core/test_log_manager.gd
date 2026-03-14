extends GutTest

## LogManager 单元测试

var log_manager: LogManager = null
var test_label: RichTextLabel = null

func before_all():
	await get_tree().process_frame

func before_each():
	log_manager = LogManager.new()
	add_child(log_manager)
	await get_tree().process_frame
	
	test_label = RichTextLabel.new()
	add_child(test_label)
	await get_tree().process_frame

func after_each():
	if log_manager:
		log_manager.queue_free()
	if test_label:
		test_label.queue_free()

#region 初始化测试

func test_initialization():
	assert_not_null(log_manager, "LogManager模块初始化")
	var logs = log_manager.get_logs()
	assert_eq(logs.size(), 0, "初始日志为空")

#endregion

#region 添加日志测试

func test_add_log():
	log_manager.clear_logs()
	
	log_manager.add_system_log("测试日志1")
	log_manager.add_system_log("测试日志2")
	
	var logs = log_manager.get_logs()
	assert_eq(logs.size(), 2, "添加2条日志")

func test_add_log_structure():
	log_manager.clear_logs()
	
	log_manager.add_system_log("第一条")
	log_manager.add_system_log("第二条")
	
	var logs = log_manager.get_logs()
	assert_eq(logs.size(), 2, "获取2条")
	
	var log1 = logs[0]
	assert_true(log1.has("timestamp"), "包含timestamp")
	assert_true(log1.has("raw_message"), "包含raw_message")
	assert_true(log1.has("formatted_message"), "包含formatted_message")

#endregion

#region 时间戳测试

func test_timestamp():
	log_manager.clear_logs()
	
	log_manager.add_system_log("带时间戳的日志")
	
	var logs = log_manager.get_logs()
	assert_eq(logs.size(), 1, "日志添加成功")
	
	var timestamp = logs[0].get("timestamp", "")
	assert_gt(timestamp.length(), 0, "时间戳非空")
	assert_true(timestamp.begins_with("["), "时间戳以[开头")
	assert_true(timestamp.ends_with("]"), "时间戳以]结尾")

#endregion

#region 关键字高亮测试

func test_keyword_highlighting_spirit_stone():
	log_manager.clear_logs()
	
	log_manager.add_system_log("获得灵石x350")
	
	var logs = log_manager.get_logs()
	var log1 = logs[0].get("formatted_message", "")
	assert_true(log1.find("[color=") != -1, "灵石金色高亮")
	assert_true(log1.find("灵石x350") != -1, "灵石内容正确")

func test_keyword_highlighting_spirit_energy():
	log_manager.clear_logs()
	
	log_manager.add_system_log("获得灵气x1000")
	
	var logs = log_manager.get_logs()
	var log2 = logs[0].get("formatted_message", "")
	assert_true(log2.find("[color=") != -1, "灵气青色高亮")

func test_keyword_highlighting_success():
	log_manager.clear_logs()
	
	log_manager.add_system_log("突破成功！")
	
	var logs = log_manager.get_logs()
	var log3 = logs[0].get("formatted_message", "")
	assert_true(log3.find("[color=") != -1, "成功绿色高亮")

func test_keyword_highlighting_failure():
	log_manager.clear_logs()
	
	log_manager.add_system_log("战斗失败...")
	
	var logs = log_manager.get_logs()
	var log4 = logs[0].get("formatted_message", "")
	assert_true(log4.find("[color=") != -1, "失败红色高亮")

func test_keyword_highlighting_offline():
	log_manager.clear_logs()
	
	log_manager.add_system_log("离线总计时间: 1.5 小时")
	
	var logs = log_manager.get_logs()
	var log5 = logs[0].get("formatted_message", "")
	assert_true(log5.find("[color=") != -1, "离线时间黄色高亮")

#endregion

#region 最大日志数量测试

func test_max_log_count():
	log_manager.clear_logs()
	
	for i in range(600):
		log_manager.add_system_log("日志" + str(i))
	
	var logs = log_manager.get_logs()
	assert_eq(logs.size(), 500, "最大保留500条日志")

#endregion

#region 清空日志测试

func test_clear_logs():
	log_manager.clear_logs()
	
	log_manager.add_system_log("测试日志")
	var logs = log_manager.get_logs()
	assert_eq(logs.size(), 1, "添加后有1条")
	
	log_manager.clear_logs()
	logs = log_manager.get_logs()
	assert_eq(logs.size(), 0, "清空后为0条")

#endregion

#region RichTextLabel 测试

func test_set_rich_text_label():
	log_manager.set_rich_text_label(test_label)
	assert_true(test_label.bbcode_enabled, "BBCode已启用")

#endregion
