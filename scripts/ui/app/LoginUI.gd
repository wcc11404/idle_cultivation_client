extends Control

const GAME_SERVER_API_SCRIPT = preload("res://scripts/network/GameServerAPI.gd")
const SERVER_CONFIG_SCRIPT = preload("res://scripts/network/ServerConfig.gd")
const UI_FONT_PROVIDER = preload("res://scripts/ui/common/UIFontProvider.gd")
const CLICK_DEBOUNCE_UTILS := preload("res://scripts/utils/ClickDebounceUtils.gd")
const CLICK_DEBOUNCE_MS := 200

var api: GameServerAPI = null

@onready var username_input = $Panel/VBoxContainer/UsernameInput
@onready var password_input = $Panel/VBoxContainer/PasswordInput
@onready var server_ip_input = $ServerPanel/VBoxContainer/ServerIPInput
@onready var server_ip_confirm_button = $ServerPanel/VBoxContainer/ServerIPHBoxContainer/ServerIPConfirmButton
@onready var login_button = $Panel/VBoxContainer/HBoxContainer/LoginButton
@onready var register_button = $Panel/VBoxContainer/HBoxContainer/RegisterButton
@onready var message_label = $Panel/MessageLabel

func _get_login_result_text(result: Dictionary, fallback: String = "登录失败") -> String:
	var reason_code := str(result.get("reason_code", ""))
	match reason_code:
		"ACCOUNT_LOGIN_USERNAME_NOT_FOUND":
			return "用户名未注册"
		"ACCOUNT_LOGIN_PASSWORD_INCORRECT":
			return "密码错误"
		"ACCOUNT_LOGIN_ACCOUNT_BANNED":
			return "账号已被封禁"
		_:
			return api.network_manager.get_api_error_text_for_ui(result, fallback)

func _get_register_result_text(result: Dictionary, fallback: String = "注册失败") -> String:
	var reason_code := str(result.get("reason_code", ""))
	match reason_code:
		"ACCOUNT_REGISTER_USERNAME_EMPTY":
			return "用户名不能为空"
		"ACCOUNT_REGISTER_USERNAME_LENGTH_INVALID":
			return "用户名长度应在4-20位之间"
		"ACCOUNT_REGISTER_USERNAME_INVALID_CHARACTER":
			return "用户名只能包含英文、数字和下划线"
		"ACCOUNT_REGISTER_PASSWORD_EMPTY":
			return "密码不能为空"
		"ACCOUNT_REGISTER_PASSWORD_LENGTH_INVALID":
			return "密码长度应在6-20位之间"
		"ACCOUNT_REGISTER_PASSWORD_INVALID_CHARACTER":
			return "密码只能包含英文、数字和英文标点符号"
		"ACCOUNT_REGISTER_USERNAME_PASSWORD_SAME":
			return "用户名和密码不能相同"
		"ACCOUNT_REGISTER_USERNAME_EXISTS":
			return "用户名已存在"
		_:
			return api.network_manager.get_api_error_text_for_ui(result, fallback)

func _ready():
	UI_FONT_PROVIDER.apply_to_root(self)
	api = GAME_SERVER_API_SCRIPT.new()
	add_child(api)

	# 防止跨场景或跨测试复用静态防抖状态，进入登录页时重置本页动作键。
	CLICK_DEBOUNCE_UTILS.reset_action("login_ui_login_button")
	CLICK_DEBOUNCE_UTILS.reset_action("login_ui_register_button")
	CLICK_DEBOUNCE_UTILS.reset_action("login_ui_server_confirm_button")
	
	# 连接信号
	login_button.pressed.connect(_on_login_pressed)
	register_button.pressed.connect(_on_register_pressed)
	server_ip_confirm_button.pressed.connect(_on_server_ip_confirm_pressed)
	
	# 设置默认服务器IP
	server_ip_input.text = SERVER_CONFIG_SCRIPT.get_api_base()
	
	# 检查自动登录
	check_auto_login()

func check_auto_login():
	# 尝试加载本地Token
	var has_token = api.network_manager.load_token()
	
	# 加载本地保存的账号信息
	var saved_account = load_account_info()
	if saved_account and saved_account.has("username"):
		username_input.text = saved_account.username
	if saved_account and saved_account.has("password"):
		password_input.text = saved_account.password
	
	if has_token:
		# 验证Token是否有效
		var refresh_result = await api.refresh_token()
		if refresh_result.get("success", false):
			# Token有效，自动填充账号信息
			var refreshed_token := str(refresh_result.get("token", ""))
			if not refreshed_token.is_empty():
				api.network_manager.save_token(refreshed_token)
			# 从 account_info 中获取用户名并填充
			var account_info = refresh_result.get("account_info", {})
			if account_info is Dictionary and account_info.has("username"):
				username_input.text = str(account_info.get("username", ""))
			# 显示提示信息
			show_message("请点击登录按钮继续")
		else:
			# Token无效，显示登录界面
			api.network_manager.clear_token()
			show_message("请重新登录")
	else:
		# 无Token，显示登录界面
		show_message("请登录账号")

func _on_login_pressed():
	if not CLICK_DEBOUNCE_UTILS.should_accept("login_ui_login_button", CLICK_DEBOUNCE_MS):
		return

	var username = username_input.text.strip_edges()
	var password = password_input.text
	
	# 检查输入是否为空
	if username.is_empty() or password.is_empty():
		show_message("用户名和密码不能为空")
		return
	
	show_message("登录中...")
	
	# 无论是否有Token，都使用输入框中的账号和密码进行登录
	var login_result = await api.login(username, password)
	if login_result.get("success", false):
		# 登录成功，保存Token
		var login_token := str(login_result.get("token", ""))
		if not login_token.is_empty():
			api.network_manager.save_token(login_token)
		
		# 保存账号和密码到本地，以便下次自动填充
		save_account_info(username, password)
		
		# 保存账号信息到 GameManager
		var game_manager = get_node_or_null("/root/GameManager")
		if game_manager and login_result.has("account_info"):
			game_manager.set_account_info(login_result.get("account_info", {}))
		
		# 应用游戏数据
		_apply_game_data(login_result.get("data", {}))
		
		# 直接进入游戏界面
		enter_game()
	else:
		# 登录异常，按要求技术性报错仅打印在控制台，业务逻辑失败才反馈 UI
		var err_msg = _get_login_result_text(login_result, "登录失败")
		if not err_msg.is_empty():
			show_message(err_msg)
		else:
			# 这里是技术性报错，不显示详细原因，仅提示常规性异常
			show_message("登录异常，请检查网络或稍后重试")

func _on_register_pressed():
	if not CLICK_DEBOUNCE_UTILS.should_accept("login_ui_register_button", CLICK_DEBOUNCE_MS):
		return

	var username = username_input.text.strip_edges()
	var password = password_input.text
	
	if username.is_empty() or password.is_empty():
		show_message("用户名和密码不能为空")
		return
	
	if username.length() < 4 or username.length() > 20:
		show_message("用户名长度应在4-20位之间")
		return
	
	if password.length() < 6 or password.length() > 20:
		show_message("密码长度应在6-20位之间")
		return
	
	show_message("注册中...")
	
	var register_result = await api.register(username, password)
	if register_result.get("success", false):
		show_message("注册成功，请登录")
	else:
		# 注册异常处理
		var err_msg = _get_register_result_text(register_result, "注册失败")
		if not err_msg.is_empty():
			show_message(err_msg)
		else:
			show_message("注册异常，请稍后重试")

func enter_game():
	# 进入游戏主场景
	get_tree().change_scene_to_file("res://scenes/app/Main.tscn")

func _apply_game_data(data: Dictionary):
	var game_manager = get_node_or_null("/root/GameManager")
	if not game_manager:
		return

	if data.has("account_info"):
		game_manager.apply_save_data(data.account_info)

	var player = game_manager.get_player() if game_manager.has_method("get_player") else null
	var inventory = game_manager.get_inventory() if game_manager.has_method("get_inventory") else null
	var spell_system = game_manager.get_spell_system() if game_manager.has_method("get_spell_system") else null
	var lianli_system = game_manager.get_lianli_system() if game_manager.has_method("get_lianli_system") else null
	var alchemy_system = game_manager.get_alchemy_system() if game_manager.has_method("get_alchemy_system") else null

	if spell_system and data.has("spell_system"):
		spell_system.apply_save_data(data.spell_system)
	if player and data.has("player"):
		player.apply_save_data(data.player)
	if inventory and data.has("inventory"):
		inventory.apply_save_data(data.inventory)
	if lianli_system and data.has("lianli_system"):
		lianli_system.apply_save_data(data.lianli_system)
	if alchemy_system and data.has("alchemy_system"):
		alchemy_system.apply_save_data(data.alchemy_system)

func show_message(message: String):
	message_label.text = message

func save_account_info(username: String, password: String):
	# 保存账号和密码到本地文件（密码使用简单加密）
	var file = FileAccess.open("user://account_info.dat", FileAccess.WRITE)
	if file:
		# 简单的密码加密（实际项目中应使用更安全的加密方式）
		var encrypted_password = _encrypt_password(password)
		var account_data = {
			"username": username,
			"password": encrypted_password,
			"encrypted": true
		}
		file.store_string(JSON.stringify(account_data))
		file.close()

func load_account_info() -> Dictionary:
	# 从本地文件加载账号信息
	if FileAccess.file_exists("user://account_info.dat"):
		var file = FileAccess.open("user://account_info.dat", FileAccess.READ)
		if file:
			var content = file.get_as_text()
			file.close()
			if content:
				var account_data = JSON.parse_string(content)
				if account_data:
					# 如果密码是加密的，进行解密
					if account_data.has("encrypted") and account_data.encrypted:
						if account_data.has("password"):
							account_data.password = _decrypt_password(account_data.password)
					return account_data
	return {}

func _encrypt_password(password: String) -> String:
	# 简单的密码加密（实际项目中应使用更安全的加密方式）
	var encrypted = ""
	for i in range(password.length()):
		var char = password[i]
		var code = char.unicode_at(0)
		encrypted += str(code + 10)
		encrypted += "-"
	return encrypted.rstrip("-")

func _decrypt_password(encrypted: String) -> String:
	# 简单的密码解密
	var decrypted = ""
	var parts = encrypted.split("-")
	for part in parts:
		if part.is_valid_int():
			var code = int(part) - 10
			decrypted += String.chr(code)
	return decrypted

func _on_server_ip_confirm_pressed():
	if not CLICK_DEBOUNCE_UTILS.should_accept("login_ui_server_confirm_button", CLICK_DEBOUNCE_MS):
		return

	# 处理服务器IP确认按钮点击事件
	var server_ip = server_ip_input.text.strip_edges()
	if server_ip.is_empty():
		show_message("服务器IP不能为空")
		return
	
	# 保存服务器IP
	SERVER_CONFIG_SCRIPT.set_api_base(server_ip)
	show_message("服务器IP设置成功")
