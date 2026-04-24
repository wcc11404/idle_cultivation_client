extends GutTest

const NETWORK_MANAGER_SCRIPT = preload("res://scripts/network/NetworkManager.gd")

class MockNetworkManager:
	extends NetworkManager

	var queued_results: Array = []
	var invalid_token_handled: bool = false
	var kicked_out_handled: bool = false
	var force_logout_handled: bool = false
	var error_logs: Array = []

	func _request_once(_method: String, _endpoint: String, _body: Dictionary = {}) -> Dictionary:
		if queued_results.is_empty():
			return {
				"success": false,
				"error_code": "NET_REQUEST_FAILED",
				"response_code": 0,
				"is_http_ok": false
			}
		return queued_results.pop_front()

	func _handle_invalid_token():
		invalid_token_handled = true

	func _handle_kicked_out():
		kicked_out_handled = true

	func _force_logout_due_network():
		force_logout_handled = true

	func show_error(message: String):
		error_logs.append(message)

var manager: MockNetworkManager = null

func before_each():
	manager = MockNetworkManager.new()
	add_child(manager)
	await get_tree().process_frame

func after_each():
	if manager and is_instance_valid(manager):
		if manager.get_parent() == self:
			remove_child(manager)
		manager.free()
		manager = null
	await get_tree().process_frame

func test_request_handles_auth_token_invalid():
	manager.queued_results = [{
		"success": false,
		"error_code": "AUTH_TOKEN_INVALID",
		"response_code": 401,
		"is_http_ok": false
	}]

	var result = await manager.request("GET", "/game/data", {}, {"track_network_failure": true})

	assert_false(result.get("success", false), "请求应返回失败")
	assert_true(manager.invalid_token_handled, "token 失效应进入 NetworkManager 统一处理链")
	assert_eq(manager.get_api_error_text_for_ui(result, "fallback"), "", "认证技术错误不应回流到业务 UI 文案")

func test_request_handles_auth_kicked_out():
	manager.queued_results = [{
		"success": false,
		"error_code": "AUTH_KICKED_OUT",
		"response_code": 401,
		"is_http_ok": false
	}]

	var result = await manager.request("GET", "/game/data", {}, {"track_network_failure": true})

	assert_false(result.get("success", false), "请求应返回失败")
	assert_true(manager.kicked_out_handled, "被顶号应进入 NetworkManager 统一处理链")
	assert_eq(manager.get_api_error_text_for_ui(result, "fallback"), "", "认证技术错误不应回流到业务 UI 文案")

func test_network_failure_threshold_forces_logout():
	manager.queued_results = [
		{
			"success": false,
			"error_code": "NET_REQUEST_FAILED",
			"response_code": 0,
			"is_http_ok": false
		},
		{
			"success": false,
			"error_code": "NET_REQUEST_FAILED",
			"response_code": 0,
			"is_http_ok": false
		},
		{
			"success": false,
			"error_code": "NET_REQUEST_FAILED",
			"response_code": 0,
			"is_http_ok": false
		}
	]

	await manager.request("GET", "/game/data", {}, {"track_network_failure": true})
	await manager.request("GET", "/game/data", {}, {"track_network_failure": true})
	await manager.request("GET", "/game/data", {}, {"track_network_failure": true})

	assert_true(manager.force_logout_handled, "连续网络失败达到阈值应触发统一退出处理")

func test_technical_error_signal_is_throttled_for_ui():
	manager._last_technical_error_ui_at = -999999.0
	manager._emit_technical_error_for_ui()
	var first_emit_at = manager._last_technical_error_ui_at
	assert_gt(first_emit_at, -999999.0, "首次触发应刷新节流时间戳")
	manager._emit_technical_error_for_ui()
	assert_eq(manager._last_technical_error_ui_at, first_emit_at, "节流窗口内再次触发不应刷新时间戳")
