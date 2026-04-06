extends Control

const GameServerAPI = preload("res://scripts/api/GameServerAPI.gd")
const CloudSaveManager = preload("res://scripts/managers/CloudSaveManager.gd")
const ServerConfig = preload("res://scripts/network/ServerConfig.gd")

var api: GameServerAPI = null
var cloud_save: CloudSaveManager = null

@onready var username_input = $Panel/VBoxContainer/UsernameInput
@onready var password_input = $Panel/VBoxContainer/PasswordInput
@onready var server_ip_input = $Panel/VBoxContainer/ServerIPInput
@onready var server_ip_confirm_button = $Panel/VBoxContainer/ServerIPHBoxContainer/ServerIPConfirmButton
@onready var login_button = $Panel/VBoxContainer/HBoxContainer/LoginButton
@onready var register_button = $Panel/VBoxContainer/HBoxContainer/RegisterButton
@onready var message_label = $Panel/MessageLabel

func _ready():
	api = GameServerAPI.new()
	add_child(api)
	
	cloud_save = CloudSaveManager.new()
	add_child(cloud_save)
	
	# 连接信号
	login_button.pressed.connect(_on_login_pressed)
	register_button.pressed.connect(_on_register_pressed)
	server_ip_confirm_button.pressed.connect(_on_server_ip_confirm_pressed)
	
	# 设置默认服务器IP
	server_ip_input.text = ServerConfig.get_api_base()
	
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
		cloud_save.apply_game_data(login_result.get("data", {}))
		
		# 直接进入游戏界面
		enter_game()
	else:
		# 登录异常，按要求技术性报错仅打印在控制台，业务逻辑失败才反馈 UI
		var err_msg = api.network_manager.get_api_error_text_for_ui(login_result, "登录失败")
		if not err_msg.is_empty():
			show_message(err_msg)
		else:
			# 这里是技术性报错，不显示详细原因，仅提示常规性异常
			show_message("登录异常，请检查网络或稍后重试")
			print("[Login Technical Error] " + str(login_result))

func _on_register_pressed():
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
		var err_msg = api.network_manager.get_api_error_text_for_ui(register_result, "注册失败")
		if not err_msg.is_empty():
			show_message(err_msg)
		else:
			show_message("注册异常，请稍后重试")
			print("[Register Technical Error] " + str(register_result))

func load_game_data():
	show_message("加载游戏数据...")
	
	var load_result = await api.load_game()
	if load_result.get("success", false):
		cloud_save.apply_game_data(load_result.get("data", {}))
		enter_game()
	else:
		var err_msg = api.network_manager.get_api_error_text_for_ui(load_result, "加载数据失败")
		if not err_msg.is_empty():
			show_message(err_msg)
		else:
			show_message("同步存档失败，请重新登录")
		api.network_manager.clear_token()

func enter_game():
	# 进入游戏主场景
	get_tree().change_scene_to_file("res://scenes/main/Main.tscn")

func claim_offline_reward():
	# 主动获取离线奖励
	# 服务端自动计算离线时间
	show_message("获取离线奖励中...")
	
	var result = await api.claim_offline_reward()
	if result.get("success", false):
		var offline_reward = result.get("offline_reward", null)
		if offline_reward != null and offline_reward is Dictionary:
			# 成功且有奖励
			show_offline_reward(offline_reward, int(result.get("offline_seconds", 0)))
		else:
			# 成功但无奖励，直接进入游戏
			enter_game()
	else:
		# 获取离线奖励失败，直接进入游戏
		enter_game()

func show_message(message: String):
	message_label.text = message

func show_offline_reward(reward: Dictionary, seconds: int):
	var hours = int(seconds / 3600)
	var minutes = int((seconds % 3600) / 60)
	var time_str = ""
	if hours > 0:
		time_str += str(hours) + "小时"
	if minutes > 0:
		time_str += str(minutes) + "分钟"
	
	var reward_str = "欢迎回来！\n"
	reward_str += "离线时长：" + time_str + "\n"
	if reward:
		if reward.has("spirit_energy"):
			reward_str += "获得灵气：+" + str(reward.spirit_energy) + "\n"
		if reward.has("spirit_stones"):
			reward_str += "获得灵石：+" + str(reward.spirit_stones) + "\n"
	
	show_message(reward_str)
	
	# 延迟进入游戏
	get_tree().create_timer(2.0).timeout.connect(enter_game)

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
	# 处理服务器IP确认按钮点击事件
	var server_ip = server_ip_input.text.strip_edges()
	if server_ip.is_empty():
		show_message("服务器IP不能为空")
		return
	
	# 保存服务器IP
	ServerConfig.set_api_base(server_ip)
	show_message("服务器IP设置成功")
