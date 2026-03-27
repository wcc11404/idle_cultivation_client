class_name SettingsModule extends Node

# 设置模块 - 处理游戏设置、存档等功能

# 信号
signal save_requested
signal load_requested
signal log_message(message: String)  # 日志消息信号

# 引用
var game_ui: Node = null
var player: Node = null
var save_manager: Node = null
var api: Node = null

# UI节点引用
var settings_panel: Control = null
var save_button: Button = null
var logout_button: Button = null
var nickname_input: LineEdit = null
var confirm_nickname_button: Button = null
var rank_button: Button = null
var rank_panel: Control = null
var rank_list: VBoxContainer = null
var back_button: Button = null

func initialize(ui: Node, player_node: Node, save_mgr: Node):
	game_ui = ui
	player = player_node
	save_manager = save_mgr
	
	# 获取API实例 - 使用延迟调用确保所有节点都已初始化
	call_deferred("_get_api_instance")
	
	_setup_signals()

func _get_api_instance():
	# 获取API实例
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		var cloud_save_manager = game_manager.get_save_manager()
		if cloud_save_manager and "api" in cloud_save_manager:
			api = cloud_save_manager.api
			# API实例获取完成

func _setup_signals():
	# 连接按钮信号
	if save_button:
		save_button.pressed.connect(_on_save_pressed)
	if logout_button:
		logout_button.pressed.connect(_on_logout_pressed)
	if confirm_nickname_button:
		confirm_nickname_button.pressed.connect(_on_confirm_nickname_pressed)
	if rank_button:
		rank_button.pressed.connect(_on_rank_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

# 显示设置Tab
func show_tab():
	if settings_panel:
		settings_panel.visible = true
	# 显示主设置面板，隐藏排行榜面板
	if rank_panel:
		rank_panel.visible = false
	if settings_panel and settings_panel.has_node("VBoxContainer"):
		settings_panel.get_node("VBoxContainer").visible = true

# 隐藏设置Tab
func hide_tab():
	if settings_panel:
		settings_panel.visible = false

# 保存按钮按下
func _on_save_pressed() -> bool:
	save_requested.emit()
	
	# 从GameManager获取save_manager
	if not save_manager:
		var game_manager = get_node_or_null("/root/GameManager")
		if game_manager:
			save_manager = game_manager.get_save_manager()
	
	if save_manager:
		var result = await save_manager.save_game()
		if result:
			log_message.emit("存档成功！")
		else:
			log_message.emit("存档失败...")
		return result
	return false

# 登出按钮按下
func _on_logout_pressed():
	# 保存游戏数据
	log_message.emit("正在保存游戏数据...")
	var save_result = await _on_save_pressed()
	
	if save_result:
		log_message.emit("保存成功，正在登出...")
		# 清除Token
		var game_manager = get_node_or_null("/root/GameManager")
		if game_manager:
			var cloud_save_manager = game_manager.get_save_manager()
			if cloud_save_manager and cloud_save_manager.has_method("api"):
				var api = cloud_save_manager.api
				if api and api.has_method("network_manager"):
					var network_manager = api.network_manager
					if network_manager and network_manager.has_method("clear_token"):
						network_manager.clear_token()
						log_message.emit("Token已清除")
		# 退出游戏
		log_message.emit("退出游戏")
		get_tree().quit()
	else:
		log_message.emit("保存失败，无法登出")

# 确认修改昵称按钮按下
func _on_confirm_nickname_pressed():
	if not nickname_input:
		return
	
	var new_nickname = nickname_input.text.strip_edges()
	if new_nickname.is_empty():
		log_message.emit("昵称不能为空")
		return
	
	if new_nickname.length() > 12:
		log_message.emit("昵称长度不能超过12个字符")
		return
	
	# 直接更新玩家数据并保存
	log_message.emit("正在修改昵称...")
	
	# 更新GameManager中的account_info
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		var account_info = game_manager.get_account_info()
		account_info["nickname"] = new_nickname
		game_manager.set_account_info(account_info)
	
	# 触发保存
	var save_result = await _on_save_pressed()
	
	if save_result:
		log_message.emit("昵称修改成功！")
		# 更新UI显示
		if game_ui and game_ui.has_method("update_account_ui"):
			game_ui.update_account_ui()
		# 清空输入框
		nickname_input.text = ""
	else:
		log_message.emit("保存失败，昵称修改未生效")

# 排行榜按钮按下
func _on_rank_pressed():
	if not rank_panel:
		return
	
	# 隐藏主设置面板，显示排行榜面板
	if settings_panel and settings_panel.has_node("VBoxContainer"):
		settings_panel.get_node("VBoxContainer").visible = false
	rank_panel.visible = true
	
	# 加载排行榜数据
	_load_rank_data()

# 返回按钮按下
func _on_back_pressed():
	if not rank_panel:
		return
	
	# 隐藏排行榜面板，显示主设置面板
	rank_panel.visible = false
	if settings_panel and settings_panel.has_node("VBoxContainer"):
		settings_panel.get_node("VBoxContainer").visible = true

# 加载排行榜数据
func _load_rank_data():
	if not rank_list:
		return
	
	# 清空现有列表
	for child in rank_list.get_children():
		child.queue_free()
	
	# 如果api为null，尝试重新获取
	if not api:
		_get_api_instance()
		if not api:
			log_message.emit("API未初始化，请稍后再试")
			return
	
	log_message.emit("正在加载排行榜...")
	var result = await api.get_rank()
	
	if result.success:
		var ranks = result.get("ranks", [])
		if ranks.is_empty():
			log_message.emit("排行榜暂无数据")
			return
		
		# 添加表头
		var header = _create_rank_header()
		rank_list.add_child(header)
		
		# 添加分隔线
		var separator = HSeparator.new()
		separator.custom_minimum_size = Vector2(0, 2)
		rank_list.add_child(separator)
		
		# 显示排行榜数据
		for rank_data in ranks:
			var rank_item = _create_rank_item(rank_data)
			rank_list.add_child(rank_item)
		
		log_message.emit("排行榜加载成功")
	else:
		log_message.emit(result.get("message", "排行榜加载失败"))

# 创建排行榜表头
func _create_rank_header() -> HBoxContainer:
	var header = HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 40)
	
	# 排名表头 - 10%
	var rank_header = Label.new()
	rank_header.text = "排名"
	rank_header.size_flags_horizontal = Control.SIZE_EXPAND
	rank_header.size_flags_stretch_ratio = 10.0
	rank_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_header.add_theme_font_size_override("font_size", 18)
	rank_header.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3, 1))
	header.add_child(rank_header)
	
	# 称号表头 - 20%
	var title_header = Label.new()
	title_header.text = "称号"
	title_header.size_flags_horizontal = Control.SIZE_EXPAND
	title_header.size_flags_stretch_ratio = 20.0
	title_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_header.add_theme_font_size_override("font_size", 18)
	title_header.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3, 1))
	header.add_child(title_header)
	
	# 昵称表头 - 30%
	var nickname_header = Label.new()
	nickname_header.text = "昵称"
	nickname_header.size_flags_horizontal = Control.SIZE_EXPAND
	nickname_header.size_flags_stretch_ratio = 30.0
	nickname_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nickname_header.add_theme_font_size_override("font_size", 18)
	nickname_header.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3, 1))
	header.add_child(nickname_header)
	
	# 境界表头 - 25%
	var realm_header = Label.new()
	realm_header.text = "境界"
	realm_header.size_flags_horizontal = Control.SIZE_EXPAND
	realm_header.size_flags_stretch_ratio = 25.0
	realm_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	realm_header.add_theme_font_size_override("font_size", 18)
	realm_header.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3, 1))
	header.add_child(realm_header)
	
	# 灵气表头 - 15%
	var spirit_header = Label.new()
	spirit_header.text = "灵气"
	spirit_header.size_flags_horizontal = Control.SIZE_EXPAND
	spirit_header.size_flags_stretch_ratio = 15.0
	spirit_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spirit_header.add_theme_font_size_override("font_size", 18)
	spirit_header.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3, 1))
	header.add_child(spirit_header)
	
	return header

# 创建排行榜条目
func _create_rank_item(rank_data: Dictionary) -> HBoxContainer:
	var item = HBoxContainer.new()
	item.custom_minimum_size = Vector2(0, 50)
	
	# 排名 - 10%
	var rank_label = Label.new()
	rank_label.text = str(int(rank_data.get("rank", 0)))
	rank_label.size_flags_horizontal = Control.SIZE_EXPAND
	rank_label.size_flags_stretch_ratio = 10.0
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_label.add_theme_font_size_override("font_size", 20)
	rank_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 1))
	item.add_child(rank_label)
	
	# 称号 - 20%
	var title_label = Label.new()
	var title_id = rank_data.get("title_id", "")
	title_label.text = title_id
	title_label.size_flags_horizontal = Control.SIZE_EXPAND
	title_label.size_flags_stretch_ratio = 20.0
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2, 1))
	item.add_child(title_label)
	
	# 昵称 - 30%
	var nickname_label = Label.new()
	nickname_label.text = rank_data.get("nickname", "未知")
	nickname_label.size_flags_horizontal = Control.SIZE_EXPAND
	nickname_label.size_flags_stretch_ratio = 30.0
	nickname_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nickname_label.add_theme_font_size_override("font_size", 18)
	nickname_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 1))
	item.add_child(nickname_label)
	
	# 境界 - 25%
	var realm_label = Label.new()
	var realm_name = rank_data.get("realm", "未知")
	var level = int(rank_data.get("level", 1))
	var level_text = ""
	match level:
		1:
			level_text = "一层"
		2:
			level_text = "二层"
		3:
			level_text = "三层"
		4:
			level_text = "四层"
		5:
			level_text = "五层"
		6:
			level_text = "六层"
		7:
			level_text = "七层"
		8:
			level_text = "八层"
		9:
			level_text = "九层"
		10:
			level_text = "十层"
		_:
			level_text = "第" + str(level) + "层"
	realm_label.text = realm_name + " " + level_text
	realm_label.size_flags_horizontal = Control.SIZE_EXPAND
	realm_label.size_flags_stretch_ratio = 25.0
	realm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	realm_label.add_theme_font_size_override("font_size", 16)
	realm_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3, 1))
	item.add_child(realm_label)
	
	# 灵气 - 15%
	var spirit_label = Label.new()
	var spirit_energy = int(rank_data.get("spirit_energy", 0))
	spirit_label.text = UIUtils.format_number(spirit_energy)
	spirit_label.size_flags_horizontal = Control.SIZE_EXPAND
	spirit_label.size_flags_stretch_ratio = 15.0
	spirit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spirit_label.add_theme_font_size_override("font_size", 16)
	spirit_label.add_theme_color_override("font_color", Color(0.5, 0.3, 0.8, 1))
	item.add_child(spirit_label)
	
	return item


# 保存游戏
func save_game() -> bool:
	save_requested.emit()
	if save_manager:
		return await save_manager.save_game()
	return false

# 加载游戏
func load_game() -> bool:
	load_requested.emit()
	if save_manager:
		return save_manager.load_game()
	return false