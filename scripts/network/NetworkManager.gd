extends Node

class_name NetworkManager

const ServerConfig = preload("res://scripts/network/ServerConfig.gd")

const NETWORK_FAILURE_LOGOUT_THRESHOLD := 3
const TECHNICAL_ERROR_UI_THROTTLE_SECONDS := 2.0

var current_token: String = ""
var consecutive_network_failures: int = 0
var _last_technical_error_ui_at: float = 0.0

signal technical_error_for_ui(message: String)

func _ready():
	load_token()

func save_token(token: String):
	current_token = token
	var file = FileAccess.open(ServerConfig.TOKEN_FILE, FileAccess.WRITE)
	file.store_string(token)
	file.close()

func load_token() -> bool:
	if FileAccess.file_exists(ServerConfig.TOKEN_FILE):
		var file = FileAccess.open(ServerConfig.TOKEN_FILE, FileAccess.READ)
		current_token = file.get_as_text()
		if current_token.is_empty():
			return false
		return true
	return false

func clear_token():
	current_token = ""
	if FileAccess.file_exists(ServerConfig.TOKEN_FILE):
		DirAccess.remove_absolute(ServerConfig.TOKEN_FILE)

func request(method: String, endpoint: String, body: Dictionary = {}, options: Dictionary = {}) -> Dictionary:
	var retry_count: int = int(options.get("retry_count", 0))
	var retry_delay_seconds: float = float(options.get("retry_delay_seconds", 0.0))
	var track_failure: bool = bool(options.get("track_network_failure", false))
	var show_retry_toast: bool = bool(options.get("show_retry_toast", false))
	var attempts: int = retry_count + 1
	var payload: Dictionary = _build_request_body(method, endpoint, body)
	var last_result: Dictionary = {}

	for attempt in range(attempts):
		var result = await _request_once(method, endpoint, payload)
		last_result = result

		if result.get("success", false):
			if track_failure:
				_reset_network_failure_counter()
			return result

		# 记录技术性报错到控制台
		if is_technical_error(result):
			show_error("[Network] " + endpoint + " failed: " + str(result.get("message", "Unknown error")))

		var can_retry := attempt < attempts - 1 and _should_retry(result)
		if can_retry:
			if show_retry_toast:
				show_toast("请求失败，正在重试...")
			if retry_delay_seconds > 0.0:
				await get_tree().create_timer(retry_delay_seconds).timeout
			continue

		if track_failure and is_technical_error(result):
			_track_network_failure_and_maybe_logout()
			_emit_technical_error_for_ui()

		var error_code := str(result.get("error_code", ""))
		if error_code == "AUTH_KICKED_OUT":
			_handle_kicked_out()
		elif error_code == "AUTH_TOKEN_INVALID":
			_handle_invalid_token()

		return result

	return last_result

func _build_request_body(method: String, endpoint: String, body: Dictionary) -> Dictionary:
	if method != "POST":
		return body

	var payload := body.duplicate(true)

	if not payload.has("operation_id"):
		payload["operation_id"] = _generate_operation_id()
	if not payload.has("timestamp"):
		payload["timestamp"] = int(Time.get_unix_time_from_system())

	return payload

func _request_once(method: String, endpoint: String, body: Dictionary = {}) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = ServerConfig.REQUEST_TIMEOUT
	add_child(http)

	var url = ServerConfig.get_api_base() + endpoint
	var headers = ["Content-Type: application/json"]
	if current_token:
		headers.append("Authorization: Bearer " + current_token)

	var method_enum := HTTPClient.METHOD_GET if method == "GET" else HTTPClient.METHOD_POST
	var body_json := ""
	if method == "POST":
		body_json = JSON.stringify(body)

	var err := http.request(url, headers, method_enum, body_json)
	if err != OK:
		http.queue_free()
		return {
			"success": false,
			"error_code": "NET_REQUEST_INIT_FAILED",
			"message": "网络请求初始化失败"
		}

	var response = await http.request_completed
	http.queue_free()
	return parse_response(response)

func parse_response(response: Array) -> Dictionary:
	var request_success = response[0] == HTTPRequest.RESULT_SUCCESS
	var response_code = response[1]
	var body = response[3]

	var status_code = 0
	if response_code is String:
		status_code = int(response_code)
	elif response_code is int:
		status_code = response_code

	var http_success = status_code >= 200 and status_code < 300
	var success = request_success and http_success

	var result = {
		"success": success,
		"response_code": status_code,
		"is_http_ok": http_success
	}

	if request_success and body.size() > 0:
		var body_str = body.get_string_from_utf8()
		var json = JSON.parse_string(body_str)
		if json and json is Dictionary:
			for key in json.keys():
				result[key] = json[key]

			if not success:
				if json.has("detail"):
					result["message"] = str(json["detail"])
				elif json.has("message"):
					result["message"] = str(json["message"])
				else:
					result["message"] = "请求失败"

				if status_code == 401:
					if str(result.get("message", "")) == "KICKED_OUT":
						result["error_code"] = "AUTH_KICKED_OUT"
					else:
						result["error_code"] = "AUTH_TOKEN_INVALID"
		else:
			result["success"] = false
			result["error_code"] = "NET_INVALID_JSON"
			result["message"] = "服务器响应格式错误"
	else:
		result["success"] = false
		result["error_code"] = "NET_REQUEST_FAILED"
		result["message"] = "请检查网络连接"

	return result

func _should_retry(result: Dictionary) -> bool:
	if result.get("success", false):
		return false
	return is_technical_error(result)

func _has_business_feedback(result: Dictionary) -> bool:
	var reason_code := str(result.get("reason_code", ""))
	return not reason_code.is_empty()

func is_technical_error(result: Dictionary) -> bool:
	if result.get("success", false):
		return false
	
	var code := str(result.get("error_code", ""))
	if code.begins_with("NET_"):
		return true

	var response_code = int(result.get("response_code", 0))
	# response_code 为 0 通常意味着网络层面的错误 (如超时、无法连接)
	# >= 500 表示服务器内部错误，也属于技术性错误
	if response_code >= 500:
		return true

	# 如果已经拿到了明确的业务失败原因，则按业务失败处理，
	# 不再继续按 response_code/is_http_ok 兜底成技术性错误。
	if _has_business_feedback(result):
		return false

	if response_code == 0:
		return true
	
	# 如果没有 success 且没有显式的业务错误码，但也属于 HTTP 错误（如 404），
	# 在本项目中也视作技术性错误，除非是 400/403/409 等可能的业务反馈
	if not result.get("is_http_ok", false):
		if response_code != 400 and response_code != 401 and response_code != 403 and response_code != 409:
			return true
			
	return false

func get_api_error_text_for_ui(result: Dictionary, fallback: String = "请求失败") -> String:
	# 如果是技术性报错，不返回给 UI，确保“技术性报错仅打印到控制台”
	if is_technical_error(result):
		return ""
	
	# 如果是认证类错误，由 NetworkManager 统一处理弹窗跳转，此处不重复提示业务错误
	var code := str(result.get("error_code", ""))
	if code.begins_with("AUTH_"):
		return ""

	# 新业务接口由各模块基于 reason_code / reason_data 自行翻译，这里不再承担业务文案映射。
	var reason_code := str(result.get("reason_code", ""))
	if not reason_code.is_empty():
		return fallback

	if not code.is_empty():
		return fallback

	return fallback

func _track_network_failure_and_maybe_logout() -> void:
	consecutive_network_failures += 1
	if consecutive_network_failures >= NETWORK_FAILURE_LOGOUT_THRESHOLD:
		show_error("网络异常次数过多，请重新登录")
		_force_logout_due_network()

func _reset_network_failure_counter() -> void:
	consecutive_network_failures = 0

func _handle_kicked_out():
	clear_token()
	show_error("账号在其他设备登录，请重新登录")
	get_tree().change_scene_to_file("res://scenes/app/Login.tscn")

func _handle_invalid_token():
	clear_token()
	show_error("登录已过期，请重新登录")
	get_tree().change_scene_to_file("res://scenes/app/Login.tscn")

func _force_logout_due_network():
	clear_token()
	get_tree().change_scene_to_file("res://scenes/app/Login.tscn")

func _emit_technical_error_for_ui() -> void:
	var now_sec = Time.get_unix_time_from_system()
	if now_sec - _last_technical_error_ui_at < TECHNICAL_ERROR_UI_THROTTLE_SECONDS:
		return
	_last_technical_error_ui_at = now_sec
	technical_error_for_ui.emit("网络错误，请稍后再重试")

func show_toast(message: String):
	print("[Toast] " + message)

func show_error(message: String):
	# 报错不再直接在UI中通过弹窗显示，而是打印到控制台
	# 只有API正确返回业务失败时，由各模块UI自行决定如何向用户展示
	print("[Error] " + message)
	# 如果以后需要关键性弹窗，可以单独实现 show_critical_dialog

func _generate_operation_id() -> String:
	return str(Time.get_unix_time_from_system()) + "-" + str(Time.get_ticks_usec()) + "-" + str(randi())
