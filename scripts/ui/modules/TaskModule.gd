class_name TaskModule
extends Node

const ACTION_BUTTON_TEMPLATE = preload("res://scripts/ui/common/ActionButtonTemplate.gd")
const TAB_BAR_STYLE_TEMPLATE = preload("res://scripts/ui/common/TabBarStyleTemplate.gd")
const DISPLAY_PANEL_TEMPLATE = preload("res://scripts/ui/common/DisplayPanelTemplate.gd")

signal log_message(message: String)
signal back_to_region_requested

var game_ui: Node = null
var api: Node = null

var task_panel: Control = null
var back_button: Button = null
var task_tab_bar: HBoxContainer = null
var daily_tab_button: Button = null
var newbie_tab_button: Button = null
var task_scroll: ScrollContainer = null
var task_list: VBoxContainer = null

var _active_tab: String = "daily"
var _daily_tasks: Array = []
var _newbie_tasks: Array = []


func initialize(ui: Node, game_api: Node) -> void:
	game_ui = ui
	api = game_api
	_setup_ui_styles()
	_setup_signals()


func _setup_ui_styles() -> void:
	if back_button:
		back_button.custom_minimum_size = Vector2(96, 40)
		ACTION_BUTTON_TEMPLATE.apply_light_neutral(back_button, back_button.custom_minimum_size, 20)
	if task_tab_bar:
		TAB_BAR_STYLE_TEMPLATE.apply_to_bar(task_tab_bar, {
			"line_position": "bottom",
			"bar_height": 58,
			"font_size": 20
		})
	if task_scroll:
		task_scroll.horizontal_scroll_mode = 3
		task_scroll.vertical_scroll_mode = 3


func _setup_signals() -> void:
	if back_button and not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)
	if daily_tab_button and not daily_tab_button.pressed.is_connected(_on_daily_tab_pressed):
		daily_tab_button.pressed.connect(_on_daily_tab_pressed)
	if newbie_tab_button and not newbie_tab_button.pressed.is_connected(_on_newbie_tab_pressed):
		newbie_tab_button.pressed.connect(_on_newbie_tab_pressed)


func show_tab() -> void:
	if task_panel:
		task_panel.visible = true
	await _refresh_task_list()


func hide_tab() -> void:
	if task_panel:
		task_panel.visible = false


func _on_back_pressed() -> void:
	back_to_region_requested.emit()


func _on_daily_tab_pressed() -> void:
	_active_tab = "daily"
	_update_tab_state()
	_render_active_tasks()


func _on_newbie_tab_pressed() -> void:
	_active_tab = "newbie"
	_update_tab_state()
	_render_active_tasks()


func _update_tab_state() -> void:
	if daily_tab_button:
		daily_tab_button.disabled = (_active_tab == "daily")
	if newbie_tab_button:
		newbie_tab_button.disabled = (_active_tab == "newbie")


func _refresh_task_list() -> void:
	if not api:
		return
	var result: Dictionary = await api.task_list()
	if not result.get("success", false):
		var msg := _map_reason_text(result, "任务列表加载失败")
		if not msg.is_empty():
			log_message.emit(msg)
		return
	_daily_tasks = result.get("daily_tasks", [])
	_newbie_tasks = result.get("newbie_tasks", [])
	_update_tab_state()
	_render_active_tasks()


func _render_active_tasks() -> void:
	if not task_list:
		return
	for child in task_list.get_children():
		task_list.remove_child(child)
		child.queue_free()

	var source_tasks: Array = _daily_tasks if _active_tab == "daily" else _newbie_tasks
	var tasks_sorted: Array = source_tasks.duplicate()
	tasks_sorted.sort_custom(_sort_tasks)

	for task in tasks_sorted:
		if not (task is Dictionary):
			continue
		task_list.add_child(_build_task_card(task))


func _sort_tasks(a: Dictionary, b: Dictionary) -> bool:
	var a_claimed := bool(a.get("claimed", false))
	var b_claimed := bool(b.get("claimed", false))
	if a_claimed != b_claimed:
		return not a_claimed
	var a_sort := int(a.get("sort_order", 0))
	var b_sort := int(b.get("sort_order", 0))
	if a_sort != b_sort:
		return a_sort < b_sort
	return str(a.get("task_id", "")) < str(b.get("task_id", ""))


func _build_task_card(task: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 140)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.95, 0.90, 0.80, 1.0)
	card_style.border_color = Color(0.76, 0.66, 0.51, 1.0)
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(12)
	card.add_theme_stylebox_override("panel", card_style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	margin.add_child(hbox)

	var left_vbox := VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 6)
	hbox.add_child(left_vbox)

	var header_row := HBoxContainer.new()
	var header_accent := ColorRect.new()
	header_accent.name = "HeaderAccent"
	var header_title := Label.new()
	header_title.name = "HeaderTitle"
	var header_line := HSeparator.new()
	header_line.name = "HeaderLine"
	header_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header_accent)
	header_row.add_child(header_title)
	header_row.add_child(header_line)
	left_vbox.add_child(header_row)
	var header_config := DISPLAY_PANEL_TEMPLATE.build_standard_header_config({
		"title_text": str(task.get("name", "")),
		"title_font_size": 20,
		"row_separation": 8
	})
	DISPLAY_PANEL_TEMPLATE.apply_to_row(header_row, header_config)
	header_title.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1, 1.0))

	var content_margin := MarginContainer.new()
	content_margin.add_theme_constant_override(
		"margin_left",
		DISPLAY_PANEL_TEMPLATE.get_content_left_inset_from_header_config(header_config)
	)
	left_vbox.add_child(content_margin)

	var content_vbox := VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 6)
	content_margin.add_child(content_vbox)

	var desc_label := Label.new()
	desc_label.text = str(task.get("description", ""))
	desc_label.add_theme_color_override("font_color", Color(0.35, 0.33, 0.30, 1.0))
	desc_label.add_theme_font_size_override("font_size", 16)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_vbox.add_child(desc_label)

	var progress_value := int(task.get("progress", 0))
	var target_value: int = max(1, int(task.get("target", 1)))

	var reward_row := HBoxContainer.new()
	reward_row.add_theme_constant_override("separation", 8)
	content_vbox.add_child(reward_row)

	var reward_label := Label.new()
	reward_label.text = "任务奖励: " + _build_reward_text(task.get("rewards", {}))
	reward_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reward_label.add_theme_color_override("font_color", Color(0.35, 0.33, 0.30, 1.0))
	reward_label.add_theme_font_size_override("font_size", 16)
	reward_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	reward_label.clip_text = true
	reward_row.add_child(reward_label)

	var progress_label := Label.new()
	progress_label.text = "%s / %s" % [
		UIUtils.format_display_number_integer(float(progress_value)),
		UIUtils.format_display_number_integer(float(target_value)),
	]
	progress_label.custom_minimum_size = Vector2(86, 0)
	progress_label.add_theme_font_size_override("font_size", 16)
	progress_label.add_theme_color_override("font_color", Color(0.27, 0.24, 0.20, 1.0))
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	reward_row.add_child(progress_label)

	var progress_bar := ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0, 16)
	progress_bar.max_value = float(target_value)
	progress_bar.value = float(min(progress_value, target_value))
	progress_bar.show_percentage = false
	content_vbox.add_child(progress_bar)

	var right_vbox := VBoxContainer.new()
	right_vbox.custom_minimum_size = Vector2(122, 0)
	right_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(right_vbox)

	var claim_button := Button.new()
	var task_id := str(task.get("task_id", ""))
	var claimed := bool(task.get("claimed", false))
	var completed := bool(task.get("completed", false))
	claim_button.text = "已领取" if claimed else ("领取" if completed else "未完成")
	if claimed:
		claim_button.disabled = true
		ACTION_BUTTON_TEMPLATE.apply_light_neutral(claim_button, Vector2(112, 42), 18)
	elif completed:
		claim_button.disabled = false
		ACTION_BUTTON_TEMPLATE.apply_alchemy_green(claim_button, Vector2(112, 42), 18)
		claim_button.pressed.connect(_on_claim_pressed.bind(task_id))
	else:
		claim_button.disabled = true
		ACTION_BUTTON_TEMPLATE.apply_light_neutral(claim_button, Vector2(112, 42), 18)
	right_vbox.add_child(claim_button)

	return card


func _on_claim_pressed(task_id: String) -> void:
	if not api:
		return
	var result: Dictionary = await api.task_claim(task_id)
	var success := bool(result.get("success", false))
	var message := _map_reason_text(result, "领取任务奖励失败")
	if not message.is_empty():
		log_message.emit(message)
	if success:
		await _refresh_task_list()
		if game_ui and game_ui.has_method("refresh_all_player_data"):
			await game_ui.refresh_all_player_data()
			if game_ui.has_method("update_ui"):
				game_ui.update_ui()
		elif game_ui and game_ui.has_method("refresh_inventory_ui"):
			game_ui.refresh_inventory_ui()
			if game_ui.has_method("update_ui"):
				game_ui.update_ui()


func _map_reason_text(result: Dictionary, fallback: String = "") -> String:
	var reason_code := str(result.get("reason_code", ""))
	match reason_code:
		"TASK_CLAIM_SUCCEEDED":
			var rewards: Dictionary = result.get("rewards_granted", {})
			if rewards.is_empty():
				return "任务奖励领取成功"
			var reward_parts: Array = []
			for item_id in rewards.keys():
				var amount: int = int(rewards[item_id])
				var item_name: String = str(item_id)
				if game_ui and game_ui.item_data_ref and game_ui.item_data_ref.has_method("get_item_name"):
					item_name = game_ui.item_data_ref.get_item_name(str(item_id))
				reward_parts.append("%s x%s" % [item_name, UIUtils.format_display_number_integer(float(amount))])
			return "领取成功: " + "、".join(reward_parts)
		"TASK_CLAIM_NOT_COMPLETED":
			return "任务尚未完成"
		"TASK_CLAIM_ALREADY_CLAIMED":
			return "该任务奖励已领取"
		"TASK_CLAIM_TASK_NOT_FOUND":
			return "任务不存在"
		_:
			if api and api.network_manager:
				return api.network_manager.get_api_error_text_for_ui(result, fallback)
			return fallback


func _build_reward_text(rewards: Dictionary) -> String:
	if rewards.is_empty():
		return "无"
	var parts: Array = []
	for item_id in rewards.keys():
		var amount: int = int(rewards[item_id])
		var item_name: String = str(item_id)
		if game_ui and game_ui.item_data_ref and game_ui.item_data_ref.has_method("get_item_name"):
			item_name = game_ui.item_data_ref.get_item_name(str(item_id))
		parts.append("%s x%s" % [item_name, UIUtils.format_display_number_integer(float(amount))])
	return "、".join(parts)
