class_name HerbGatherModule
extends Node

const ActionButtonTemplate = preload("res://scripts/ui/common/ActionButtonTemplate.gd")
const SpellThumbnailTemplate = preload("res://scripts/ui/common/SpellThumbnailTemplate.gd")

signal log_message(message: String)
signal back_to_region_requested

var game_ui: Node = null
var player: Node = null
var inventory: Node = null
var item_data: Node = null
var api: Node = null
var spell_system: Node = null

var herb_gather_panel: Control = null
var point_list: VBoxContainer = null
var back_button: Button = null

var _points_config: Dictionary = {}
var _card_refs: Dictionary = {}
var _is_gathering: bool = false
var _current_point_id: String = ""
var _current_interval: float = 0.0
var _report_timer: float = 0.0
var _report_in_flight: bool = false
var _report_time_invalid_prompted: bool = false

func _ready():
	set_process(true)

func initialize(ui: Node, player_node: Node, inventory_node: Node, item_data_node: Node, game_api: Node):
	game_ui = ui
	player = player_node
	inventory = inventory_node
	item_data = item_data_node
	api = game_api
	_setup_back_button_style()
	if back_button and not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)

func _process(delta: float):
	if not _is_gathering or _report_in_flight:
		return
	if _current_interval <= 0.0:
		return
	_report_timer += delta
	_update_progress_visual()
	if _report_timer < _current_interval:
		return
	_report_timer -= _current_interval
	_update_progress_visual()
	_report_in_flight = true
	await _do_report_once()
	_report_in_flight = false

func _setup_back_button_style():
	if not back_button:
		return
	back_button.text = "< 返回"
	back_button.custom_minimum_size = Vector2(96, 40)
	ActionButtonTemplate.apply_light_neutral(back_button, back_button.custom_minimum_size, 20)

func show_tab():
	if herb_gather_panel:
		herb_gather_panel.visible = true
	await _refresh_points()

func hide_tab():
	if herb_gather_panel:
		herb_gather_panel.visible = false

func _on_back_pressed():
	back_to_region_requested.emit()

func _get_item_name(item_id: String) -> String:
	if item_data and item_data.has_method("get_item_name"):
		return item_data.get_item_name(item_id)
	return item_id

func _format_drops_preview(drops: Array) -> String:
	var parts: Array = []
	for drop in drops:
		if not (drop is Dictionary):
			continue
		var item_id = str(drop.get("item_id", ""))
		if item_id.is_empty():
			continue
		var chance = float(drop.get("chance", 0.0)) * 100.0
		parts.append("%s x%d~%d (%.0f%%)" % [
			_get_item_name(item_id),
			int(drop.get("min", 0)),
			int(drop.get("max", 0)),
			chance
		])
	return "、".join(parts)

func _format_seconds_text(value: float) -> String:
	return UIUtils.format_decimal(value, 1) + "秒"

func _format_percent_text(value: float) -> String:
	return UIUtils.format_decimal(value * 100.0, 0) + "%"

func _build_point_info_bbcode(point: Dictionary) -> String:
	var base_interval = float(point.get("base_report_interval_seconds", point.get("report_interval_seconds", 0.0)))
	var effective_interval = float(point.get("report_interval_seconds", 0.0))
	var interval_delta = effective_interval - base_interval
	var interval_sign = "-" if interval_delta < 0 else "+"
	var interval_delta_text = interval_sign + _format_seconds_text(abs(interval_delta))

	var base_success_rate = float(point.get("base_success_rate", point.get("success_rate", 0.0)))
	var effective_success_rate = float(point.get("success_rate", 0.0))
	var success_delta = effective_success_rate - base_success_rate
	var success_sign = "+" if success_delta >= 0 else "-"
	var success_delta_text = success_sign + _format_percent_text(abs(success_delta))

	return "耗时: %s [color=#c24639]（%s）[/color]   成功率: %s [color=#c24639]（%s）[/color]\n掉落: %s" % [
		_format_seconds_text(effective_interval),
		interval_delta_text,
		_format_percent_text(effective_success_rate),
		success_delta_text,
		_format_drops_preview(point.get("drops", []))
	]

func _build_reason_text(result: Dictionary, fallback: String = "") -> String:
	var reason_code = str(result.get("reason_code", ""))
	match reason_code:
		"HERB_START_SUCCEEDED":
			return "开始采集"
		"HERB_START_ALREADY_ACTIVE":
			return "已在采集中"
		"HERB_START_POINT_NOT_FOUND":
			return "采集点不存在"
		"HERB_START_BLOCKED_BY_CULTIVATION":
			return "正在修炼中，无法开始采集"
		"HERB_START_BLOCKED_BY_ALCHEMY":
			return "正在炼丹中，无法开始采集"
		"HERB_START_BLOCKED_BY_LIANLI":
			return "正在历练中，无法开始采集"
		"HERB_REPORT_NOT_ACTIVE":
			return "当前未在采集状态"
		"HERB_REPORT_POINT_NOT_FOUND":
			return "采集点不存在"
		"HERB_REPORT_TIME_INVALID":
			return "采集同步异常，请稍后重试"
		"HERB_STOP_SUCCEEDED":
			return "停止采集"
		"HERB_STOP_NOT_ACTIVE":
			return "当前未在采集状态"
		_:
			if api and api.network_manager:
				return api.network_manager.get_api_error_text_for_ui(result, fallback)
			return fallback

func _drop_map_to_text(drops: Dictionary) -> String:
	if drops.is_empty():
		return ""
	var ids: Array = []
	for key in drops.keys():
		ids.append(str(key))
	ids.sort()
	var parts: Array = []
	for item_id in ids:
		parts.append("%s x%d" % [_get_item_name(item_id), int(drops[item_id])])
	return "、".join(parts)

func _report_log_message(result: Dictionary):
	var drops = result.get("drops_gained", {})
	var success_roll = bool(result.get("success_roll", false))
	if drops is Dictionary and not drops.is_empty():
		log_message.emit("采集获得")
		return
	if success_roll:
		log_message.emit("采集获得")
	else:
		log_message.emit("本轮采集失败")

func _render_cards():
	if not point_list:
		return
	for child in point_list.get_children():
		child.queue_free()
	_card_refs.clear()

	var point_ids: Array = []
	for point_id in _points_config.keys():
		point_ids.append(str(point_id))
	point_ids.sort()

	for point_id in point_ids:
		var point = _points_config.get(point_id, {})
		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 210)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		SpellThumbnailTemplate.apply_to_card(card)

		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 16)
		margin.add_theme_constant_override("margin_top", 14)
		margin.add_theme_constant_override("margin_right", 16)
		margin.add_theme_constant_override("margin_bottom", 14)
		card.add_child(margin)

		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 8)
		margin.add_child(vbox)

		var name_label = Label.new()
		name_label.text = str(point.get("name", point_id))
		name_label.add_theme_font_size_override("font_size", 24)
		name_label.add_theme_color_override("font_color", Color(0.22, 0.2, 0.18, 1.0))
		vbox.add_child(name_label)

		var desc_label = Label.new()
		desc_label.text = str(point.get("description", ""))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.add_theme_font_size_override("font_size", 18)
		desc_label.add_theme_color_override("font_color", Color(0.35, 0.33, 0.3, 1.0))
		vbox.add_child(desc_label)

		var info_label = RichTextLabel.new()
		info_label.bbcode_enabled = true
		info_label.fit_content = true
		info_label.scroll_active = false
		info_label.text = _build_point_info_bbcode(point)
		info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_label.add_theme_font_size_override("normal_font_size", 17)
		info_label.add_theme_color_override("default_color", Color(0.25, 0.23, 0.2, 1.0))
		vbox.add_child(info_label)

		var progress_bar = ProgressBar.new()
		progress_bar.custom_minimum_size = Vector2(0, 18)
		progress_bar.max_value = 100.0
		progress_bar.value = 0.0
		progress_bar.show_percentage = false
		vbox.add_child(progress_bar)

		var actions = HBoxContainer.new()
		actions.alignment = BoxContainer.ALIGNMENT_END
		actions.add_theme_constant_override("separation", 10)
		vbox.add_child(actions)

		var start_button = Button.new()
		start_button.text = "开始采集"
		ActionButtonTemplate.apply_alchemy_green(start_button, Vector2(130, 42), 18)
		start_button.pressed.connect(_on_start_pressed.bind(point_id))
		actions.add_child(start_button)

		var stop_button = Button.new()
		stop_button.text = "停止采集"
		ActionButtonTemplate.apply_breakthrough_red(stop_button, Vector2(130, 42), 18)
		stop_button.pressed.connect(_on_stop_pressed)
		actions.add_child(stop_button)

		point_list.add_child(card)
		_card_refs[point_id] = {
			"start": start_button,
			"stop": stop_button,
			"progress": progress_bar,
		}

	_update_button_states()
	_update_progress_visual()

func _update_button_states():
	for point_id in _card_refs.keys():
		var refs = _card_refs[point_id]
		var start_button: Button = refs.get("start", null)
		var stop_button: Button = refs.get("stop", null)
		if start_button:
			start_button.disabled = _is_gathering and point_id != _current_point_id
		if stop_button:
			stop_button.disabled = (not _is_gathering) or (point_id != _current_point_id)

func _update_progress_visual():
	for point_id in _card_refs.keys():
		var refs = _card_refs[point_id]
		var progress_bar: ProgressBar = refs.get("progress", null)
		if not progress_bar:
			continue
		if _is_gathering and point_id == _current_point_id and _current_interval > 0.0:
			var percent = clamp((_report_timer / _current_interval) * 100.0, 0.0, 100.0)
			progress_bar.value = percent
		else:
			progress_bar.value = 0.0

func _apply_runtime_state(current_state: Dictionary):
	_is_gathering = bool(current_state.get("is_gathering", false))
	_current_point_id = str(current_state.get("current_point_id", ""))
	var current_point = _points_config.get(_current_point_id, {})
	_current_interval = float(current_point.get("report_interval_seconds", 0.0))
	_report_timer = 0.0
	_update_button_states()
	_update_progress_visual()

func _refresh_points():
	if not api:
		return
	var result = await api.herb_points()
	if not result.get("success", false):
		var message = _build_reason_text(result, "采集点加载失败")
		if not message.is_empty():
			log_message.emit(message)
		return
	_points_config = result.get("points_config", {})
	if not (_points_config is Dictionary):
		_points_config = {}
	_render_cards()
	_apply_runtime_state(result.get("current_state", {}))

func _on_start_pressed(point_id: String):
	var result = await api.herb_start(point_id)
	if not result.get("success", false):
		var message = _build_reason_text(result, "开始采集失败")
		if not message.is_empty():
			log_message.emit(message)
		return
	_is_gathering = true
	_current_point_id = point_id
	var point = _points_config.get(point_id, {})
	_current_interval = float(point.get("report_interval_seconds", 0.0))
	_report_timer = 0.0
	_report_time_invalid_prompted = false
	_update_button_states()
	_update_progress_visual()
	var point_name = str(point.get("name", point_id))
	log_message.emit("开始采集：" + point_name)

func _on_stop_pressed():
	var result = await api.herb_stop()
	if not result.get("success", false):
		var message = _build_reason_text(result, "停止采集失败")
		if not message.is_empty():
			log_message.emit(message)
		return
	_is_gathering = false
	_current_point_id = ""
	_current_interval = 0.0
	_report_timer = 0.0
	_update_button_states()
	_update_progress_visual()
	log_message.emit("停止采集")

func _do_report_once():
	var result = await api.herb_report()
	if not result.get("success", false):
		var reason_code = str(result.get("reason_code", ""))
		if reason_code == "HERB_REPORT_TIME_INVALID":
			if not _report_time_invalid_prompted:
				log_message.emit(_build_reason_text(result, "采集上报失败"))
				_report_time_invalid_prompted = true
			return
		var message = _build_reason_text(result, "采集上报失败")
		if not message.is_empty():
			log_message.emit(message)
		if reason_code == "HERB_REPORT_NOT_ACTIVE":
			_is_gathering = false
			_current_point_id = ""
			_current_interval = 0.0
			_report_timer = 0.0
			_update_button_states()
			_update_progress_visual()
		return

	_report_time_invalid_prompted = false
	var drops_gained = result.get("drops_gained", {})
	if drops_gained is Dictionary and inventory and inventory.has_method("add_item"):
		for item_id in drops_gained.keys():
			inventory.add_item(str(item_id), int(drops_gained[item_id]))
		if game_ui and game_ui.has_method("update_ui"):
			game_ui.update_ui()
	_apply_local_spell_use_count("herb_gathering")
	_report_log_message(result)
	_update_progress_visual()

func _apply_local_spell_use_count(spell_id: String):
	if not spell_system or not spell_system.has_method("add_spell_use_count"):
		return
	spell_system.add_spell_use_count(spell_id)
	if game_ui and game_ui.has_method("_on_spell_used"):
		game_ui._on_spell_used(spell_id)
