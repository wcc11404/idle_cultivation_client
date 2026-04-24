extends GutTest

const MODULE_HARNESS = preload("res://tests_gut/support/ModuleHarness.gd")
const SERVER_CONFIG_SCRIPT = preload("res://scripts/network/ServerConfig.gd")
const NETWORK_MANAGER_SCRIPT = preload("res://scripts/network/NetworkManager.gd")

class FakeRankApi:
	extends Node

	func get_rank(_server_id: String = "default") -> Dictionary:
		return {"success": true, "ranks": []}

class FakeAuthNetworkManager:
	extends NetworkManager

	var queued_results: Array = []
	var invalid_token_handled: bool = false
	var kicked_out_handled: bool = false

	func request(_method: String, _endpoint: String, _body: Dictionary = {}, _options: Dictionary = {}) -> Dictionary:
		if queued_results.is_empty():
			return {"success": false, "error_code": "NET_REQUEST_FAILED", "response_code": 0}
		var result: Dictionary = queued_results.pop_front()
		var code = str(result.get("error_code", ""))
		if code == "AUTH_TOKEN_INVALID":
			_handle_invalid_token()
		elif code == "AUTH_KICKED_OUT":
			_handle_kicked_out()
		return result

	func _handle_invalid_token():
		invalid_token_handled = true

	func _handle_kicked_out():
		kicked_out_handled = true

class FakeAuthApi:
	extends Node

	var network_manager: FakeAuthNetworkManager = null
	var mode: String = "nickname"

	func change_nickname(_new_nickname: String) -> Dictionary:
		return await network_manager.request("POST", "/auth/change_nickname", {}, {"track_network_failure": true})

	func get_rank(_server_id: String = "default") -> Dictionary:
		return await network_manager.request("GET", "/game/rank", {}, {"track_network_failure": true})

var harness: ModuleHarness = null

func before_each():
	harness = MODULE_HARNESS.new()
	add_child(harness)
	await harness.bootstrap()

func after_each():
	if harness:
		await harness.cleanup()
		harness.free()
		harness = null
	await get_tree().process_frame

func test_change_nickname_invalid_character_uses_client_mapping():
	var game_ui = harness.game_ui
	harness.clear_logs()

	await game_ui._on_profile_nickname_submit_requested("ab" + char(0x3000) + "c")

	assert_eq(harness.last_log(), "昵称包含非法字符", "昵称错误提示应来自客户端 reason_code 映射")

func test_change_nickname_success_updates_ui():
	var game_ui = harness.game_ui
	var new_name = "qa%06d" % [int(Time.get_unix_time_from_system()) % 1000000]
	harness.clear_logs()

	await game_ui._on_profile_nickname_submit_requested(new_name)

	assert_eq(harness.last_log(), "昵称修改成功", "昵称修改成功应输出固定文案")
	assert_eq(harness.get_game_manager().get_account_info().get("nickname", ""), new_name, "成功后应更新客户端账号信息")

func test_rank_success_is_silent_but_populates_list():
	var module = harness.game_ui.settings_module
	harness.clear_logs()

	await module._load_rank_data()

	assert_eq(harness.get_log_messages().size(), 0, "排行榜成功加载时不应写入日志")
	assert_gt(module.rank_list.get_child_count(), 0, "排行榜成功后应渲染列表")

func test_rank_success_empty_shows_no_data_message():
	var module = harness.game_ui.settings_module
	harness.clear_logs()

	var fake_api = FakeRankApi.new()
	module.add_child(fake_api)
	module.api = fake_api

	await module._load_rank_data()
	assert_eq(harness.last_log(), "排行榜暂无数据", "排行榜空数据时应提示暂无数据")
	module.api = harness.client.api

func test_logout_clears_local_token_file():
	var module = harness.game_ui.settings_module
	assert_true(FileAccess.file_exists(SERVER_CONFIG_SCRIPT.TOKEN_FILE), "测试前应已存在本地 token")

	await module._on_logout_pressed()

	assert_false(FileAccess.file_exists(SERVER_CONFIG_SCRIPT.TOKEN_FILE), "登出后应清理本地 token 文件")

func test_change_nickname_auth_invalid_uses_network_chain_and_stays_silent():
	var game_ui = harness.game_ui
	var fake_manager = FakeAuthNetworkManager.new()
	var fake_api = FakeAuthApi.new()
	fake_api.network_manager = fake_manager
	fake_manager.queued_results = [{
		"success": false,
		"error_code": "AUTH_TOKEN_INVALID",
		"response_code": 401,
		"is_http_ok": false
	}]
	game_ui.add_child(fake_manager)
	game_ui.add_child(fake_api)
	game_ui.api = fake_api
	harness.clear_logs()

	await game_ui._on_profile_nickname_submit_requested("valid123")

	assert_true(fake_manager.invalid_token_handled, "昵称请求遇到 token 失效时应走 NetworkManager 处理链")
	assert_eq(harness.get_log_messages().size(), 0, "技术性认证错误不应写入业务日志")
	game_ui.api = harness.client.api

func test_rank_kicked_out_uses_network_chain_and_stays_silent():
	var module = harness.game_ui.settings_module
	var fake_manager = FakeAuthNetworkManager.new()
	var fake_api = FakeAuthApi.new()
	fake_api.network_manager = fake_manager
	fake_manager.queued_results = [{
		"success": false,
		"error_code": "AUTH_KICKED_OUT",
		"response_code": 401,
		"is_http_ok": false
	}]
	module.add_child(fake_manager)
	module.add_child(fake_api)
	module.api = fake_api
	harness.clear_logs()

	await module._load_rank_data()

	assert_true(fake_manager.kicked_out_handled, "排行榜请求遇到顶号时应走 NetworkManager 处理链")
	assert_eq(harness.get_log_messages().size(), 0, "技术性认证错误不应写入业务日志")
	module.api = harness.client.api
