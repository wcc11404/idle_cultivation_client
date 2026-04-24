class_name SettingsModule extends Node

const ACTION_BUTTON_TEMPLATE = preload("res://scripts/ui/common/ActionButtonTemplate.gd")
const UI_ICON_PROVIDER = preload("res://scripts/ui/common/UIIconProvider.gd")
const SETTINGS_SAVE_PATH := "user://settings.cfg"
const DEFAULT_FPS_LIMIT := 60
const DEFAULT_MUSIC_VOLUME := 0.8

signal save_requested
signal load_requested
signal log_message(message: String)

var game_ui: Node = null
var player: Node = null
var api: Node = null

var settings_panel: Control = null
var save_button: Button = null
var logout_button: Button = null
var rank_button: Button = null
var mall_button: Button = null
var guide_button: Button = null
var mailbox_button: Button = null
var redeem_confirm_button: Button = null
var redeem_code_input: LineEdit = null
var fps_30_button: Button = null
var fps_60_button: Button = null
var fps_120_button: Button = null
var fps_144_button: Button = null
var fps_unlimited_button: Button = null
var fps_limit_option_button: OptionButton = null
var music_mute_button: Button = null
var music_volume_slider: HSlider = null
var music_volume_value_label: Label = null
var rank_panel: Control = null
var rank_list: VBoxContainer = null
var back_button: Button = null
var _music_bus_name: String = "Master"
var _is_music_muted: bool = false
var _last_music_linear_volume: float = DEFAULT_MUSIC_VOLUME
var _music_mute_icon_rect: TextureRect = null

func _get_logout_result_text(result: Dictionary, fallback: String = "登出失败") -> String:
	var reason_code = str(result.get("reason_code", ""))
	match reason_code:
		"ACCOUNT_LOGOUT_SUCCEEDED":
			return ""
		_:
			return api.network_manager.get_api_error_text_for_ui(result, fallback)

func initialize(ui: Node, player_node: Node, game_api: Node = null):
	game_ui = ui
	player = player_node
	api = game_api
	_load_local_settings()
	_setup_frame_limit_options()
	_setup_fps_preset_styles()
	_refresh_fps_preset_visual(int(Engine.max_fps))
	_apply_aux_button_templates()
	_sync_audio_controls_from_state()
	_setup_signals()
	_style_rank_back_button()
	if save_button:
		save_button.visible = false

func _ensure_mute_button_icon():
	if not music_mute_button:
		return
	music_mute_button.text = ""
	if _music_mute_icon_rect and is_instance_valid(_music_mute_icon_rect):
		return
	var icon_rect := TextureRect.new()
	icon_rect.name = "MuteIcon"
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.custom_minimum_size = Vector2(24, 24)
	icon_rect.layout_mode = 1
	icon_rect.anchors_preset = 8
	icon_rect.anchor_left = 0.5
	icon_rect.anchor_top = 0.5
	icon_rect.anchor_right = 0.5
	icon_rect.anchor_bottom = 0.5
	icon_rect.offset_left = -12.0
	icon_rect.offset_top = -12.0
	icon_rect.offset_right = 12.0
	icon_rect.offset_bottom = 12.0
	music_mute_button.add_child(icon_rect)
	_music_mute_icon_rect = icon_rect

func _refresh_mute_button_icon():
	_ensure_mute_button_icon()
	if not _music_mute_icon_rect:
		return
	_music_mute_icon_rect.texture = UI_ICON_PROVIDER.load_svg_texture(
		UI_ICON_PROVIDER.ICON_AUDIO_OFF if _is_music_muted else UI_ICON_PROVIDER.ICON_AUDIO_ON
	)

func _style_rank_back_button():
	if not back_button:
		return
	# 与炼丹房返回按钮保持一致
	back_button.custom_minimum_size = Vector2(96, 40)
	ACTION_BUTTON_TEMPLATE.apply_light_neutral(back_button, back_button.custom_minimum_size, 20)

func _setup_signals():
	if logout_button:
		logout_button.pressed.connect(_on_logout_pressed)
	if rank_button:
		rank_button.pressed.connect(_on_rank_pressed)
	if mall_button:
		mall_button.pressed.connect(_on_mall_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if guide_button:
		guide_button.pressed.connect(_on_guide_pressed)
	if mailbox_button:
		mailbox_button.pressed.connect(_on_mailbox_pressed)
	if redeem_confirm_button:
		redeem_confirm_button.pressed.connect(_on_redeem_confirm_pressed)
	if fps_30_button:
		fps_30_button.pressed.connect(func(): _on_fps_preset_pressed(30))
	if fps_60_button:
		fps_60_button.pressed.connect(func(): _on_fps_preset_pressed(60))
	if fps_120_button:
		fps_120_button.pressed.connect(func(): _on_fps_preset_pressed(120))
	if fps_144_button:
		fps_144_button.pressed.connect(func(): _on_fps_preset_pressed(144))
	if fps_unlimited_button:
		fps_unlimited_button.pressed.connect(func(): _on_fps_preset_pressed(0))
	if fps_limit_option_button:
		fps_limit_option_button.item_selected.connect(_on_fps_limit_selected)
	if music_mute_button:
		music_mute_button.pressed.connect(_on_music_mute_toggled)
	if music_volume_slider:
		music_volume_slider.value_changed.connect(_on_music_volume_changed)

func _setup_frame_limit_options():
	if not fps_limit_option_button:
		return
	fps_limit_option_button.clear()
	fps_limit_option_button.add_item("不限帧率", 0)
	fps_limit_option_button.add_item("30 FPS", 30)
	fps_limit_option_button.add_item("60 FPS", 60)
	fps_limit_option_button.add_item("120 FPS", 120)
	fps_limit_option_button.add_item("144 FPS", 144)

	var current_limit := int(Engine.max_fps)
	var target_index := 0
	for i in range(fps_limit_option_button.item_count):
		if fps_limit_option_button.get_item_id(i) == DEFAULT_FPS_LIMIT:
			target_index = i
			break
	for i in range(fps_limit_option_button.item_count):
		if fps_limit_option_button.get_item_id(i) == current_limit:
			target_index = i
			break
	fps_limit_option_button.select(target_index)
	_refresh_fps_preset_visual(current_limit)

func _setup_fps_preset_styles():
	var buttons: Array = [fps_30_button, fps_60_button, fps_120_button, fps_144_button, fps_unlimited_button]
	for btn_variant in buttons:
		var btn: Button = btn_variant
		if not btn:
			continue
		ACTION_BUTTON_TEMPLATE.apply_light_neutral(btn, btn.custom_minimum_size, 16)

func _apply_aux_button_templates():
	if music_mute_button:
		ACTION_BUTTON_TEMPLATE.apply_light_neutral(music_mute_button, music_mute_button.custom_minimum_size, 16)
	if redeem_confirm_button:
		ACTION_BUTTON_TEMPLATE.apply_light_neutral(redeem_confirm_button, redeem_confirm_button.custom_minimum_size, 16)

func _refresh_fps_preset_visual(current_limit: int):
	var mapping := {
		30: fps_30_button,
		60: fps_60_button,
		120: fps_120_button,
		144: fps_144_button,
		0: fps_unlimited_button
	}
	for key in mapping.keys():
		var btn: Button = mapping[key]
		if not btn:
			continue
		var is_selected := int(key) == current_limit
		if is_selected:
			ACTION_BUTTON_TEMPLATE.apply_light_neutral_selected(btn, btn.custom_minimum_size, 16)
		else:
			ACTION_BUTTON_TEMPLATE.apply_light_neutral(btn, btn.custom_minimum_size, 16)

func _find_music_bus_name() -> String:
	if AudioServer.get_bus_index("Music") != -1:
		return "Music"
	return "Master"

func _sync_audio_controls_from_state():
	_music_bus_name = _find_music_bus_name()
	if music_volume_slider:
		music_volume_slider.min_value = 0.0
		music_volume_slider.max_value = 1.0
		music_volume_slider.step = 0.01
		music_volume_slider.set_value_no_signal(_last_music_linear_volume)
	_update_music_volume_label()
	if music_mute_button:
		_refresh_mute_button_icon()
	_apply_music_volume_to_bus()

func _update_music_volume_label():
	if not music_volume_value_label:
		return
	var percent_value := int(round(_last_music_linear_volume * 100.0))
	music_volume_value_label.text = str(percent_value) + "%"

func _apply_music_volume_to_bus():
	var bus_index := AudioServer.get_bus_index(_music_bus_name)
	if bus_index == -1:
		return
	if _is_music_muted:
		AudioServer.set_bus_volume_db(bus_index, -80.0)
		return
	var safe_linear: float = max(_last_music_linear_volume, 0.0001)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(safe_linear))

func _load_local_settings():
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_SAVE_PATH)
	if err != OK:
		Engine.max_fps = DEFAULT_FPS_LIMIT
		_is_music_muted = false
		_last_music_linear_volume = DEFAULT_MUSIC_VOLUME
		# 首次启动即写入默认设置，确保本地缓存与 UI 默认值一致
		_save_local_settings()
		return

	var needs_save := false

	if config.has_section_key("graphics", "fps_limit"):
		Engine.max_fps = int(config.get_value("graphics", "fps_limit", DEFAULT_FPS_LIMIT))
	else:
		Engine.max_fps = DEFAULT_FPS_LIMIT
		needs_save = true

	if config.has_section_key("audio", "music_muted"):
		_is_music_muted = bool(config.get_value("audio", "music_muted", false))
	else:
		_is_music_muted = false
		needs_save = true

	if config.has_section_key("audio", "music_volume"):
		var raw_volume = float(config.get_value("audio", "music_volume", DEFAULT_MUSIC_VOLUME))
		var clamped_volume = clampf(raw_volume, 0.0, 1.0)
		_last_music_linear_volume = clamped_volume
		if not is_equal_approx(raw_volume, clamped_volume):
			needs_save = true
	else:
		_last_music_linear_volume = DEFAULT_MUSIC_VOLUME
		needs_save = true

	if needs_save:
		_save_local_settings()

func _save_local_settings():
	var config := ConfigFile.new()
	config.set_value("graphics", "fps_limit", int(Engine.max_fps))
	config.set_value("audio", "music_muted", _is_music_muted)
	config.set_value("audio", "music_volume", _last_music_linear_volume)
	config.save(SETTINGS_SAVE_PATH)

func _on_fps_limit_selected(index: int):
	if not fps_limit_option_button:
		return
	var selected_fps := int(fps_limit_option_button.get_item_id(index))
	Engine.max_fps = selected_fps
	_refresh_fps_preset_visual(selected_fps)
	_save_local_settings()

func _on_fps_preset_pressed(fps_limit: int):
	Engine.max_fps = fps_limit
	if fps_limit_option_button:
		for i in range(fps_limit_option_button.item_count):
			if fps_limit_option_button.get_item_id(i) == fps_limit:
				fps_limit_option_button.select(i)
				break
	_refresh_fps_preset_visual(fps_limit)
	_save_local_settings()

func _on_music_mute_toggled():
	_is_music_muted = not _is_music_muted
	if music_mute_button:
		_refresh_mute_button_icon()
	_apply_music_volume_to_bus()
	_save_local_settings()

func _on_music_volume_changed(value: float):
	_last_music_linear_volume = clampf(value, 0.0, 1.0)
	if _is_music_muted and _last_music_linear_volume > 0.0:
		_is_music_muted = false
		if music_mute_button:
			_refresh_mute_button_icon()
	_update_music_volume_label()
	_apply_music_volume_to_bus()
	_save_local_settings()

func _on_redeem_confirm_pressed():
	log_message.emit("兑换码功能暂未开放")

func _on_mailbox_pressed():
	log_message.emit("邮箱功能暂未开放")

func _on_mall_pressed():
	log_message.emit("商城功能暂未开放")

func _on_guide_pressed():
	log_message.emit("游戏说明功能暂未开放")

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
			var err_msg = _get_logout_result_text(result, "登出失败")
			if not err_msg.is_empty():
				log_message.emit(err_msg + "，已执行本地退出")

	if api and api.network_manager and api.network_manager.has_method("clear_token"):
		api.network_manager.clear_token()
	get_tree().change_scene_to_file("res://scenes/app/Login.tscn")

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
	spirit_label.text = UIUtils.format_display_number(float(rank_data.get("spirit_energy", 0)))
	spirit_label.size_flags_horizontal = Control.SIZE_EXPAND
	spirit_label.size_flags_stretch_ratio = 15.0
	spirit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spirit_label.add_theme_font_size_override("font_size", 16)
	spirit_label.add_theme_color_override("font_color", Color(0.5, 0.3, 0.8, 1))
	item.add_child(spirit_label)
	return item
