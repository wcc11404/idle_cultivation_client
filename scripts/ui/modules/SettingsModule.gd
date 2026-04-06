class_name SettingsModule extends Node

signal save_requested
signal load_requested
signal log_message(message: String)

var game_ui: Node = null
var player: Node = null
var api: Node = null

var settings_panel: Control = null
var save_button: Button = null
var logout_button: Button = null
var nickname_input: LineEdit = null
var confirm_nickname_button: Button = null
var rank_button: Button = null
var rank_panel: Control = null
var rank_list: VBoxContainer = null
var back_button: Button = null

func initialize(ui: Node, player_node: Node, game_api: Node = null):
	game_ui = ui
	player = player_node
	api = game_api
	_setup_signals()
	if save_button:
		save_button.visible = false

func _setup_signals():
	if logout_button:
		logout_button.pressed.connect(_on_logout_pressed)
	if confirm_nickname_button:
		confirm_nickname_button.pressed.connect(_on_confirm_nickname_pressed)
	if rank_button:
		rank_button.pressed.connect(_on_rank_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

func show_tab():
	if settings_panel:
		settings_panel.visible = true
	if rank_panel:
		rank_panel.visible = false
	if settings_panel and settings_panel.has_node("VBoxContainer"):
		settings_panel.get_node("VBoxContainer").visible = true

func hide_tab():
	if settings_panel:
		settings_panel.visible = false

func _on_logout_pressed():
	if api:
		var result = await api.logout()
		if not result.get("success", false):
			var err_msg = api.network_manager.get_api_error_text_for_ui(result, "登出失败")
			if not err_msg.is_empty():
				log_message.emit(err_msg + "，已执行本地退出")

	if api and api.network_manager and api.network_manager.has_method("clear_token"):
		api.network_manager.clear_token()
	get_tree().change_scene_to_file("res://scenes/login/Login.tscn")

func _on_confirm_nickname_pressed():
	if not nickname_input:
		return
	if not api:
		log_message.emit("API未初始化")
		return

	var new_nickname = nickname_input.text.strip_edges()
	if new_nickname.is_empty():
		log_message.emit("昵称不能为空")
		return
	if new_nickname.length() > 12:
		log_message.emit("昵称长度不能超过12个字符")
		return

	var result = await api.change_nickname(new_nickname)
	if result.get("success", false):
		log_message.emit(result.get("message", "昵称修改成功"))
		var game_manager = get_node_or_null("/root/GameManager")
		if game_manager:
			var account_info = game_manager.get_account_info()
			account_info["nickname"] = new_nickname
			game_manager.set_account_info(account_info)
		if game_ui and game_ui.has_method("update_account_ui"):
			game_ui.update_account_ui()
		nickname_input.text = ""
	else:
		var err_msg = api.network_manager.get_api_error_text_for_ui(result, "昵称修改失败")
		if not err_msg.is_empty():
			log_message.emit(err_msg)

func _on_rank_pressed():
	if not rank_panel:
		return
	if settings_panel and settings_panel.has_node("VBoxContainer"):
		settings_panel.get_node("VBoxContainer").visible = false
	rank_panel.visible = true
	_load_rank_data()

func _on_back_pressed():
	if not rank_panel:
		return
	rank_panel.visible = false
	if settings_panel and settings_panel.has_node("VBoxContainer"):
		settings_panel.get_node("VBoxContainer").visible = true

func _load_rank_data():
	if not rank_list:
		return
	for child in rank_list.get_children():
		child.queue_free()
	if not api:
		log_message.emit("API未初始化，请稍后再试")
		return

	log_message.emit("正在加载排行榜...")
	var result = await api.get_rank()
	if result.get("success", false):
		var ranks = result.get("ranks", [])
		if ranks.is_empty():
			log_message.emit("排行榜暂无数据")
			return
		var header = _create_rank_header()
		rank_list.add_child(header)
		var separator = HSeparator.new()
		separator.custom_minimum_size = Vector2(0, 2)
		rank_list.add_child(separator)
		for rank_data in ranks:
			var rank_item = _create_rank_item(rank_data)
			rank_list.add_child(rank_item)
		log_message.emit("排行榜加载成功")
	else:
		var err_msg = api.network_manager.get_api_error_text_for_ui(result, "排行榜加载失败")
		if not err_msg.is_empty():
			log_message.emit(err_msg)


func _create_rank_header() -> HBoxContainer:
	var header = HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 40)
	var rank_header = Label.new()
	rank_header.text = "排名"
	rank_header.size_flags_horizontal = Control.SIZE_EXPAND
	rank_header.size_flags_stretch_ratio = 10.0
	rank_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_header.add_theme_font_size_override("font_size", 18)
	rank_header.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3, 1))
	header.add_child(rank_header)
	var title_header = Label.new()
	title_header.text = "称号"
	title_header.size_flags_horizontal = Control.SIZE_EXPAND
	title_header.size_flags_stretch_ratio = 20.0
	title_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_header.add_theme_font_size_override("font_size", 18)
	title_header.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3, 1))
	header.add_child(title_header)
	var nickname_header = Label.new()
	nickname_header.text = "昵称"
	nickname_header.size_flags_horizontal = Control.SIZE_EXPAND
	nickname_header.size_flags_stretch_ratio = 30.0
	nickname_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nickname_header.add_theme_font_size_override("font_size", 18)
	nickname_header.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3, 1))
	header.add_child(nickname_header)
	var realm_header = Label.new()
	realm_header.text = "境界"
	realm_header.size_flags_horizontal = Control.SIZE_EXPAND
	realm_header.size_flags_stretch_ratio = 25.0
	realm_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	realm_header.add_theme_font_size_override("font_size", 18)
	realm_header.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3, 1))
	header.add_child(realm_header)
	var spirit_header = Label.new()
	spirit_header.text = "灵气"
	spirit_header.size_flags_horizontal = Control.SIZE_EXPAND
	spirit_header.size_flags_stretch_ratio = 15.0
	spirit_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spirit_header.add_theme_font_size_override("font_size", 18)
	spirit_header.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3, 1))
	header.add_child(spirit_header)
	return header

func _create_rank_item(rank_data: Dictionary) -> HBoxContainer:
	var item = HBoxContainer.new()
	item.custom_minimum_size = Vector2(0, 50)
	var rank_label = Label.new()
	rank_label.text = str(int(rank_data.get("rank", 0)))
	rank_label.size_flags_horizontal = Control.SIZE_EXPAND
	rank_label.size_flags_stretch_ratio = 10.0
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_label.add_theme_font_size_override("font_size", 20)
	rank_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 1))
	item.add_child(rank_label)
	var title_label = Label.new()
	title_label.text = rank_data.get("title_id", "")
	title_label.size_flags_horizontal = Control.SIZE_EXPAND
	title_label.size_flags_stretch_ratio = 20.0
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2, 1))
	item.add_child(title_label)
	var nickname_label = Label.new()
	nickname_label.text = rank_data.get("nickname", "未知")
	nickname_label.size_flags_horizontal = Control.SIZE_EXPAND
	nickname_label.size_flags_stretch_ratio = 30.0
	nickname_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nickname_label.add_theme_font_size_override("font_size", 18)
	nickname_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 1))
	item.add_child(nickname_label)
	var realm_label = Label.new()
	var realm_name = rank_data.get("realm", "未知")
	var level = int(rank_data.get("level", 1))
	var level_text = "第" + str(level) + "层"
	if level == 10:
		level_text = "十层"
	realm_label.text = realm_name + " " + level_text
	realm_label.size_flags_horizontal = Control.SIZE_EXPAND
	realm_label.size_flags_stretch_ratio = 25.0
	realm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	realm_label.add_theme_font_size_override("font_size", 16)
	realm_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3, 1))
	item.add_child(realm_label)
	var spirit_label = Label.new()
	spirit_label.text = UIUtils.format_number(int(rank_data.get("spirit_energy", 0)))
	spirit_label.size_flags_horizontal = Control.SIZE_EXPAND
	spirit_label.size_flags_stretch_ratio = 15.0
	spirit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spirit_label.add_theme_font_size_override("font_size", 16)
	spirit_label.add_theme_color_override("font_color", Color(0.5, 0.3, 0.8, 1))
	item.add_child(spirit_label)
	return item
