class_name AlchemyModule extends Node

# 炼丹模块 - 处理炼丹房UI显示
const ACTION_LOCK_MANAGER = preload("res://scripts/utils/flow/ActionLockManager.gd")
const ACTION_BUTTON_TEMPLATE = preload("res://scripts/ui/common/ActionButtonTemplate.gd")

# === 信号 ===
signal recipe_selected(recipe_id: String)
signal log_message(message: String)
signal back_to_dongfu_requested

# === 样式常量 ===
const COLOR_BG_LIGHT := Color(0.92, 0.90, 0.87, 1.0)
const COLOR_BG_SELECTED := Color(0.85, 0.82, 0.75, 1.0)
const COLOR_TEXT_DARK := Color(0.25, 0.22, 0.18, 1.0)
const COLOR_TEXT_DARKER := Color(0.15, 0.12, 0.10, 1.0)
const COLOR_TEXT_LIGHT := Color(0.95, 0.95, 0.92, 1.0)
const COLOR_TEXT_RED := Color(0.75, 0.25, 0.25, 1.0)
const COLOR_INDICATOR := Color(0.3, 0.55, 0.3, 1.0)
const COLOR_BUTTON_RED := Color(0.6, 0.35, 0.35, 1.0)
const COLOR_PROGRESS_BG := Color(0.5, 0.47, 0.43, 1.0)
const COLOR_PROGRESS_FILL := Color(0.3, 0.6, 0.3, 1.0)

const FONT_SIZE_TITLE := 24
const FONT_SIZE_NORMAL := 18
const FONT_SIZE_SMALL := 16
const FONT_SIZE_TEXT := 19
const FONT_SIZE_SMALL_TEXT := 17
const ALCHEMY_BACK_BUTTON_MIN_SIZE := Vector2(96, 40)

# === 引用 ===
var game_ui: Node = null
var player: Node = null
var alchemy_system: Node = null
var recipe_data: Node = null
var item_data: Node = null
var inventory: Node = null
var api: Node = null
var spell_system: Node = null

# === UI节点引用 ===
var alchemy_room_panel: Control = null
var recipe_list_container: VBoxContainer = null
var recipe_name_label: Label = null
var success_rate_label: Label = null
var craft_time_label: Label = null
var materials_container: VBoxContainer = null
var craft_button: Button = null
var stop_button: Button = null
var craft_progress_bar: ProgressBar = null
var alchemy_info_label: Label = null
var furnace_info_label: Label = null
var craft_count_label: Label = null
var count_1_button: Button = null
var count_10_button: Button = null
var alchemy_back_button: Button = null
var count_100_button: Button = null
var count_max_button: Button = null
var count_plus_10_button: Button = null
var count_final_max_button: Button = null

# === 状态 ===
var selected_recipe: String = ""
var selected_count: int = 1
var _is_alchemizing: bool = false
var _runtime_recipe_id: String = ""
var _runtime_total_count: int = 0
var _runtime_index: int = 0
var _runtime_success_count: int = 0
var _runtime_fail_count: int = 0
var _runtime_timer: float = 0.0
var _runtime_craft_time: float = 0.0
var _runtime_tick_in_flight: bool = false
var _runtime_pending_cost: Dictionary = {}
var _pending_async_task_count: int = 0
var _report_time_invalid_prompted: bool = false

# === 缓存 ===
var _recipe_cards: Dictionary = {}
var _material_labels: Dictionary = {}
var _cached_recipe_materials: Dictionary = {}
var _material_entry_order: Array = []
var _progress_margin_added: bool = false
var _signals_connected: bool = false
var _ui_style_setup_done: bool = false

const ACTION_COOLDOWN_SECONDS := 0.1
var _action_lock := ACTION_LOCK_MANAGER.new()

func _get_item_name(item_id: String) -> String:
	if item_id == "spirit_energy":
		return "灵气"
	if item_data and item_data.has_method("get_item_name"):
		return item_data.get_item_name(item_id)
	return item_id

func _format_alchemy_items(items: Dictionary) -> String:
	if items.is_empty():
		return ""
	var item_ids: Array = []
	for raw_item_id in items.keys():
		item_ids.append(str(raw_item_id))
	item_ids.sort()
	var parts: Array = []
	for item_id in item_ids:
		parts.append("%s x%d" % [_get_item_name(item_id), int(items[item_id])])
	return "、".join(parts)

func _get_alchemy_result_message(result: Dictionary, fallback: String = "") -> String:
	var reason_code = str(result.get("reason_code", ""))
	var reason_data = result.get("reason_data", {})
	match reason_code:
		"ALCHEMY_START_SUCCEEDED":
			return "开炉炼丹"
		"ALCHEMY_START_ALREADY_ACTIVE":
			return "已在炼丹状态"
		"ALCHEMY_START_BLOCKED_BY_CULTIVATION":
			return "正在修炼中，无法开始炼丹"
		"ALCHEMY_START_BLOCKED_BY_BATTLE":
			return "正在战斗中，无法开始炼丹"
		"ALCHEMY_START_BLOCKED_BY_HERB_GATHERING":
			return "正在采集中，无法开始炼丹"
		"ALCHEMY_REPORT_SUCCEEDED":
			return ""
		"ALCHEMY_REPORT_NOT_ACTIVE":
			return "当前未在炼丹状态"
		"ALCHEMY_REPORT_RECIPE_NOT_FOUND", "ALCHEMY_REPORT_RECIPE_NOT_LEARNED":
			return "丹方不存在或未学会"
		"ALCHEMY_REPORT_TIME_INVALID":
			return "炼丹同步异常，请稍后重试"
		"ALCHEMY_REPORT_INVENTORY_UNAVAILABLE":
			return "储纳系统未初始化"
		"ALCHEMY_REPORT_MATERIALS_INSUFFICIENT":
			var missing_materials = reason_data.get("missing_materials", {})
			if missing_materials is Dictionary and not missing_materials.is_empty():
				return "材料不足，缺少" + _format_alchemy_items(missing_materials)
			return "材料不足"
		"ALCHEMY_REPORT_SPIRIT_INSUFFICIENT":
			return "灵气不足"
		"ALCHEMY_STOP_NOT_ACTIVE":
			return "当前未在炼丹状态"
		"ALCHEMY_STOP_SUCCEEDED":
			return ""
		_:
			return api.network_manager.get_api_error_text_for_ui(result, fallback)

func _build_alchemy_summary_message(success_count: int, fail_count: int) -> String:
	return "收丹停火：成丹%d枚，废丹%d枚" % [success_count, fail_count]

# === 初始化 ===
func _begin_action_lock(action_key: String) -> bool:
	return _action_lock.try_begin(action_key)

func _end_action_lock(action_key: String):
	_action_lock.end(action_key, ACTION_COOLDOWN_SECONDS)

func _ready():
	pass

func initialize(ui: Node, player_node: Node, alchemy_sys: Node, recipe_data_node: Node, item_data_node: Node, game_api: Node = null):
	game_ui = ui
	player = player_node
	alchemy_system = alchemy_sys
	recipe_data = recipe_data_node
	item_data = item_data_node
	inventory = alchemy_system.get("inventory") if alchemy_system else null
	api = game_api
	set_process(true)
	_setup_back_button()

func _process(delta: float):
	if not _is_alchemizing or _runtime_tick_in_flight:
		return
	if _runtime_craft_time <= 0.0:
		return

	_runtime_timer += delta
	
	# 实时更新进度条
	var progress = (_runtime_timer / _runtime_craft_time) * 100.0
	progress = min(progress, 100.0)
	_on_alchemy_crafting_progress(_runtime_index + 1, _runtime_total_count, progress)
	
	if _runtime_timer < _runtime_craft_time:
		return

	_runtime_timer -= _runtime_craft_time
	_runtime_tick_in_flight = true
	await _run_alchemy_tick()
	_runtime_tick_in_flight = false

func _run_alchemy_tick():
	_pending_async_task_count += 1
	if not _is_alchemizing:
		_pending_async_task_count = maxi(0, _pending_async_task_count - 1)
		return
	if _runtime_index >= _runtime_total_count:
		await _finish_alchemy_session(true)
		_pending_async_task_count = maxi(0, _pending_async_task_count - 1)
		return

	var report_result = await api.alchemy_report(_runtime_recipe_id, 1)
	if not report_result.get("success", false):
		_restore_pending_cost()
		var reason_code = str(report_result.get("reason_code", ""))
		if reason_code == "ALCHEMY_REPORT_TIME_INVALID":
			if not _report_time_invalid_prompted:
				var invalid_msg = _get_alchemy_result_message(report_result, "炼丹上报失败")
				if not invalid_msg.is_empty():
					log_message.emit(invalid_msg)
				_report_time_invalid_prompted = true
		else:
			var err_msg = _get_alchemy_result_message(report_result, "炼丹上报失败")
			if not err_msg.is_empty():
				log_message.emit(err_msg)
		await _finish_alchemy_session(false)
		_pending_async_task_count = maxi(0, _pending_async_task_count - 1)
		return

	_runtime_index += 1
	_runtime_success_count += int(report_result.get("success_count", 0))
	_runtime_fail_count += int(report_result.get("fail_count", 0))
	_apply_report_result(report_result)
	_apply_local_spell_use_count("alchemy")
	var report_msg = _get_alchemy_tick_message(report_result)
	if not report_msg.is_empty():
		log_message.emit(report_msg)

	_on_alchemy_crafting_progress(_runtime_index, _runtime_total_count, 100.0 * float(_runtime_index) / float(max(1, _runtime_total_count)))
	_on_alchemy_single_craft_completed(int(report_result.get("success_count", 0)) > 0, recipe_data.get_recipe_name(_runtime_recipe_id) if recipe_data else "")

	if _runtime_index >= _runtime_total_count:
		await _finish_alchemy_session(true)
		_pending_async_task_count = maxi(0, _pending_async_task_count - 1)
		return

	if not _apply_single_pre_deduct(_runtime_recipe_id):
		log_message.emit("灵材或灵气不足，无法继续炼丹")
		await _finish_alchemy_session(false)
	_pending_async_task_count = maxi(0, _pending_async_task_count - 1)

func _apply_local_spell_use_count(spell_id: String):
	if not spell_system or not spell_system.has_method("add_spell_use_count"):
		return
	spell_system.add_spell_use_count(spell_id)
	if game_ui and game_ui.has_method("_on_spell_used"):
		game_ui._on_spell_used(spell_id)

func _apply_report_result(report_result: Dictionary):
	var returned_materials = report_result.get("returned_materials", {})
	if returned_materials is Dictionary and not returned_materials.is_empty():
		_add_items_silently(returned_materials)

	if inventory and report_result.has("products"):
		for item_id in report_result.products.keys():
			var count = int(report_result.products[item_id])
			if count > 0:
				inventory.add_item(item_id, count)

	_runtime_pending_cost.clear()
	_update_materials_display()
	if game_ui and game_ui.has_method("update_ui"):
		game_ui.update_ui()

func _can_start_batch(recipe_id: String, count: int) -> bool:
	if not recipe_data or not inventory or not player:
		return false

	var materials = recipe_data.get_recipe_materials(recipe_id)
	for material_id in materials.keys():
		var need = int(materials[material_id]) * count
		if inventory.get_item_count(material_id) < need:
			return false

	var spirit_need = int(recipe_data.get_recipe_spirit_energy(recipe_id)) * count
	if player.spirit_energy < spirit_need:
		return false

	return true

func _apply_single_pre_deduct(recipe_id: String) -> bool:
	if not recipe_data or not inventory or not player:
		return false

	var pending_cost: Dictionary = {}
	var materials = recipe_data.get_recipe_materials(recipe_id)
	for material_id in materials.keys():
		var need = int(materials[material_id])
		if inventory.get_item_count(material_id) < need:
			return false
		pending_cost[material_id] = need

	var spirit_need = int(recipe_data.get_recipe_spirit_energy(recipe_id))
	if player.spirit_energy < spirit_need:
		return false
	if spirit_need > 0:
		pending_cost["spirit_energy"] = spirit_need

	for material_id in materials.keys():
		inventory.remove_item(material_id, int(materials[material_id]))
	if spirit_need > 0:
		player.consume_spirit(spirit_need)

	_runtime_pending_cost = pending_cost
	_update_materials_display()
	if game_ui and game_ui.has_method("update_ui"):
		game_ui.update_ui()
	return true

func _restore_pending_cost() -> Dictionary:
	var restored_resources: Dictionary = {}
	if not inventory or not player:
		return restored_resources
	if _runtime_pending_cost.is_empty():
		return restored_resources

	for key in _runtime_pending_cost.keys():
		var amount = int(_runtime_pending_cost.get(key, 0))
		if amount <= 0:
			continue
		if key == "spirit_energy":
			player.add_spirit(amount)
		else:
			_add_item_silently(key, amount)
		restored_resources[key] = amount

	_runtime_pending_cost.clear()
	_update_materials_display()
	if game_ui and game_ui.has_method("update_ui"):
		game_ui.update_ui()
	return restored_resources

func _get_alchemy_tick_message(report_result: Dictionary) -> String:
	if int(report_result.get("success_count", 0)) > 0:
		return ""
	var returned_materials = report_result.get("returned_materials", {})
	if returned_materials is Dictionary and not returned_materials.is_empty():
		return "炼制失败，返还材料" + _format_alchemy_items(returned_materials)
	return "炼制失败"

func _add_items_silently(items: Dictionary):
	for item_id in items.keys():
		_add_item_silently(str(item_id), int(items[item_id]))

func _add_item_silently(item_id: String, count: int):
	if count <= 0 or not inventory:
		return
	if game_ui and game_ui.has_method("begin_silent_item_added_logs"):
		game_ui.begin_silent_item_added_logs()
	inventory.add_item(item_id, count)
	if game_ui and game_ui.has_method("end_silent_item_added_logs"):
		game_ui.end_silent_item_added_logs()

func setup_styles():
	_setup_ui_static_style()
	_setup_signals()

func _setup_signals():
	if craft_button:
		craft_button.pressed.connect(_on_craft_pressed)
		craft_button.disabled = false
	else:
		push_warning("AlchemyModule: craft_button is null")
	
	if stop_button:
		stop_button.pressed.connect(_on_stop_pressed)
		stop_button.disabled = true
	else:
		push_warning("AlchemyModule: stop_button is null")

# === 样式设置 ===
func _setup_ui_static_style():
	if _ui_style_setup_done:
		return
	if not alchemy_room_panel:
		return
	_setup_craft_panel_static_style()
	_ui_style_setup_done = true

func _setup_craft_panel_static_style():
	_ensure_count_button_texts()
	_style_recipe_name_label()
	_style_info_labels()
	_style_materials_section()
	_style_progress_section()
	_style_count_buttons_static()
	_style_craft_button()

func _ensure_count_button_texts():
	if count_1_button:
		count_1_button.text = "min"
	if count_10_button:
		count_10_button.text = "-10"
	if count_100_button:
		count_100_button.text = "-1"
	if count_max_button:
		count_max_button.text = "+1"
	if count_plus_10_button:
		count_plus_10_button.text = "+10"
	if count_final_max_button:
		count_final_max_button.text = "max"

func _style_recipe_name_label():
	if not recipe_name_label:
		return
	recipe_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	recipe_name_label.add_theme_font_size_override("font_size", FONT_SIZE_TITLE)
	recipe_name_label.add_theme_color_override("font_color", COLOR_TEXT_DARKER)
	recipe_name_label.custom_minimum_size = Vector2(0, 40)

func _style_info_labels():
	for label in [success_rate_label, craft_time_label]:
		if label:
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.add_theme_font_size_override("font_size", FONT_SIZE_TEXT)
			label.add_theme_color_override("font_color", Color(0.3, 0.28, 0.25, 1.0))

func _style_materials_section():
	if not materials_container:
		return
	
	var margin = MarginContainer.new()
	margin.name = "MaterialsMargin"
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	
	var parent = materials_container.get_parent()
	if parent and not parent.get_node_or_null("MaterialsMargin"):
		var idx = materials_container.get_index()
		parent.remove_child(materials_container)
		margin.add_child(materials_container)
		parent.add_child(margin)
		parent.move_child(margin, idx)
	
	parent = materials_container.get_parent()
	if parent and parent.name == "MaterialsMargin":
		parent = parent.get_parent()
	if not parent:
		return
	
	for child in parent.get_children():
		if child is Label and child.name == "MaterialsLabel":
			child.text = "◇ 材料需求 ◇"
			child.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			child.add_theme_font_size_override("font_size", FONT_SIZE_TEXT)
			child.add_theme_color_override("font_color", COLOR_TEXT_DARK)
		elif child is HSeparator:
			var sep_style = StyleBoxLine.new()
			sep_style.color = Color(0.5, 0.47, 0.42, 1.0)
			sep_style.thickness = 2
			sep_style.grow_begin = -8
			sep_style.grow_end = -8
			child.add_theme_stylebox_override("separator", sep_style)

func _style_progress_section():
	if craft_count_label:
		craft_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		craft_count_label.add_theme_font_size_override("font_size", FONT_SIZE_TEXT)
		craft_count_label.add_theme_color_override("font_color", Color(0.3, 0.28, 0.25, 1.0))
		craft_count_label.custom_minimum_size = Vector2(0, 42)
	
	_style_progress_bar()

func _style_progress_bar():
	if not craft_progress_bar:
		return
	
	craft_progress_bar.custom_minimum_size = Vector2(0, 28)
	craft_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	craft_progress_bar.max_value = 100.0
	craft_progress_bar.min_value = 0.0
	craft_progress_bar.value = 0.0
	craft_progress_bar.show_percentage = false
	
	_add_progress_bar_margin()
	_apply_progress_bar_styles()

func _add_progress_bar_margin():
	if _progress_margin_added:
		return
	
	var parent = craft_progress_bar.get_parent()
	if not parent:
		return
	
	var margin_container = MarginContainer.new()
	margin_container.name = "ProgressMargin"
	margin_container.add_theme_constant_override("margin_left", 24)
	margin_container.add_theme_constant_override("margin_right", 24)
	margin_container.add_theme_constant_override("margin_top", 8)
	margin_container.add_theme_constant_override("margin_bottom", 8)
	
	var idx = craft_progress_bar.get_index()
	parent.remove_child(craft_progress_bar)
	margin_container.add_child(craft_progress_bar)
	parent.add_child(margin_container)
	parent.move_child(margin_container, idx)
	_progress_margin_added = true

func _apply_progress_bar_styles():
	var style_bg = StyleBoxFlat.new()
	style_bg.bg_color = COLOR_PROGRESS_BG
	style_bg.border_color = Color(0.4, 0.37, 0.33, 1.0)
	style_bg.set_border_width_all(1)
	style_bg.set_corner_radius_all(6)
	style_bg.content_margin_left = 2
	style_bg.content_margin_right = 2
	style_bg.content_margin_top = 2
	style_bg.content_margin_bottom = 2
	craft_progress_bar.add_theme_stylebox_override("background", style_bg)
	
	var style_fill = StyleBoxFlat.new()
	style_fill.bg_color = COLOR_PROGRESS_FILL
	style_fill.set_corner_radius_all(4)
	craft_progress_bar.add_theme_stylebox_override("fill", style_fill)

func _style_count_buttons_static():
	# 只做一次静态外观初始化
	var all_buttons = [
		count_1_button, count_10_button, count_100_button,
		count_max_button, count_plus_10_button, count_final_max_button
	]
	for btn in all_buttons:
		if btn:
			_apply_count_button_style(btn, false)

func _update_count_button_styles():
	var disable_all = _is_alchemizing
	var button_configs = [
		{btn = count_1_button, disabled = disable_all}, # min
		{btn = count_10_button, disabled = disable_all}, # -10
		{btn = count_100_button, disabled = disable_all}, # -1
		{btn = count_max_button, disabled = disable_all}, # +1
		{btn = count_plus_10_button, disabled = disable_all}, # +10
		{btn = count_final_max_button, disabled = disable_all}, # max
	]
	
	for config in button_configs:
		var btn = config.btn
		if not btn:
			continue
		_apply_count_button_style(btn, false)
		btn.disabled = bool(config.disabled)

func _apply_count_button_style(btn: Button, _is_selected: bool):
	btn.custom_minimum_size = Vector2(54, 40)
	ACTION_BUTTON_TEMPLATE.apply_spell_view_brown(btn, btn.custom_minimum_size, FONT_SIZE_NORMAL)

func _style_craft_button():
	if not craft_button:
		return
	
	craft_button.text = "开始炼制"
	craft_button.custom_minimum_size = Vector2(160, 56)
	ACTION_BUTTON_TEMPLATE.apply_alchemy_green(craft_button, craft_button.custom_minimum_size, FONT_SIZE_TITLE)
	
	_style_stop_button()

func _style_stop_button():
	if not stop_button:
		return
	
	stop_button.text = "停止炼制"
	stop_button.custom_minimum_size = Vector2(160, 56)
	ACTION_BUTTON_TEMPLATE.apply_breakthrough_red(stop_button, stop_button.custom_minimum_size, FONT_SIZE_TITLE)

func _clear_container_children(container: Node):
	for child in container.get_children():
		container.remove_child(child)
		child.free()

# === 返回按钮 ===
func _setup_back_button():
	if not alchemy_room_panel:
		return
	
	if alchemy_back_button:
		alchemy_back_button.custom_minimum_size = ALCHEMY_BACK_BUTTON_MIN_SIZE
		ACTION_BUTTON_TEMPLATE.apply_light_neutral(alchemy_back_button, alchemy_back_button.custom_minimum_size, FONT_SIZE_NORMAL)
		return
	
	var title_bar = alchemy_room_panel.get_node_or_null("VBoxContainer/TitleBar")
	if title_bar:
		return
	
	var vbox = alchemy_room_panel.get_node_or_null("VBoxContainer")
	if not vbox:
		return
	
	title_bar = HBoxContainer.new()
	title_bar.name = "TitleBar"
	title_bar.custom_minimum_size = Vector2(0, 40)
	
	var back_button = Button.new()
	back_button.text = "< 返回"
	back_button.custom_minimum_size = ALCHEMY_BACK_BUTTON_MIN_SIZE
	back_button.pressed.connect(_on_back_button_pressed)
	ACTION_BUTTON_TEMPLATE.apply_light_neutral(back_button, back_button.custom_minimum_size, FONT_SIZE_NORMAL)
	title_bar.add_child(back_button)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(spacer)
	
	vbox.add_child(title_bar)
	vbox.move_child(title_bar, 0)

func _on_back_button_pressed():
	back_to_dongfu_requested.emit()

# === 显示/隐藏 ===
func show_alchemy_room():
	if alchemy_room_panel:
		alchemy_room_panel.visible = true
		_render_alchemy_ui(true)
		call_deferred("_refresh_recipe_config_from_server")

func hide_alchemy_room():
	if alchemy_room_panel:
		alchemy_room_panel.visible = false

func refresh_ui():
	_render_alchemy_ui(true)

func _refresh_recipe_config_from_server():
	if not api:
		return
	var result = await api.alchemy_recipes()
	if not result.get("success", false):
		var err_msg = api.network_manager.get_api_error_text_for_ui(result, "丹方同步失败")
		if not err_msg.is_empty():
			log_message.emit(err_msg)
		return

	if recipe_data and recipe_data.has_method("apply_remote_config"):
		var remote_recipes = result.get("recipes_config", {})
		if remote_recipes is Dictionary and not remote_recipes.is_empty():
			recipe_data.apply_remote_config({"recipes": remote_recipes})

	if alchemy_system and result.has("learned_recipes") and result["learned_recipes"] is Array:
		alchemy_system.apply_save_data({
			"equipped_furnace_id": str(alchemy_system.equipped_furnace_id),
			"learned_recipes": result["learned_recipes"]
		})

	_render_alchemy_ui(true)

func _render_alchemy_ui(rebuild_recipe_list: bool = false):
	if rebuild_recipe_list:
		_update_recipe_list()
	else:
		_update_recipe_selection()
	_update_alchemy_info()
	if selected_recipe:
		_update_craft_panel()
		if craft_button and not _is_alchemizing:
			craft_button.disabled = false
	else:
		_clear_craft_panel()
	_refresh_dynamic_ui_state()
	_update_count_button_styles()

func _refresh_dynamic_ui_state():
	if craft_button:
		craft_button.disabled = _is_alchemizing or selected_recipe.is_empty()
	if stop_button:
		stop_button.disabled = not _is_alchemizing

# === 丹方列表 ===
func _update_recipe_list():
	if not recipe_list_container or not player or _is_alchemizing:
		return

	var learned = alchemy_system.get_learned_recipes() if alchemy_system else []
	if learned.is_empty():
		_clear_container_children(recipe_list_container)
		_recipe_cards.clear()
		selected_recipe = ""
		_ensure_empty_recipe_tip()
		return
	
	var sorted_recipes = _sort_recipes(learned)
	_sync_recipe_cards(sorted_recipes)
	_update_recipe_selection()
	
	if not selected_recipe or not _recipe_cards.has(selected_recipe):
		selected_recipe = ""
	if selected_recipe.is_empty() and sorted_recipes.size() > 0:
		_select_recipe(sorted_recipes[0])

func _ensure_empty_recipe_tip():
	var label = recipe_list_container.get_node_or_null("EmptyRecipeLabel")
	if label:
		return
	label = Label.new()
	label.name = "EmptyRecipeLabel"
	label.text = "暂无学会的丹方"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 1))
	recipe_list_container.add_child(label)

func _sync_recipe_cards(sorted_recipes: Array):
	var new_set := {}
	for recipe_id_variant in sorted_recipes:
		var recipe_id = str(recipe_id_variant)
		new_set[recipe_id] = true
	
	# 删除已失效卡片
	var stale_ids: Array = []
	for existing_id_variant in _recipe_cards.keys():
		var existing_id = str(existing_id_variant)
		if not new_set.has(existing_id):
			stale_ids.append(existing_id)
	for stale_id_variant in stale_ids:
		var stale_id = str(stale_id_variant)
		var stale_card = _recipe_cards.get(stale_id, null)
		if is_instance_valid(stale_card):
			stale_card.queue_free()
		_recipe_cards.erase(stale_id)
	
	# 删除空态提示
	var empty_label = recipe_list_container.get_node_or_null("EmptyRecipeLabel")
	if empty_label:
		empty_label.queue_free()
	
	# 新增/更新并重排
	for index in range(sorted_recipes.size()):
		var recipe_id = str(sorted_recipes[index])
		var recipe_name = recipe_data.get_recipe_name(recipe_id)
		var card: Control = _recipe_cards.get(recipe_id, null)
		if not is_instance_valid(card):
			card = _create_recipe_card(recipe_id, recipe_name)
			_recipe_cards[recipe_id] = card
			recipe_list_container.add_child(card)
		else:
			_update_recipe_card_name(card, recipe_name)
		
		if card.get_parent() == recipe_list_container and card.get_index() != index:
			recipe_list_container.move_child(card, index)
	
func _update_recipe_card_name(card: Control, recipe_name: String):
	if not is_instance_valid(card):
		return
	var name_label = card.find_child("RecipeNameLabel", true, false)
	if name_label and name_label is Label:
		(name_label as Label).text = recipe_name

func _create_recipe_card(recipe_id: String, recipe_name: String) -> Control:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 44)
	
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_BG_LIGHT
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)
	
	var hbox = HBoxContainer.new()
	card.add_child(hbox)
	
	var indicator = ColorRect.new()
	indicator.name = "SelectedIndicator"
	indicator.custom_minimum_size = Vector2(4, 24)
	indicator.color = Color(0.3, 0.5, 0.3, 0.0)
	hbox.add_child(indicator)
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(4, 0)
	hbox.add_child(spacer)
	
	var name_label = Label.new()
	name_label.name = "RecipeNameLabel"
	name_label.text = recipe_name
	name_label.add_theme_color_override("font_color", COLOR_TEXT_DARK)
	name_label.add_theme_font_size_override("font_size", FONT_SIZE_SMALL_TEXT)
	hbox.add_child(name_label)
	
	var button = Button.new()
	button.name = "ClickButton"
	button.modulate = Color(1, 1, 1, 0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.pressed.connect(func(): _on_recipe_card_clicked(recipe_id))
	card.add_child(button)
	
	card.set_meta("recipe_id", recipe_id)
	return card

func _on_recipe_card_clicked(recipe_id: String):
	if _is_alchemizing:
		return
	selected_recipe = recipe_id
	recipe_selected.emit(recipe_id)
	_update_recipe_selection()
	_update_craft_panel()

func _update_recipe_selection():
	for recipe_id in _recipe_cards:
		var card = _recipe_cards[recipe_id]
		if is_instance_valid(card):
			_apply_card_selection_style(card, recipe_id == selected_recipe)

func _apply_card_selection_style(card: Control, is_selected: bool):
	var style: StyleBoxFlat = card.get_theme_stylebox("panel")
	if not style:
		style = StyleBoxFlat.new()
		card.add_theme_stylebox_override("panel", style)
	
	var indicator = card.find_child("SelectedIndicator", true, false)
	var name_label = card.find_child("RecipeNameLabel", true, false)
	
	if is_selected:
		style.bg_color = COLOR_BG_SELECTED
		if indicator:
			indicator.color = COLOR_INDICATOR
		if name_label:
			name_label.add_theme_color_override("font_color", COLOR_TEXT_DARKER)
	else:
		style.bg_color = COLOR_BG_LIGHT
		if indicator:
			indicator.color = Color(0.3, 0.5, 0.3, 0.0)
		if name_label:
			name_label.add_theme_color_override("font_color", COLOR_TEXT_DARK)

func _sort_recipes(recipes: Array) -> Array:
	var breakthrough_keywords = ["foundation", "golden_core", "nascent_soul", "spirit_separation", 
		"void_refining", "body_integration", "mahayana", "tribulation"]
	
	var result = recipes.duplicate()
	result.sort_custom(func(a, b):
		var a_is_breakthrough = breakthrough_keywords.any(func(k): return a.contains(k))
		var b_is_breakthrough = breakthrough_keywords.any(func(k): return b.contains(k))
		
		if a_is_breakthrough != b_is_breakthrough:
			return a_is_breakthrough
		return a < b
	)
	return result

func _select_recipe(recipe_id: String):
	if _is_alchemizing:
		return
	selected_recipe = recipe_id
	recipe_selected.emit(recipe_id)
	_update_recipe_selection()
	_update_craft_panel()

# === 炼制面板 ===
func _update_craft_panel():
	if not selected_recipe or not recipe_data or not alchemy_system:
		_clear_craft_panel()
		return
	
	if recipe_name_label:
		recipe_name_label.text = "【 %s 】" % recipe_data.get_recipe_name(selected_recipe)
	
	var success_rate = alchemy_system.calculate_success_rate(selected_recipe)
	var craft_time = alchemy_system.calculate_craft_time(selected_recipe)
	
	if success_rate_label:
		success_rate_label.text = "成功率 %d%%" % success_rate
	if craft_time_label:
		craft_time_label.text = "耗时 %.1f秒" % craft_time
	
	_update_materials_display()
	_update_craft_count_label()
	_update_count_button_styles()
	
	if craft_button and not _is_alchemizing:
		craft_button.text = "开始炼制"
		craft_button.disabled = false

func _clear_craft_panel():
	if recipe_name_label:
		recipe_name_label.text = "请选择丹方"
	if success_rate_label:
		success_rate_label.text = "成功率 -"
	if craft_time_label:
		craft_time_label.text = "耗时 -"
	if materials_container:
		for child in materials_container.get_children():
			child.queue_free()
	_material_labels.clear()
	_cached_recipe_materials.clear()
	_material_entry_order.clear()
	if craft_count_label:
		craft_count_label.text = "制作: 第 0 颗 / 共 0 颗"
	if craft_progress_bar:
		craft_progress_bar.value = 0
	if craft_button:
		craft_button.text = "开始炼制"
	_refresh_dynamic_ui_state()
	_update_count_button_styles()

# === 材料显示 ===
func _update_materials_display():
	if not materials_container or not selected_recipe or not recipe_data:
		return
	
	var materials = recipe_data.get_recipe_materials(selected_recipe)
	var spirit_required = recipe_data.get_recipe_spirit_energy(selected_recipe)
	var entry_order = _build_material_entry_order(materials, spirit_required)
	_sync_material_labels(materials, spirit_required, entry_order)
	_cached_recipe_materials = materials.duplicate()
	_update_material_labels_text()

func _build_material_entry_order(materials: Dictionary, spirit_required: int) -> Array:
	var material_ids: Array = []
	for material_id_variant in materials.keys():
		material_ids.append(str(material_id_variant))
	material_ids.sort()
	var order: Array = []
	for material_id in material_ids:
		order.append(material_id)
	if spirit_required > 0:
		order.append("spirit_energy")
	return order

func _ensure_material_columns() -> Dictionary:
	var hbox = materials_container.get_node_or_null("MaterialsHBox")
	if not hbox:
		hbox = HBoxContainer.new()
		hbox.name = "MaterialsHBox"
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		materials_container.add_child(hbox)

	var col1 = hbox.get_node_or_null("Column1")
	if not col1:
		col1 = VBoxContainer.new()
		col1.name = "Column1"
		col1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col1.custom_minimum_size = Vector2(0, 90)
		hbox.add_child(col1)

	var col2 = hbox.get_node_or_null("Column2")
	if not col2:
		col2 = VBoxContainer.new()
		col2.name = "Column2"
		col2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col2.custom_minimum_size = Vector2(0, 90)
		hbox.add_child(col2)

	return {"col1": col1, "col2": col2}

func _sync_material_labels(materials: Dictionary, spirit_required: int, entry_order: Array):
	var valid_set := {}
	for entry_id_variant in entry_order:
		var entry_id = str(entry_id_variant)
		valid_set[entry_id] = true

	# 删除失效标签
	var stale_ids: Array = []
	for existing_id_variant in _material_labels.keys():
		var existing_id = str(existing_id_variant)
		if not valid_set.has(existing_id):
			stale_ids.append(existing_id)
	for stale_id_variant in stale_ids:
		var stale_id = str(stale_id_variant)
		var label = _material_labels.get(stale_id, null)
		if is_instance_valid(label):
			var parent = label.get_parent()
			if parent:
				parent.remove_child(label)
			label.free()
		_material_labels.erase(stale_id)

	var columns = _ensure_material_columns()
	var col1: VBoxContainer = columns["col1"]
	var col2: VBoxContainer = columns["col2"]

	# 新增/重排
	for i in range(entry_order.size()):
		var entry_id = str(entry_order[i])
		var target_col: VBoxContainer = col1 if i < 3 else col2
		var target_index: int = i if i < 3 else i - 3

		var label: Label = _material_labels.get(entry_id, null)
		if not is_instance_valid(label):
			label = _create_material_label(entry_id)
			_material_labels[entry_id] = label
			target_col.add_child(label)
		elif label.get_parent() != target_col:
			var old_parent = label.get_parent()
			if old_parent:
				old_parent.remove_child(label)
			target_col.add_child(label)

		if label.get_parent() == target_col and label.get_index() != target_index:
			target_col.move_child(label, target_index)

	_material_entry_order = entry_order.duplicate()

func _create_material_label(entry_id: String) -> Label:
	var label = Label.new()
	label.name = "MaterialLabel_%s" % entry_id
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_font_size_override("font_size", FONT_SIZE_TEXT)
	return label

func _update_material_labels_text():
	for material_id_variant in _material_entry_order:
		var material_id = str(material_id_variant)
		var label = _material_labels.get(material_id, null)
		if not is_instance_valid(label):
			continue
		
		if material_id == "spirit_energy":
			var spirit_required = recipe_data.get_recipe_spirit_energy(selected_recipe) if recipe_data else 0
			var total_spirit = spirit_required * selected_count
			var has_spirit = int(player.spirit_energy) if player else 0
			label.text = "灵气: %s / %s" % [
				UIUtils.format_display_number(float(has_spirit)),
				UIUtils.format_display_number(float(total_spirit))
			]
			label.add_theme_color_override("font_color", COLOR_TEXT_RED if has_spirit < total_spirit else COLOR_TEXT_DARK)
		else:
			var required_per = _cached_recipe_materials.get(material_id, 0)
			var total_required = required_per * selected_count
			var has = inventory.get_item_count(material_id) if inventory else 0
			var item_name = item_data.get_item_name(material_id) if item_data else material_id
			label.text = "%s: %s / %s" % [
				item_name,
				UIUtils.format_display_number(float(has)),
				UIUtils.format_display_number(float(total_required))
			]
			label.add_theme_color_override("font_color", COLOR_TEXT_RED if has < total_required else COLOR_TEXT_DARK)

func _update_craft_count_label():
	if craft_count_label:
		if _is_alchemizing:
			craft_count_label.text = "制作: 第 %d 颗 / 共 %d 颗" % [_runtime_index, _runtime_total_count]
		else:
			craft_count_label.text = "制作: 第 0 颗 / 共 %d 颗" % selected_count

# === 炼丹信息 ===
func _update_alchemy_info():
	if not alchemy_system:
		return
	
	var alchemy_bonus = alchemy_system.get_alchemy_bonus()
	var furnace_bonus = alchemy_system.get_furnace_bonus()
	
	if alchemy_info_label:
		if alchemy_bonus.get("obtained", false):
			var alchemy_level = alchemy_bonus.get("level", 0)
			alchemy_info_label.text = "炼丹术: LV.%d (+%d成功值, +%.0f%%速度)" % [
				alchemy_level,
				alchemy_bonus.get("success_bonus", 0),
				alchemy_bonus.get("speed_rate", 0.0) * 100
			]
		else:
			alchemy_info_label.text = "炼丹术: 未学习"
	
	if furnace_info_label:
		if furnace_bonus.get("has_furnace", false):
			furnace_info_label.text = "丹炉: %s (+%d成功值, +%.0f%%速度)" % [
				furnace_bonus.get("furnace_name", "未知丹炉"),
				furnace_bonus.get("success_bonus", 0),
				furnace_bonus.get("speed_rate", 0.0) * 100
			]
		else:
			furnace_info_label.text = "丹炉: 无"

# === 炼制流程 ===
func _on_craft_pressed():
	if not selected_recipe or not alchemy_system or not api or _is_alchemizing:
		return
	if not _begin_action_lock("alchemy_start"):
		return

	if game_ui and game_ui.has_method("can_enter_mode"):
		var enter_check = game_ui.can_enter_mode("alchemy")
		if not enter_check.get("ok", false):
			log_message.emit(enter_check.get("message", "请先结束当前行为"))
			_end_action_lock("alchemy_start")
			return

	# 开始炼丹前同步修炼增量
	var settle_ok = true
	if game_ui and game_ui.get("cultivation_module") and game_ui.get("cultivation_module").has_method("flush_pending_and_then"):
		settle_ok = await game_ui.get("cultivation_module").flush_pending_and_then(func(): pass)
	if not settle_ok:
		log_message.emit("炼丹前修炼同步失败，请稍后重试")
		_end_action_lock("alchemy_start")
		return

	if not _can_start_batch(selected_recipe, selected_count):
		log_message.emit("灵材或灵气不足，无法开炉炼丹")
		_end_action_lock("alchemy_start")
		return

	var start_result = await api.alchemy_start()
	if not start_result.get("success", false):
		var err_msg = _get_alchemy_result_message(start_result, "开始炼丹失败")
		if not err_msg.is_empty():
			log_message.emit(err_msg)
		_end_action_lock("alchemy_start")
		return

	_runtime_recipe_id = selected_recipe
	_runtime_total_count = selected_count
	_runtime_index = 0
	_runtime_success_count = 0
	_runtime_fail_count = 0
	_runtime_timer = 0.0
	_runtime_craft_time = alchemy_system.calculate_craft_time(selected_recipe)
	_is_alchemizing = true
	_report_time_invalid_prompted = false
	_runtime_pending_cost.clear()
	if not _apply_single_pre_deduct(_runtime_recipe_id):
		log_message.emit("灵材或灵气不足，无法开炉炼丹")
		_restore_pending_cost()
		_is_alchemizing = false
		await api.alchemy_stop()
		_end_action_lock("alchemy_start")
		return
	_on_alchemy_crafting_started(_runtime_recipe_id, _runtime_total_count)
	_end_action_lock("alchemy_start")

func _on_stop_pressed():
	if not _is_alchemizing:
		return
	if not _begin_action_lock("alchemy_stop"):
		return
	await _finish_alchemy_session(false)

func _finish_alchemy_session(natural_finished: bool):
	_pending_async_task_count += 1
	if not api:
		_end_action_lock("alchemy_stop")
		_pending_async_task_count = maxi(0, _pending_async_task_count - 1)
		return

	var stop_result = await api.alchemy_stop()
	if not stop_result.get("success", false):
		var err_msg = _get_alchemy_result_message(stop_result, "停止炼丹失败")
		if not err_msg.is_empty():
			log_message.emit(err_msg)

	if not natural_finished:
		_restore_pending_cost()

	var success_count = _runtime_success_count
	var fail_count = _runtime_fail_count

	_is_alchemizing = false
	_runtime_recipe_id = ""
	_runtime_total_count = 0
	_runtime_index = 0
	_runtime_success_count = 0
	_runtime_fail_count = 0
	_runtime_timer = 0.0
	_runtime_craft_time = 0.0
	_runtime_tick_in_flight = false
	_runtime_pending_cost.clear()
	_report_time_invalid_prompted = false

	if game_ui and game_ui.has_method("clear_active_mode"):
		game_ui.clear_active_mode("alchemy")

	if natural_finished:
		_on_alchemy_crafting_finished(selected_recipe, success_count, fail_count)
	else:
		_on_alchemy_crafting_stopped(success_count, fail_count)
	
	if game_ui and game_ui.has_method("refresh_all_player_data"):
		await game_ui.refresh_all_player_data()

	_end_action_lock("alchemy_stop")
	_pending_async_task_count = maxi(0, _pending_async_task_count - 1)

func _on_alchemy_crafting_started(recipe_id: String, count: int):
	if game_ui and game_ui.has_method("set_active_mode"):
		game_ui.set_active_mode("alchemy")
	_refresh_dynamic_ui_state()
	if craft_progress_bar:
		craft_progress_bar.visible = true
		craft_progress_bar.value = 0
	_update_craft_count_label()
	_update_count_button_styles()
	var start_msg = _get_alchemy_result_message({"reason_code": "ALCHEMY_START_SUCCEEDED"}, "开炉炼丹")
	if not start_msg.is_empty():
		log_message.emit(start_msg + "，开始炼制[" + recipe_data.get_recipe_name(recipe_id) + "]")

func _on_alchemy_crafting_progress(current: int, total: int, progress: float):
	if craft_progress_bar:
		craft_progress_bar.value = progress
	if craft_count_label:
		craft_count_label.text = "制作: 第 %d 颗 / 共 %d 颗" % [current, total]

func _on_alchemy_single_craft_completed(success: bool, recipe_name: String):
	_update_materials_display()

func _on_alchemy_crafting_finished(recipe_id: String, success_count: int, fail_count: int):
	if craft_button:
		craft_button.text = "开始炼制"
	_refresh_dynamic_ui_state()
	if craft_progress_bar:
		craft_progress_bar.value = 0

	_render_alchemy_ui(true)
	log_message.emit(_build_alchemy_summary_message(success_count, fail_count))

func _on_alchemy_crafting_stopped(success_count: int, fail_count: int):
	if craft_button:
		craft_button.text = "开始炼制"
	_refresh_dynamic_ui_state()
	if craft_progress_bar:
		craft_progress_bar.value = 0

	_render_alchemy_ui(true)
	log_message.emit(_build_alchemy_summary_message(success_count, fail_count))

# === 公共方法 ===
func set_craft_count(count: int):
	if _is_alchemizing:
		return
	var max_allowed = maxi(get_max_craft_count(), 1)
	selected_count = clampi(count, 1, max_allowed)
	_update_craft_count_label()
	_update_materials_display()
	_update_count_button_styles()

func adjust_craft_count(delta: int):
	if _is_alchemizing:
		return
	var max_allowed = maxi(get_max_craft_count(), 1)
	selected_count = clampi(selected_count + delta, 1, max_allowed)
	_update_craft_count_label()
	_update_materials_display()
	_update_count_button_styles()

func set_craft_count_to_min():
	if _is_alchemizing:
		return
	selected_count = 1
	_update_craft_count_label()
	_update_materials_display()
	_update_count_button_styles()

func set_craft_count_to_max():
	if _is_alchemizing:
		return
	selected_count = maxi(get_max_craft_count(), 1)
	_update_craft_count_label()
	_update_materials_display()
	_update_count_button_styles()

func is_crafting_active() -> bool:
	return _is_alchemizing

func has_pending_test_tasks() -> bool:
	return _pending_async_task_count > 0 or _runtime_tick_in_flight

func stop_crafting():
	if _is_alchemizing:
		await _finish_alchemy_session(false)

func get_max_craft_count() -> int:
	if not selected_recipe or not alchemy_system:
		return 0
	
	var materials = recipe_data.get_recipe_materials(selected_recipe)
	var max_count = 9999
	
	for material_id in materials:
		var has_count = inventory.get_item_count(material_id) if inventory else 0
		var possible_count = int(has_count / materials[material_id])
		max_count = mini(max_count, possible_count)
	
	if player and recipe_data:
		var spirit_required = recipe_data.get_recipe_spirit_energy(selected_recipe)
		if spirit_required > 0:
			var max_by_spirit = int(player.spirit_energy / spirit_required)
			max_count = mini(max_count, max_by_spirit)
	
	return max_count
