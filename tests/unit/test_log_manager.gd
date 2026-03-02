extends Node

var helper: Node = null
var test_log_manager: LogManager = null
var test_label: RichTextLabel = null

func _ready():
	helper = load("res://tests/test_helper.gd").new()
	add_child(helper)

func run_tests():
	print("\n=== LogManager 单元测试 ===")
	helper.reset_stats()
	
	test_log_manager = LogManager.new()
	add_child(test_log_manager)
	
	test_label = RichTextLabel.new()
	add_child(test_label)
	
	test_initialization()
	test_add_log()
	test_timestamp()
	test_keyword_highlighting()
	test_max_log_count()
	test_clear_logs()
	test_get_logs()
	test_bbcode_enabled()
	
	return helper.failed_count == 0

func test_initialization():
	helper.assert_true(test_log_manager != null, "LogManager", "模块初始化")
	
	var logs = test_log_manager.get_logs()
	helper.assert_eq(logs.size(), 0, "LogManager", "初始日志为空")

func test_add_log():
	test_log_manager.clear_logs()
	
	test_log_manager.add_system_log("测试日志1")
	test_log_manager.add_system_log("测试日志2")
	
	var logs = test_log_manager.get_logs()
	helper.assert_eq(logs.size(), 2, "LogManager", "添加2条日志")

func test_timestamp():
	test_log_manager.clear_logs()
	
	test_log_manager.add_system_log("带时间戳的日志")
	
	var logs = test_log_manager.get_logs()
	helper.assert_eq(logs.size(), 1, "LogManager", "日志添加成功")
	
	var timestamp = logs[0].get("timestamp", "")
	helper.assert_true(timestamp.length() > 0, "LogManager", "时间戳非空")
	helper.assert_true(timestamp.begins_with("["), "LogManager", "时间戳以[开头")
	helper.assert_true(timestamp.ends_with("]"), "LogManager", "时间戳以]结尾")

func test_keyword_highlighting():
	test_log_manager.clear_logs()
	
	test_log_manager.add_system_log("获得灵石x350")
	test_log_manager.add_system_log("获得灵气x1000")
	test_log_manager.add_system_log("突破成功！")
	test_log_manager.add_system_log("战斗失败...")
	test_log_manager.add_system_log("离线总计时间: 1.5 小时")
	test_log_manager.add_system_log("获得奖励：")
	
	var logs = test_log_manager.get_logs()
	helper.assert_eq(logs.size(), 6, "LogManager", "测试日志数量")
	
	var log1 = logs[0].get("formatted_message", "")
	helper.assert_true(log1.find("[color=") != -1, "LogManager", "灵石金色高亮")
	helper.assert_true(log1.find("灵石x350") != -1, "LogManager", "灵石内容正确")
	
	var log2 = logs[1].get("formatted_message", "")
	helper.assert_true(log2.find("[color=") != -1, "LogManager", "灵气青色高亮")
	
	var log3 = logs[2].get("formatted_message", "")
	helper.assert_true(log3.find("[color=") != -1, "LogManager", "成功绿色高亮")
	
	var log4 = logs[3].get("formatted_message", "")
	helper.assert_true(log4.find("[color=") != -1, "LogManager", "失败红色高亮")
	
	var log5 = logs[4].get("formatted_message", "")
	helper.assert_true(log5.find("[color=") != -1, "LogManager", "离线时间黄色高亮")

func test_max_log_count():
	test_log_manager.clear_logs()
	
	for i in range(600):
		test_log_manager.add_system_log("日志" + str(i))
	
	var logs = test_log_manager.get_logs()
	helper.assert_eq(logs.size(), 500, "LogManager", "最大保留500条日志")

func test_clear_logs():
	test_log_manager.clear_logs()
	
	test_log_manager.add_system_log("测试日志")
	var logs = test_log_manager.get_logs()
	helper.assert_eq(logs.size(), 1, "LogManager", "添加后有1条")
	
	test_log_manager.clear_logs()
	logs = test_log_manager.get_logs()
	helper.assert_eq(logs.size(), 0, "LogManager", "清空后为0条")

func test_get_logs():
	test_log_manager.clear_logs()
	
	test_log_manager.add_system_log("第一条")
	test_log_manager.add_system_log("第二条")
	
	var logs = test_log_manager.get_logs()
	helper.assert_eq(logs.size(), 2, "LogManager", "获取2条")
	
	var log1 = logs[0]
	helper.assert_true(log1.has("timestamp"), "LogManager", "包含timestamp")
	helper.assert_true(log1.has("raw_message"), "LogManager", "包含raw_message")
	helper.assert_true(log1.has("formatted_message"), "LogManager", "包含formatted_message")

func test_bbcode_enabled():
	test_log_manager.set_rich_text_label(test_label)
	helper.assert_true(test_label.bbcode_enabled, "LogManager", "BBCode已启用")
