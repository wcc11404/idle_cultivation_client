extends Node

const GameServerAPI = preload("res://scripts/network/GameServerAPI.gd")

const AUTO_SAVE_INTERVAL = 300  # 5分钟
const MAX_SAVE_FAILURES = 3

var api: GameServerAPI = null
var save_failure_count: int = 0
var last_save_time: int = 0
var is_autosave_running: bool = false

func _ready():
	api = GameServerAPI.new()
	add_child(api)
	
	# 开始自动保存
	start_auto_save()

func start_auto_save():
	if is_autosave_running:
		return
	
	is_autosave_running = true
	_auto_save_loop()

func _auto_save_loop():
	while is_autosave_running:
		await get_tree().create_timer(AUTO_SAVE_INTERVAL).timeout
		await save_game()

func save_game() -> bool:
	var data = collect_game_data()
	# 重新加载 token，确保使用最新的
	api.network_manager.load_token()
	var result = await api.save_game(data)
	
	if result.success:
		last_save_time = Time.get_unix_time_from_system()
		save_failure_count = 0
		return true
	else:
		# 检查是否是401错误（Token过期）
		var is_401 = false
		if result.has("response_code"):
			var response_code = result.response_code
			if response_code is String:
				is_401 = response_code == "401"
			elif response_code is int:
				is_401 = response_code == 401
		
		if is_401:
			# Token过期，直接强制登出
			_force_logout()
			return false
		else:
			# 其他错误，增加失败计数
			save_failure_count += 1
			
			if save_failure_count >= MAX_SAVE_FAILURES:
				_force_logout()
			return false

func save_partial(fields: Array) -> bool:
	var all_data = collect_game_data()
	var partial_data = {}
	
	for field in fields:
		if all_data.has(field):
			partial_data[field] = all_data[field]
	
	if partial_data.is_empty():
		return false
	
	api.network_manager.load_token()
	var result = await api.save_game(partial_data)
	
	if result.success:
		last_save_time = Time.get_unix_time_from_system()
		save_failure_count = 0
		return true
	else:
		var is_401 = false
		if result.has("response_code"):
			var response_code = result.response_code
			if response_code is String:
				is_401 = response_code == "401"
			elif response_code is int:
				is_401 = response_code == 401
		
		if is_401:
			_force_logout()
			return false
		else:
			save_failure_count += 1
			if save_failure_count >= MAX_SAVE_FAILURES:
				_force_logout()
			return false

func load_game() -> bool:
	var result = await api.load_game()
	if result.success:
		apply_game_data(result.data)
		return true
	return false

func collect_game_data() -> Dictionary:
	var game_manager = get_node_or_null("/root/GameManager")
	if not game_manager:
		print("GameManager not found")
		return {}
	
	var player = game_manager.get_player()
	var inventory = game_manager.get_inventory()
	var spell_system = game_manager.get_spell_system()
	var lianli_system = game_manager.get_lianli_system()
	var alchemy_system = game_manager.get_alchemy_system()
	
	return {
		"account_info": game_manager.get_save_data(),
		"player": player.get_save_data() if player else {},
		"inventory": inventory.get_save_data() if inventory else {},
		"spell_system": spell_system.get_save_data() if spell_system else {},
		"lianli_system": lianli_system.get_save_data() if lianli_system else {},
		"alchemy_system": alchemy_system.get_save_data() if alchemy_system else {},
		"timestamp": Time.get_unix_time_from_system()  # 记录保存时间，目前无实际作用，为未来功能预留
	}

func apply_game_data(data: Dictionary):
	var game_manager = get_node_or_null("/root/GameManager")
	if not game_manager:
		print("GameManager not found")
		return
	
	# 处理账号信息
	if data.has("account_info"):
		game_manager.apply_save_data(data.account_info)
	
	var player = game_manager.get_player()
	var inventory = game_manager.get_inventory()
	var spell_system = game_manager.get_spell_system()
	var lianli_system = game_manager.get_lianli_system()
	var alchemy_system = game_manager.get_alchemy_system()
	
	if player and data.has("player"):
		player.apply_save_data(data.player)
	
	if inventory and data.has("inventory"):
		inventory.apply_save_data(data.inventory)
	
	if spell_system and data.has("spell_system"):
		spell_system.apply_save_data(data.spell_system)
	
	if lianli_system and data.has("lianli_system"):
		lianli_system.apply_save_data(data.lianli_system)
	
	if alchemy_system and data.has("alchemy_system"):
		alchemy_system.apply_save_data(data.alchemy_system)

func _force_logout():
	# 清除本地Token
	api.network_manager.clear_token()
	# 返回登录界面
	var tree = get_tree()
	if tree:
		tree.change_scene_to_file("res://scenes/login/Login.tscn")
	else:
		print("无法获取场景树，无法切换场景")

func stop_auto_save():
	is_autosave_running = false

func on_game_exit():
	# 游戏退出前保存
	# 由于是协程，这里使用await等待保存完成
	# 保存时不进行强制登出，因为游戏正在退出
	var data = collect_game_data()
	# 重新加载 token，确保使用最新的
	api.network_manager.load_token()
	await api.save_game(data)
	stop_auto_save()
