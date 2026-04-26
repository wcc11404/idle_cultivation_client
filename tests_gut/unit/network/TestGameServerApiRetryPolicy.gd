extends GutTest

const GAME_SERVER_API_SCRIPT = preload("res://scripts/network/GameServerAPI.gd")

class MockNetworkManager:
	extends Node

	var calls: Array = []

	func request(method: String, endpoint: String, body: Dictionary = {}, options: Dictionary = {}) -> Dictionary:
		calls.append({
			"method": method,
			"endpoint": endpoint,
			"body": body.duplicate(true),
			"options": options.duplicate(true)
		})
		return {"success": true}

var api: GameServerAPI = null
var mock_network_manager: MockNetworkManager = null

func before_each():
	api = GAME_SERVER_API_SCRIPT.new()
	add_child(api)
	mock_network_manager = MockNetworkManager.new()
	api.add_child(mock_network_manager)
	api.network_manager = mock_network_manager
	await get_tree().process_frame

func after_each():
	if api and is_instance_valid(api):
		if api.get_parent() == self:
			remove_child(api)
		api.free()
		api = null
	mock_network_manager = null
	await get_tree().process_frame

func test_cultivation_report_does_not_enable_retry():
	var result = await api.cultivation_report(5.0)
	assert_true(result.get("success", false), "mock 请求应返回成功")
	assert_eq(mock_network_manager.calls.size(), 1, "应只发起一次请求")

	var options = mock_network_manager.calls[0].get("options", {})
	assert_eq(int(options.get("retry_count", -1)), 0, "修炼上报不应配置重试")
	assert_eq(float(options.get("retry_delay_seconds", -1.0)), 0.0, "修炼上报不应配置重试延迟")
	assert_false(bool(options.get("show_retry_toast", false)), "修炼上报不应提示重试 toast")

func test_alchemy_report_enables_single_retry_with_delay():
	var result = await api.alchemy_report("health_pill", 1)
	assert_true(result.get("success", false), "mock 请求应返回成功")
	assert_eq(mock_network_manager.calls.size(), 1, "应只发起一次请求")

	var options = mock_network_manager.calls[0].get("options", {})
	assert_eq(int(options.get("retry_count", -1)), 1, "炼丹上报应配置单次重试")
	assert_eq(float(options.get("retry_delay_seconds", -1.0)), 1.0, "炼丹上报应配置 1 秒重试延迟")
	assert_true(bool(options.get("show_retry_toast", false)), "炼丹上报应开启重试 toast")

func test_lianli_finish_enables_single_retry_with_delay():
	var result = await api.lianli_finish(1.0)
	assert_true(result.get("success", false), "mock 请求应返回成功")
	assert_eq(mock_network_manager.calls.size(), 1, "应只发起一次请求")

	var options = mock_network_manager.calls[0].get("options", {})
	assert_eq(int(options.get("retry_count", -1)), 1, "历练结算应配置单次重试")
	assert_eq(float(options.get("retry_delay_seconds", -1.0)), 1.0, "历练结算应配置 1 秒重试延迟")
	assert_true(bool(options.get("show_retry_toast", false)), "历练结算应开启重试 toast")

func test_lianli_finish_omits_index_when_full_settle():
	var result = await api.lianli_finish(1.0, null)
	assert_true(result.get("success", false), "mock 请求应返回成功")
	assert_eq(mock_network_manager.calls.size(), 1, "应只发起一次请求")

	var body = mock_network_manager.calls[0].get("body", {})
	assert_true(body.has("speed"), "请求体应包含 speed")
	assert_false(body.has("index"), "完整结算时不应上传 index 字段")

func test_lianli_finish_includes_negative_index_for_cancel_before_action():
	var result = await api.lianli_finish(1.0, -1)
	assert_true(result.get("success", false), "mock 请求应返回成功")
	assert_eq(mock_network_manager.calls.size(), 1, "应只发起一次请求")

	var body = mock_network_manager.calls[0].get("body", {})
	assert_eq(int(body.get("index", 0)), -1, "首帧退出应显式上传 index=-1")

func test_lianli_speed_options_uses_get_endpoint():
	var result = await api.lianli_speed_options()
	assert_true(result.get("success", false), "mock 请求应返回成功")
	assert_eq(mock_network_manager.calls.size(), 1, "应只发起一次请求")

	var call = mock_network_manager.calls[0]
	assert_eq(call.get("method", ""), "GET", "历练倍速选项应走 GET")
	assert_eq(call.get("endpoint", ""), "/game/lianli/speed_options", "历练倍速选项接口路径应正确")
