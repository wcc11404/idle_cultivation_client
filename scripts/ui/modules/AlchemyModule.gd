class_name AlchemyModule extends Node

# 炼丹模块 - 处理炼丹房UI显示
const ActionLockManager = preload("res://scripts/managers/ActionLockManager.gd")

# === 信号 ===
signal recipe_selected(recipe_id: String)
signal log_message(message: String)
signal back_to_dongfu_requested

# === 样式常量 ===
const COLOR_BG_LIGHT := Color(0.92, 0.90, 0.87, 1.0)
const COLOR_BG_SELECTED := Color(0.85, 0.82, 0.75, 1.0)
const COLOR_BG_PANEL := Color(0.85, 0.82, 0.78, 0.75)
const COLOR_TEXT_DARK := Color(0.25, 0.22, 0.18, 1.0)
const COLOR_TEXT_DARKER := Color(0.15, 0.12, 0.10, 1.0)
const COLOR_TEXT_LIGHT := Color(0.95, 0.95, 0.92, 1.0)
const COLOR_TEXT_RED := Color(0.75, 0.25, 0.25, 1.0)
const COLOR_INDICATOR := Color(0.3, 0.55, 0.3, 1.0)
const COLOR_BUTTON_GREEN := Color(0.35, 0.50, 0.35, 1.0)
const COLOR_BUTTON_RED := Color(0.6, 0.35, 0.35, 1.0)
const COLOR_PROGRESS_BG := Color(0.5, 0.47, 0.43, 1.0)
const COLOR_PROGRESS_FILL := Color(0.3, 0.6, 0.3, 1.0)

const FONT_SIZE_TITLE := 24
const FONT_SIZE_NORMAL := 18
const FONT_SIZE_SMALL := 16

# === 引用 ===
var game_ui: Node = null
var player: Node = null
var alchemy_system: Node = null
var recipe_data: Node = null
var item_data: Node = null
var inventory: Node = null
var api: Node = null

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
var _runtime_consumed: Dictionary = {}
var _runtime_pre_deduct: Dictionary = {}

# === 缓存 ===
var _recipe_cards: Dictionary = {}
var _material_labels: Dictionary = {}
var _cached_recipe_materials: Dictionary = {}
var _progress_margin_added: bool = false
var _signals_connected: bool = false

const ACTION_COOLDOWN_SECONDS := 0.1
var _action_lock := ActionLockManager.new()

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
	if _runtime_timer < _runtime_craft_time:
		return

	_runtime_timer -= _runtime_craft_time
	_runtime_tick_in_flight = true
	await _run_alchemy_tick()
	_runtime_tick_in_flight = false

func _run_alchemy_tick():
	if not _is_alchemizing:
		return
	if _runtime_index >= _runtime_total_count:
		await _finish_alchemy_session(true)
		return

	var report_result = await api.alchemy_report(_runtime_recipe_id, 1)
	if not report_result.get("success", false):
		var err_msg = api.network_manager.get_api_error_text_for_ui(report_result, "炼丹上报失败")
		if not err_msg.is_empty():
			log_message.emit(err_msg)
		await _finish_alchemy_session(false)
		return

	_runtime_index += 1
	_runtime_success_count += int(report_result.get("success_count", 0))
	_runtime_fail_count += int(report_result.get("fail_count", 0))
	_apply_report_result(report_result)

	_on_alchemy_crafting_progress(_runtime_index, _runtime_total_count, 100.0 * float(_runtime_index) / float(max(1, _runtime_total_count)))
	_on_alchemy_single_craft_completed(int(report_result.get("success_count", 0)) > 0, recipe_data.get_recipe_name(_runtime_recipe_id) if recipe_data else "")

	if _runtime_index >= _runtime_total_count:
		await _finish_alchemy_session(true)

func _apply_report_result(report_result: Dictionary):
	if inventory and report_result.has("products"):
		for item_id in report_result.products.keys():
			var count = int(report_result.products[item_id])
			if count > 0:
				inventory.add_item(item_id, count)

	var materials_consumed = report_result.get("materials_consumed", {})
	for key in materials_consumed.keys():
		_runtime_consumed[key] = int(_runtime_consumed.get(key, 0)) + int(materials_consumed[key])

func _apply_pre_deduct(recipe_id: String, count: int) -> bool:
	if not recipe_data or not inventory or not player:
		return false

	_runtime_pre_deduct.clear()
	_runtime_consumed.clear()

	var materials = recipe_data.get_recipe_materials(recipe_id)
	for material_id in materials.keys():
		var need = int(materials[material_id]) * count
		if inventory.get_item_count(material_id) < need:
			return false
		_runtime_pre_deduct[material_id] = need

	var spirit_need = int(recipe_data.get_recipe_spirit_energy(recipe_id)) * count
	if player.spirit_energy < spirit_need:
		return false
	if spirit_need > 0:
		_runtime_pre_deduct["spirit_energy"] = spirit_need

	for material_id in materials.keys():
		inventory.remove_item(material_id, int(materials[material_id]) * count)
	if spirit_need > 0:
		player.consume_spirit(spirit_need)

	return true

func _refund_unconsumed_resources():
	if not inventory or not player:
		return

	for key in _runtime_pre_deduct.keys():
		var pre = int(_runtime_pre_deduct.get(key, 0))
		var consumed = int(_runtime_consumed.get(key, 0))
		var refund = max(0, pre - consumed)
		if refund <= 0:
			continue
		if key == "spirit_energy":
			player.add_spirit(refund)
		else:
			inventory.add_item(key, refund)

func setup_styles():
	_setup_ui_style()
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
func _setup_ui_style():
	if not alchemy_room_panel:
		return
	alchemy_room_panel.modulate = Color(1, 1, 1, 0.95)
	_apply_panel_style_recursive(alchemy_room_panel)
	_setup_craft_panel_style()

func _setup_craft_panel_style():
	_style_recipe_name_label()
	_style_info_labels()
	_style_materials_section()
	_style_progress_section()
	_style_count_buttons()
	_style_craft_button()

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
			label.add_theme_font_size_override("font_size", FONT_SIZE_NORMAL)
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
			child.add_theme_font_size_override("font_size", FONT_SIZE_NORMAL)
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
		craft_count_label.add_theme_font_size_override("font_size", FONT_SIZE_NORMAL)
		craft_count_label.add_theme_color_override("font_color", Color(0.3, 0.28, 0.25, 1.0))
	
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

func _style_count_buttons():
	_update_count_button_styles()

func _update_count_button_styles():
	var button_configs = [
		{btn = count_1_button, count = 1},
		{btn = count_10_button, count = 10},
		{btn = count_100_button, count = 100},
		{btn = count_max_button, count = -1}
	]
	
	for config in button_configs:
		var btn = config.btn
		if not btn:
			continue
		
		var is_selected = (selected_count == config.count) or (config.count == -1 and selected_count > 100)
		_apply_count_button_style(btn, is_selected)

func _apply_count_button_style(btn: Button, is_selected: bool):
	btn.custom_minimum_size = Vector2(60, 40)
	btn.add_theme_font_size_override("font_size", FONT_SIZE_NORMAL)
	
	var normal_style = StyleBoxFlat.new()
	normal_style.set_border_width_all(2)
	normal_style.set_corner_radius_all(4)
	
	if is_selected:
		normal_style.bg_color = Color(0.55, 0.52, 0.48, 1.0)
		normal_style.border_color = Color(0.35, 0.32, 0.28, 1.0)
		btn.add_theme_color_override("font_color", Color(0.95, 0.92, 0.88, 1.0))
	else:
		normal_style.bg_color = Color(0.82, 0.78, 0.72, 1.0)
		normal_style.border_color = Color(0.55, 0.50, 0.45, 1.0)
		btn.add_theme_color_override("font_color", COLOR_TEXT_DARK)
	
	btn.add_theme_stylebox_override("normal", normal_style)
	
	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(0.75, 0.71, 0.65, 1.0) if not is_selected else Color(0.60, 0.57, 0.53, 1.0)
	btn.add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style = normal_style.duplicate()
	pressed_style.bg_color = Color(0.68, 0.64, 0.58, 1.0) if not is_selected else Color(0.50, 0.47, 0.43, 1.0)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	
	var disabled_style = normal_style.duplicate()
	disabled_style.bg_color = Color(0.88, 0.85, 0.80, 0.5)
	btn.add_theme_stylebox_override("disabled", disabled_style)

func _style_craft_button():
	if not craft_button:
		return
	
	craft_button.text = "开始炼制"
	craft_button.custom_minimum_size = Vector2(160, 56)
	craft_button.add_theme_font_size_override("font_size", FONT_SIZE_TITLE)
	
	var normal_style = _create_button_style(COLOR_BUTTON_GREEN, Color(0.25, 0.40, 0.25, 1.0))
	craft_button.add_theme_stylebox_override("normal", normal_style)
	craft_button.add_theme_color_override("font_color", COLOR_TEXT_LIGHT)
	
	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(0.40, 0.55, 0.40, 1.0)
	craft_button.add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style = normal_style.duplicate()
	pressed_style.bg_color = Color(0.30, 0.45, 0.30, 1.0)
	craft_button.add_theme_stylebox_override("pressed", pressed_style)
	
	var disabled_style = normal_style.duplicate()
	disabled_style.bg_color = Color(0.6, 0.58, 0.55, 0.6)
	disabled_style.border_color = Color(0.5, 0.48, 0.45, 0.6)
	craft_button.add_theme_stylebox_override("disabled", disabled_style)
	craft_button.add_theme_color_override("font_disabled_color", Color(0.4, 0.38, 0.35, 1.0))
	
	_style_stop_button()

func _style_stop_button():
	if not stop_button:
		return
	
	stop_button.text = "停止"
	stop_button.custom_minimum_size = Vector2(160, 56)
	stop_button.add_theme_font_size_override("font_size", FONT_SIZE_TITLE)
	
	var stop_normal = _create_button_style(COLOR_BUTTON_RED, Color(0.5, 0.25, 0.25, 1.0))
	stop_button.add_theme_stylebox_override("normal", stop_normal)
	stop_button.add_theme_color_override("font_color", COLOR_TEXT_LIGHT)
	
	var stop_hover = stop_normal.duplicate()
	stop_hover.bg_color = Color(0.65, 0.40, 0.40, 1.0)
	stop_button.add_theme_stylebox_override("hover", stop_hover)

func _create_button_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

func _apply_panel_style_recursive(node: Node):
	if node is Panel or node is PanelContainer:
		var style = StyleBoxFlat.new()
		style.bg_color = COLOR_BG_PANEL
		style.set_corner_radius_all(8)
		node.add_theme_stylebox_override("panel", style)
	
	for child in node.get_children():
		_apply_panel_style_recursive(child)

# === 返回按钮 ===
func _setup_back_button():
	if not alchemy_room_panel:
		return
	
	if alchemy_back_button:
		_apply_count_button_style(alchemy_back_button, false)
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
	back_button.custom_minimum_size = Vector2(80, 40)
	back_button.pressed.connect(_on_back_button_pressed)
	_apply_count_button_style(back_button, false)
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
		_update_recipe_list()
		_update_alchemy_info()
		if selected_recipe:
			_update_craft_panel()
		call_deferred("_refresh_recipe_config_from_server")

func hide_alchemy_room():
	if alchemy_room_panel:
		alchemy_room_panel.visible = false

func refresh_ui():
	_update_recipe_list()
	_update_alchemy_info()
	if selected_recipe:
		_update_materials_display()
		_update_craft_count_label()
		if craft_button and not _is_alchemizing:
			craft_button.disabled = false

func _refresh_recipe_config_from_server():
	if not api:
		return
	var result = await api.alchemy_recipes()
	if not result.get("success", false):
		var err_msg = api.network_manager.get_api_error_text_for_ui(result, "丹方同步失败")
		if not err_msg.is_empty():
			log_message.emit(err_msg)
		return

	var body: Dictionary = result
	if result.has("data") and result["data"] is Dictionary:
		body = result["data"]

	if recipe_data and recipe_data.has_method("apply_remote_config"):
		var remote_recipes = body.get("recipes_config", {})
		if remote_recipes is Dictionary and not remote_recipes.is_empty():
			recipe_data.apply_remote_config({"recipes": remote_recipes})

	if alchemy_system and body.has("learned_recipes") and body["learned_recipes"] is Array:
		alchemy_system.apply_save_data({
			"equipped_furnace_id": str(alchemy_system.equipped_furnace_id),
			"learned_recipes": body["learned_recipes"]
		})

	refresh_ui()

# === 丹方列表 ===
func _update_recipe_list():
	if not recipe_list_container or not player or _is_alchemizing:
		return
	
	for child in recipe_list_container.get_children():
		child.queue_free()
	_recipe_cards.clear()
	
	var learned = alchemy_system.get_learned_recipes() if alchemy_system else []
	if learned.is_empty():
		var label = Label.new()
		label.text = "暂无学会的丹方"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 1))
		recipe_list_container.add_child(label)
		return
	
	var sorted_recipes = _sort_recipes(learned)
	
	for recipe_id in sorted_recipes:
		var recipe_name = recipe_data.get_recipe_name(recipe_id)
		var card = _create_recipe_card(recipe_id, recipe_name)
		recipe_list_container.add_child(card)
		_recipe_cards[recipe_id] = card
	
	_update_recipe_selection()
	
	if not selected_recipe and sorted_recipes.size() > 0:
		_select_recipe(sorted_recipes[0])

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
	name_label.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
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
	if craft_count_label:
		craft_count_label.text = "制作: 第 0 颗 / 共 0 颗"
	if craft_progress_bar:
		craft_progress_bar.value = 0
	if craft_button:
		craft_button.text = "开始炼制"
		craft_button.disabled = true

# === 材料显示 ===
func _update_materials_display():
	if not materials_container or not selected_recipe or not recipe_data:
		return
	
	var materials = recipe_data.get_recipe_materials(selected_recipe)
	
	if _cached_recipe_materials != materials:
		_cached_recipe_materials = materials.duplicate()
		_rebuild_material_labels(materials)
	else:
		_update_material_labels_text()

func _rebuild_material_labels(materials: Dictionary):
	for child in materials_container.get_children():
		child.get_parent().remove_child(child)
		child.free()
	_material_labels.clear()
	
	var hbox = HBoxContainer.new()
	hbox.name = "MaterialsHBox"
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	materials_container.add_child(hbox)
	
	var col1 = VBoxContainer.new()
	col1.name = "Column1"
	col1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col1.custom_minimum_size = Vector2(0, 90)
	hbox.add_child(col1)
	
	var col2 = VBoxContainer.new()
	col2.name = "Column2"
	col2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col2.custom_minimum_size = Vector2(0, 90)
	hbox.add_child(col2)
	
	var all_items = []
	for material_id in materials:
		all_items.append({"type": "material", "id": material_id, "required": materials[material_id]})
	
	var spirit_required = recipe_data.get_recipe_spirit_energy(selected_recipe)
	if spirit_required > 0:
		all_items.append({"type": "spirit", "id": "spirit_energy", "required": spirit_required})
	
	for i in range(all_items.size()):
		var item = all_items[i]
		var target_col = col1 if i < 3 else col2
		_create_material_item(target_col, item)

func _create_material_item(parent: VBoxContainer, item: Dictionary):
	var label = Label.new()
	
	if item.type == "spirit":
		label.name = "SpiritEnergyLabel"
		var total_spirit = item.required * selected_count
		var has_spirit = int(player.spirit_energy) if player else 0
		label.text = "灵气: %d/%d" % [has_spirit, total_spirit]
		label.add_theme_color_override("font_color", COLOR_TEXT_RED if has_spirit < total_spirit else COLOR_TEXT_DARK)
		_material_labels["spirit_energy"] = label
	else:
		var material_id = item.id
		var total_required = item.required * selected_count
		var has = inventory.get_item_count(material_id) if inventory else 0
		var item_name = item_data.get_item_name(material_id) if item_data else material_id
		label.text = "%s: %d/%d" % [item_name, has, total_required]
		label.add_theme_color_override("font_color", COLOR_TEXT_RED if has < total_required else COLOR_TEXT_DARK)
		_material_labels[material_id] = label
	
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_font_size_override("font_size", FONT_SIZE_NORMAL)
	parent.add_child(label)

func _update_material_labels_text():
	for material_id in _material_labels:
		var label = _material_labels[material_id]
		if not is_instance_valid(label):
			continue
		
		if material_id == "spirit_energy":
			var spirit_required = recipe_data.get_recipe_spirit_energy(selected_recipe) if recipe_data else 0
			var total_spirit = spirit_required * selected_count
			var has_spirit = int(player.spirit_energy) if player else 0
			label.text = "灵气: %d/%d" % [has_spirit, total_spirit]
			label.add_theme_color_override("font_color", COLOR_TEXT_RED if has_spirit < total_spirit else COLOR_TEXT_DARK)
		else:
			var required_per = _cached_recipe_materials.get(material_id, 0)
			var total_required = required_per * selected_count
			var has = inventory.get_item_count(material_id) if inventory else 0
			var item_name = item_data.get_item_name(material_id) if item_data else material_id
			label.text = "%s: %d/%d" % [item_name, has, total_required]
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

	if not _apply_pre_deduct(selected_recipe, selected_count):
		log_message.emit("灵材或灵气不足，无法开炉炼丹")
		_end_action_lock("alchemy_start")
		return

	var start_result = await api.alchemy_start()
	if not start_result.get("success", false):
		_refund_unconsumed_resources()
		var err_msg = api.network_manager.get_api_error_text_for_ui(start_result, "开始炼丹失败")
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
	_on_alchemy_crafting_started(_runtime_recipe_id, _runtime_total_count)
	_end_action_lock("alchemy_start")

func _on_stop_pressed():
	if not _is_alchemizing:
		return
	if not _begin_action_lock("alchemy_stop"):
		return
	await _finish_alchemy_session(false)

func _finish_alchemy_session(natural_finished: bool):
	if not api:
		_end_action_lock("alchemy_stop")
		return

	var stop_result = await api.alchemy_stop()
	if not stop_result.get("success", false):
		var err_msg = api.network_manager.get_api_error_text_for_ui(stop_result, "停止炼丹失败")
		if not err_msg.is_empty():
			log_message.emit(err_msg)

	_refund_unconsumed_resources()

	var completed = _runtime_index
	var remaining = max(_runtime_total_count - _runtime_index, 0)
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
	_runtime_pre_deduct.clear()
	_runtime_consumed.clear()

	if game_ui and game_ui.has_method("clear_active_mode"):
		game_ui.clear_active_mode("alchemy")

	if natural_finished:
		_on_alchemy_crafting_finished(selected_recipe, success_count, fail_count)
	else:
		_on_alchemy_crafting_stopped(completed, remaining)
	
	if game_ui and game_ui.has_method("refresh_all_player_data"):
		await game_ui.refresh_all_player_data()

	_end_action_lock("alchemy_stop")

func _on_alchemy_crafting_started(recipe_id: String, count: int):
	if game_ui and game_ui.has_method("set_active_mode"):
		game_ui.set_active_mode("alchemy")
	if craft_button:
		craft_button.disabled = true
	if stop_button:
		stop_button.disabled = false
	if craft_progress_bar:
		craft_progress_bar.visible = true
		craft_progress_bar.value = 0
	_update_craft_count_label()
	log_message.emit("开炉炼丹，开始炼制 [" + recipe_data.get_recipe_name(recipe_id) + "]")

func _on_alchemy_crafting_progress(current: int, total: int, progress: float):
	if craft_progress_bar:
		craft_progress_bar.value = progress
	if craft_count_label:
		craft_count_label.text = "制作: 第 %d 颗 / 共 %d 颗" % [current, total]

func _on_alchemy_single_craft_completed(success: bool, recipe_name: String):
	_update_materials_display()

func _on_alchemy_crafting_finished(recipe_id: String, success_count: int, fail_count: int):
	if craft_button:
		craft_button.disabled = false
		craft_button.text = "开始炼制"
	if stop_button:
		stop_button.disabled = true
	if craft_progress_bar:
		craft_progress_bar.value = 0

	_update_recipe_list()
	_update_alchemy_info()
	_update_materials_display()
	_update_craft_count_label()
	log_message.emit("此次炼丹结束，成丹%d枚，废丹%d枚" % [success_count, fail_count])

func _on_alchemy_crafting_stopped(completed_count: int, remaining_count: int):
	if craft_button:
		craft_button.disabled = false
		craft_button.text = "开始炼制"
	if stop_button:
		stop_button.disabled = true
	if craft_progress_bar:
		craft_progress_bar.value = 0

	_update_recipe_list()
	_update_craft_panel()
	_update_alchemy_info()
	_update_materials_display()
	_update_craft_count_label()
	log_message.emit("收丹停火：已完成%d颗，剩余%d颗" % [completed_count, remaining_count])


func _on_alchemy_log_message(message: String):
	log_message.emit(message)

# === 公共方法 ===
func set_craft_count(count: int):
	if _is_alchemizing:
		return
	selected_count = count
	_update_craft_count_label()
	_update_materials_display()
	_update_count_button_styles()

func is_crafting_active() -> bool:
	return _is_alchemizing

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
