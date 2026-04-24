class_name ChunaModule extends Node

# 储纳模块 - 处理物品管理、物品详情等功能
const ACTION_LOCK_MANAGER = preload("res://scripts/utils/flow/ActionLockManager.gd")
const ACTION_BUTTON_TEMPLATE = preload("res://scripts/ui/common/ActionButtonTemplate.gd")
const POPUP_STYLE_TEMPLATE = preload("res://scripts/ui/common/PopupStyleTemplate.gd")

# 信号
signal item_selected(item_id: String, index: int)
signal item_used(item_id: String)
signal item_discarded(item_id: String, count: int)
signal inventory_updated
signal log_message(message: String)  # 日志消息信号

# 引用
var game_ui: Node = null
var player: Node = null
var inventory: Node = null
var item_data: Node = null
var spell_system: Node = null
var spell_data: Node = null
var alchemy_system: Node = null
var api: Node = null
var recipe_data_ref: Node = null

# UI节点引用
var chuna_panel: Control = null
var inventory_grid: GridContainer = null
var capacity_label: Label = null
var item_detail_panel: Panel = null
var view_button: Button = null
var use_button: Button = null
var discard_button: Button = null
var expand_button: Button = null
var sort_button: Button = null

# 常量
const GRID_COLS = 5
const MAX_SLOTS = 40
const SLOT_BG_EMPTY := Color(0.82, 0.78, 0.70, 1.0)
const SLOT_BG_OCCUPIED := Color(0.88, 0.84, 0.76, 1.0)
const SLOT_BG_SELECTED := Color(0.95, 0.90, 0.80, 1.0)
const SLOT_BORDER_DEFAULT := Color(0.71, 0.64, 0.51, 1.0)
const SLOT_BORDER_SELECTED := Color(0.87, 0.71, 0.21, 1.0)

# 当前选中的物品
var current_selected_item_id: String = ""
var current_selected_index: int = -1

# 信号连接状态标记
var _signals_connected: bool = false
var _discard_overlay_host: Control = null
var _discard_confirm_overlay: ColorRect = null
var _discard_confirm_panel: Panel = null
var _discard_confirm_line1: Label = null
var _discard_confirm_line2: Label = null
var _discard_confirm_button: Button = null

const ACTION_COOLDOWN_SECONDS := 0.1
var _action_lock := ACTION_LOCK_MANAGER.new()

func initialize(
	ui: Node,
	_player_node: Node,
	inv: Node,
	item_data_node: Node,
	_spell_sys: Node = null,
	spell_dt: Node = null,
	_alchemy_sys: Node = null,
	game_api: Node = null,
	recipe_data_node: Node = null
):
	game_ui = ui
	player = _player_node
	inventory = inv
	item_data = item_data_node
	spell_system = _spell_sys
	spell_data = spell_dt
	alchemy_system = _alchemy_sys
	api = game_api
	recipe_data_ref = recipe_data_node
	
	# 检查必需节点
	_check_required_nodes()
	_apply_action_button_templates()
	
	_setup_signals()
	_setup_viewport_listener()
	_setup_discard_confirm_popup()
	setup_inventory_grid()

func _apply_action_button_templates():
	if use_button:
		ACTION_BUTTON_TEMPLATE.apply_cultivation_yellow(use_button, use_button.custom_minimum_size)
	if discard_button:
		ACTION_BUTTON_TEMPLATE.apply_breakthrough_red(discard_button, discard_button.custom_minimum_size)
	if expand_button:
		ACTION_BUTTON_TEMPLATE.apply_cultivation_yellow(expand_button, expand_button.custom_minimum_size)
	if sort_button:
		ACTION_BUTTON_TEMPLATE.apply_light_neutral(sort_button, sort_button.custom_minimum_size)

func _get_game_manager() -> Node:
	return get_node_or_null("/root/GameManager")

func _get_recipe_data() -> Node:
	if recipe_data_ref and is_instance_valid(recipe_data_ref):
		return recipe_data_ref
	var game_manager = _get_game_manager()
	if game_manager and game_manager.has_method("get_recipe_data"):
		return game_manager.get_recipe_data()
	return null

func _get_item_name(item_id: String) -> String:
	if item_data and item_data.has_method("get_item_name"):
		return item_data.get_item_name(item_id)
	return item_id

func _get_spell_name(spell_id: String) -> String:
	if spell_data and spell_data.has_method("get_spell_name"):
		return spell_data.get_spell_name(spell_id)
	return spell_id

func _get_recipe_name(recipe_id: String) -> String:
	var recipe_data = _get_recipe_data()
	if recipe_data and recipe_data.has_method("get_recipe_name"):
		return recipe_data.get_recipe_name(recipe_id)
	return recipe_id

func _format_inventory_contents(contents: Dictionary) -> String:
	if contents.is_empty():
		return ""
	var item_ids: Array = []
	for raw_item_id in contents.keys():
		item_ids.append(str(raw_item_id))
	item_ids.sort()
	var parts: Array = []
	for item_id in item_ids:
		parts.append("%s x%d" % [_get_item_name(item_id), int(contents[item_id])])
	return "、".join(parts)

func _get_inventory_result_message(result: Dictionary, fallback: String = "") -> String:
	var reason_code = str(result.get("reason_code", ""))
	var reason_data = result.get("reason_data", {})
	var item_id = str(reason_data.get("item_id", ""))
	var item_name = _get_item_name(item_id) if not item_id.is_empty() else "该物品"
	var effect = reason_data.get("effect", {})
	if not (effect is Dictionary):
		effect = {}
	var contents = reason_data.get("contents", {})
	if not (contents is Dictionary):
		contents = {}
	match reason_code:
		"INVENTORY_USE_CONSUMABLE_SUCCEEDED":
			match str(effect.get("type", "")):
				"add_spirit_energy":
					return "%s使用成功，获得灵气%d" % [item_name, int(effect.get("spirit_energy_added", 0))]
				"add_health":
					return "%s使用成功，恢复气血%d" % [item_name, int(effect.get("health_added", 0))]
				"add_spirit_and_health":
					return "%s使用成功，获得灵气%d，恢复气血%d" % [
						item_name,
						int(effect.get("spirit_energy_added", 0)),
						int(effect.get("health_added", 0))
					]
				_:
					return item_name + "使用成功"
		"INVENTORY_USE_GIFT_SUCCEEDED":
			var content_text = _format_inventory_contents(contents)
			if content_text.is_empty():
				return item_name + "打开成功"
			return item_name + "打开成功，获得" + content_text
		"INVENTORY_USE_UNLOCK_SPELL_SUCCEEDED":
			return "学会术法【%s】" % _get_spell_name(str(effect.get("spell_id", "")))
		"INVENTORY_USE_UNLOCK_RECIPE_SUCCEEDED":
			return "学会丹方【%s】" % _get_recipe_name(str(effect.get("recipe_id", "")))
		"INVENTORY_USE_UNLOCK_FURNACE_SUCCEEDED":
			return "获得丹炉【%s】" % _get_item_name(str(effect.get("furnace_id", item_id)))
		"INVENTORY_USE_ITEM_NOT_FOUND":
			return "物品不存在"
		"INVENTORY_USE_ITEM_NOT_ENOUGH":
			return item_name + "数量不足"
		"INVENTORY_USE_ITEM_NOT_USABLE":
			return item_name + "无法使用"
		"INVENTORY_USE_EFFECT_INVALID":
			return item_name + "效果异常"
		"INVENTORY_USE_UNLOCK_SPELL_INVALID":
			return item_name + "无效"
		"INVENTORY_USE_UNLOCK_RECIPE_INVALID":
			return item_name + "无效"
		"INVENTORY_USE_ALREADY_USED":
			return item_name + "已经使用过了，无法重复使用"
		"INVENTORY_USE_SYSTEM_ERROR":
			return item_name + "使用失败，请稍后重试"
		"INVENTORY_USE_REQUIREMENT_NOT_MET":
			var requirement = effect.get("requirement", reason_data.get("requirement", {}))
			if requirement is Dictionary and requirement.has("realm_min"):
				var need_level = int(requirement.get("realm_min", 0))
				if need_level > 0:
					return item_name + "需要炼气" + str(need_level) + "层才能打开"
			return item_name + "暂不满足使用条件"
		"INVENTORY_DISCARD_SUCCEEDED":
			return item_name + "丢弃成功"
		"INVENTORY_DISCARD_ITEM_NOT_ENOUGH":
			return item_name + "数量不足"
		"INVENTORY_EXPAND_SUCCEEDED":
			return "纳戒扩容成功，当前容量%s格" % UIUtils.format_display_number_integer(float(reason_data.get("new_capacity", 0)))
		"INVENTORY_EXPAND_CAPACITY_MAX":
			return "纳戒已达到最大容量"
		"INVENTORY_ORGANIZE_SUCCEEDED":
			return "纳戒已整理"
		_:
			return api.network_manager.get_api_error_text_for_ui(result, fallback)

func _check_required_nodes():
	"""检查必需的UI节点是否存在"""
	if not inventory_grid:
		push_warning("ChunaModule: inventory_grid 未设置")
	if not item_detail_panel:
		push_warning("ChunaModule: item_detail_panel 未设置")
	if not use_button:
		push_warning("ChunaModule: use_button 未设置")
	if not discard_button:
		push_warning("ChunaModule: discard_button 未设置")

func _setup_signals():
	"""连接按钮信号，防止重复连接"""
	if _signals_connected:
		return
	
	# 连接按钮信号
	if view_button and not view_button.pressed.is_connected(_on_view_button_pressed):
		view_button.pressed.connect(_on_view_button_pressed)
	if use_button and not use_button.pressed.is_connected(_on_use_button_pressed):
		use_button.pressed.connect(_on_use_button_pressed)
	if discard_button and not discard_button.pressed.is_connected(_on_discard_button_pressed):
		discard_button.pressed.connect(_on_discard_button_pressed)
	if expand_button and not expand_button.pressed.is_connected(_on_expand_button_pressed):
		expand_button.pressed.connect(_on_expand_button_pressed)
	if sort_button and not sort_button.pressed.is_connected(_on_sort_button_pressed):
		sort_button.pressed.connect(_on_sort_button_pressed)
	
	_signals_connected = true

func cleanup():
	"""清理资源，断开信号连接"""
	_cleanup_viewport_listener()
	
	if view_button and view_button.pressed.is_connected(_on_view_button_pressed):
		view_button.pressed.disconnect(_on_view_button_pressed)
	if use_button and use_button.pressed.is_connected(_on_use_button_pressed):
		use_button.pressed.disconnect(_on_use_button_pressed)
	if discard_button and discard_button.pressed.is_connected(_on_discard_button_pressed):
		discard_button.pressed.disconnect(_on_discard_button_pressed)
	if expand_button and expand_button.pressed.is_connected(_on_expand_button_pressed):
		expand_button.pressed.disconnect(_on_expand_button_pressed)
	if sort_button and sort_button.pressed.is_connected(_on_sort_button_pressed):
		sort_button.pressed.disconnect(_on_sort_button_pressed)
	
	_signals_connected = false
	_hide_discard_confirm_popup(false)
	if _discard_confirm_overlay and is_instance_valid(_discard_confirm_overlay):
		_discard_confirm_overlay.queue_free()
	_discard_confirm_overlay = null
	_discard_confirm_panel = null
	_discard_confirm_line1 = null
	_discard_confirm_line2 = null
	_discard_confirm_button = null
	_discard_overlay_host = null

func _setup_discard_confirm_popup():
	if _discard_confirm_overlay:
		return
	_discard_overlay_host = game_ui as Control
	if not _discard_overlay_host:
		_discard_overlay_host = chuna_panel
	if not _discard_overlay_host:
		return

	_discard_confirm_overlay = ColorRect.new()
	_discard_confirm_overlay.name = "DiscardConfirmOverlay"
	_discard_confirm_overlay.visible = false
	_discard_confirm_overlay.color = Color(0, 0, 0, 0.45)
	_discard_confirm_overlay.z_index = 1200
	_discard_confirm_overlay.layout_mode = 1
	_discard_confirm_overlay.anchors_preset = 15
	_discard_confirm_overlay.anchor_right = 1.0
	_discard_confirm_overlay.anchor_bottom = 1.0
	_discard_confirm_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_discard_confirm_overlay.gui_input.connect(_on_discard_overlay_input)
	_discard_overlay_host.add_child(_discard_confirm_overlay)

	_discard_confirm_panel = Panel.new()
	_discard_confirm_panel.name = "DiscardConfirmPanel"
	_discard_confirm_panel.z_index = 1201
	_discard_confirm_panel.layout_mode = 1
	_discard_confirm_panel.anchors_preset = 8
	_discard_confirm_panel.anchor_left = 0.5
	_discard_confirm_panel.anchor_top = 0.5
	_discard_confirm_panel.anchor_right = 0.5
	_discard_confirm_panel.anchor_bottom = 0.5
	_discard_confirm_panel.offset_left = -170
	_discard_confirm_panel.offset_top = -90
	_discard_confirm_panel.offset_right = 170
	_discard_confirm_panel.offset_bottom = 90
	_discard_confirm_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_discard_confirm_panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			_discard_confirm_panel.accept_event()
	)
	_discard_confirm_panel.add_theme_stylebox_override("panel", POPUP_STYLE_TEMPLATE.build_panel_style({
		"bg_color": POPUP_STYLE_TEMPLATE.POPUP_BG_COLOR,
		"border_color": POPUP_STYLE_TEMPLATE.POPUP_BORDER_COLOR,
		"corner_radius": 12,
		"border_width": 2
	}))
	_discard_confirm_overlay.add_child(_discard_confirm_panel)

	var margin := MarginContainer.new()
	margin.layout_mode = 1
	margin.anchors_preset = 15
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	_discard_confirm_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	_discard_confirm_line1 = Label.new()
	_discard_confirm_line1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_discard_confirm_line1.add_theme_font_size_override("font_size", 19)
	_discard_confirm_line1.add_theme_color_override("font_color", Color(0.24, 0.22, 0.19, 1.0))
	vbox.add_child(_discard_confirm_line1)

	_discard_confirm_line2 = Label.new()
	_discard_confirm_line2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_discard_confirm_line2.add_theme_font_size_override("font_size", 15)
	_discard_confirm_line2.add_theme_color_override("font_color", Color(0.30, 0.27, 0.22, 1.0))
	_discard_confirm_line2.text = "（此物品为重要物品，丢弃后无法找回）"
	vbox.add_child(_discard_confirm_line2)

	_discard_confirm_button = Button.new()
	_discard_confirm_button.name = "DiscardConfirmButton"
	_discard_confirm_button.text = "确定丢弃"
	_discard_confirm_button.custom_minimum_size = Vector2(170, 46)
	ACTION_BUTTON_TEMPLATE.apply_breakthrough_red(_discard_confirm_button, _discard_confirm_button.custom_minimum_size, 18)
	_discard_confirm_button.pressed.connect(_on_discard_confirmed)
	vbox.add_child(_discard_confirm_button)

func _on_discard_overlay_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_hide_discard_confirm_popup()
		_on_discard_cancelled()
		_discard_confirm_overlay.accept_event()

func _show_discard_confirm_popup(item_name: String):
	if not _discard_confirm_overlay:
		_setup_discard_confirm_popup()
	if not _discard_confirm_overlay:
		return
	if _discard_confirm_line1:
		_discard_confirm_line1.text = "确定要丢弃 %s 吗？" % item_name
	_discard_confirm_overlay.visible = true

func _hide_discard_confirm_popup(clear_log: bool = false):
	if _discard_confirm_overlay:
		_discard_confirm_overlay.visible = false
	if clear_log:
		_on_discard_cancelled()

func _setup_viewport_listener():
	"""设置屏幕大小变化监听"""
	if get_viewport() and not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)

func _cleanup_viewport_listener():
	"""清理屏幕大小变化监听"""
	if get_viewport() and get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.disconnect(_on_viewport_size_changed)

func _on_viewport_size_changed():
	_update_slot_sizes()

# 显示储纳Tab
func show_tab():
	if chuna_panel:
		chuna_panel.visible = true
	_clear_item_detail_panel()
	update_inventory_ui()
	# 初始化时，确保数据是最新的
	if game_ui and bool(game_ui.get("allow_background_server_refresh")):
		game_ui.call_deferred("refresh_all_player_data")

# 隐藏储纳Tab
func hide_tab():
	if chuna_panel:
		chuna_panel.visible = false
	_clear_item_detail_panel()

# 设置物品格子
func setup_inventory_grid():
	if not inventory_grid:
		return
	
	# 禁用并隐藏横向滚动条
	var scroll_container = inventory_grid.get_parent() if inventory_grid.get_parent() is ScrollContainer else null
	if scroll_container:
		scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	
	# 清空现有格子
	while inventory_grid.get_child_count() > 0:
		var child = inventory_grid.get_child(0)
		inventory_grid.remove_child(child)
		child.queue_free()
	
	# 获取当前容量，限制最大格子数
	var current_capacity = 40
	if inventory:
		current_capacity = min(inventory.get_capacity(), MAX_SLOTS)
	
	inventory_grid.columns = GRID_COLS
	
	# 先创建所有格子
	for i in range(current_capacity):
		var slot = _create_slot(i)
		inventory_grid.add_child(slot)
	
		# 延迟到当前帧结束后再调整大小，避免在测试释放节点时留下悬空协程
		call_deferred("_update_slot_sizes")

# 创建单个格子
func _create_slot(index: int) -> Control:
	var slot = Control.new()
	slot.set_meta("index", index)
	slot.layout_mode = 2
	slot.size_flags_horizontal = 3
	slot.size_flags_vertical = 3
	
	# 初始大小，会在_update_slot_sizes中更新
	slot.custom_minimum_size = Vector2(100, 80)
	
	var bg = ColorRect.new()
	bg.name = "SlotBg"
	bg.color = Color(0.2, 0.2, 0.2, 0.5)
	bg.layout_mode = 1
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(bg)

	var border = Panel.new()
	border.name = "SlotBorder"
	border.layout_mode = 1
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(border)
	
	var name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.layout_mode = 1
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color(0.12, 0.12, 0.12, 1))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(name_label)
	
	var count_label = Label.new()
	count_label.name = "CountLabel"
	count_label.layout_mode = 1
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	count_label.offset_left = -55
	count_label.offset_top = -20
	count_label.offset_right = -2
	count_label.offset_bottom = -2
	count_label.add_theme_font_size_override("font_size", 14)
	count_label.add_theme_color_override("font_color", Color(0.12, 0.12, 0.12, 1))
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(count_label)
	
	slot.gui_input.connect(_on_slot_input.bind(index))
	
	_apply_slot_visual(slot, true, false)
	return slot

# 更新格子大小
func _update_slot_sizes():
	if not inventory_grid:
		return
	
	# 计算每个格子的宽度
	var scroll_container = inventory_grid.get_parent()
	if not scroll_container:
		return
	
	var available_width = scroll_container.size.x - 20  # 减去边距
	var separation = 5
	var slot_width = (available_width - separation * (GRID_COLS - 1)) / GRID_COLS
	var slot_height = 80  # 固定高度为80像素
	
	# 更新所有格子的大小
	for child in inventory_grid.get_children():
		if child is Control:
			child.custom_minimum_size = Vector2(slot_width, slot_height)

# 格子输入事件
func _on_slot_input(event: InputEvent, index: int):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_slot(index)

# 选择格子
func _select_slot(index: int):
	current_selected_index = index
	
	# 获取该格子的物品
	var item_list = inventory.get_item_list() if inventory else []
	if index >= 0 and index < item_list.size():
		var item = item_list[index]
		if not item.get("empty", true):
			var item_id = item.get("id", "")
			current_selected_item_id = item_id
			_show_item_detail(index)
			item_selected.emit(item_id, index)
		else:
			_clear_item_detail_panel()
	else:
		_clear_item_detail_panel()

	_refresh_slot_visuals()

# 更新储纳UI
func update_inventory_ui():
	if not inventory or not inventory_grid:
		return
	
	# 更新容量显示
	if capacity_label:
		var used = inventory.get_used_slots()
		var cap = inventory.get_capacity()
		capacity_label.text = "容量：" + UIUtils.format_display_number_integer(float(used)) + " / " + UIUtils.format_display_number_integer(float(cap))
	
	# 更新扩展按钮状态
	if expand_button:
		expand_button.visible = inventory.can_expand() if inventory.has_method("can_expand") else false
	
	# 更新格子显示
	var item_list = inventory.get_item_list() if inventory else []
	
	for child in inventory_grid.get_children():
		var index = child.get_meta("index", -1)
		if index >= 0 and index < item_list.size():
			var item = item_list[index]
			var name_label = child.get_node_or_null("NameLabel")
			var count_label = child.get_node_or_null("CountLabel")
			
			if item == null or item.get("empty", true):
				if name_label:
					name_label.text = ""
					name_label.add_theme_color_override("font_color", Color(0.12, 0.12, 0.12, 1))
				if count_label:
					count_label.text = ""
				_apply_slot_visual(child, true, index == current_selected_index)
			else:
				var item_id = item.get("id", "")
				var count = int(item.get("count", 0))
				var item_info = item_data.get_item_data(item_id) if item_data else {}
				var item_name = item_info.get("name", "未知")
				var quality = int(item_info.get("quality", 0))
				
				if name_label:
					name_label.text = item_name
					name_label.add_theme_color_override("font_color", _get_display_quality_color(quality))
				if count_label:
					if count > 1:
						count_label.text = "x" + UIUtils.format_display_number_integer(float(count))
					else:
						count_label.text = ""
				_apply_slot_visual(child, false, index == current_selected_index)

func _refresh_slot_visuals():
	if not inventory or not inventory_grid:
		return
	var item_list = inventory.get_item_list()
	for child in inventory_grid.get_children():
		var index = child.get_meta("index", -1)
		if index < 0 or index >= item_list.size():
			_apply_slot_visual(child, true, false)
			continue
		var item = item_list[index]
		var is_empty = item == null or item.get("empty", true)
		_apply_slot_visual(child, is_empty, index == current_selected_index)

func _apply_slot_visual(slot: Control, is_empty: bool, is_selected: bool):
	if not slot:
		return
	var bg = slot.get_node_or_null("SlotBg") as ColorRect
	if bg:
		if is_selected:
			bg.color = SLOT_BG_SELECTED
		else:
			bg.color = SLOT_BG_EMPTY if is_empty else SLOT_BG_OCCUPIED
	var border = slot.get_node_or_null("SlotBorder") as Panel
	if border:
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.corner_radius_top_left = 4
		sb.corner_radius_top_right = 4
		sb.corner_radius_bottom_left = 4
		sb.corner_radius_bottom_right = 4
		sb.border_width_left = 2 if is_selected else 1
		sb.border_width_top = 2 if is_selected else 1
		sb.border_width_right = 2 if is_selected else 1
		sb.border_width_bottom = 2 if is_selected else 1
		sb.border_color = SLOT_BORDER_SELECTED if is_selected else SLOT_BORDER_DEFAULT
		border.add_theme_stylebox_override("panel", sb)

# 获取显示用的品质颜色（确保足够亮度）
func _get_display_quality_color(quality: int) -> Color:
	if not item_data or not item_data.has_method("get_item_quality_color"):
		return Color(0.12, 0.12, 0.12, 1)
	
	return item_data.get_item_quality_color(quality)

# 显示物品详情
func _show_item_detail(index: int):
	if not inventory or not item_detail_panel:
		return
	
	var item_list = inventory.get_item_list()
	if index >= item_list.size() or item_list[index].get("empty", true):
		_clear_item_detail_panel()
		return
	
	var item_id = item_list[index].get("id", "")
	var count = int(item_list[index].get("count", 0))
	
	if item_id.is_empty():
		_clear_item_detail_panel()
		return
	
	var item_info = item_data.get_item_data(item_id) if item_data else {}
	var item_name = item_info.get("name", "未知")
	var description = item_info.get("description", "")
	var quality = item_info.get("quality", 0)
	var type = item_info.get("type", 0)
	
	var detail_name = item_detail_panel.get_node_or_null("VBoxContainer/MainHBox/InfoVBox/DetailName")
	var detail_desc = item_detail_panel.get_node_or_null("VBoxContainer/MainHBox/DescVBox/ScrollContainer/DetailContent/DetailDesc")
	var detail_type = item_detail_panel.get_node_or_null("VBoxContainer/MainHBox/InfoVBox/DetailInfo/DetailType")
	var detail_count = item_detail_panel.get_node_or_null("VBoxContainer/MainHBox/InfoVBox/DetailInfo/DetailCount")
	var detail_stats = item_detail_panel.get_node_or_null("VBoxContainer/MainHBox/DescVBox/ScrollContainer/DetailContent/DetailStats")
	var desc_title = item_detail_panel.get_node_or_null("VBoxContainer/MainHBox/DescVBox/DescTitle")
	var info_separator = item_detail_panel.get_node_or_null("VBoxContainer/MainHBox/InfoSeparator")
	var button_separator = item_detail_panel.get_node_or_null("VBoxContainer/MainHBox/ButtonSeparator")
	
	if detail_name:
		detail_name.text = item_name
		detail_name.modulate = _get_display_quality_color(quality)
	if detail_desc:
		detail_desc.text = description
	if detail_type:
		var type_str = ""
		match type:
			ItemData.ItemType.CURRENCY: type_str = "货币"
			ItemData.ItemType.MATERIAL: type_str = "材料"
			ItemData.ItemType.CONSUMABLE: type_str = "消耗品"
			ItemData.ItemType.GIFT: type_str = "礼包"
			ItemData.ItemType.UNLOCK_SPELL: type_str = "解锁术法"
			ItemData.ItemType.UNLOCK_RECIPE: type_str = "解锁丹方"
			ItemData.ItemType.UNLOCK_FURNACE: type_str = "解锁炼丹炉"
		detail_type.text = "类型: " + type_str
	if detail_count:
		detail_count.text = "数量: " + UIUtils.format_display_number(float(count))
	
	# 隐藏装备属性显示（暂无装备类物品）
	if detail_stats:
		detail_stats.visible = false
	if desc_title:
		desc_title.visible = true
	if info_separator:
		info_separator.visible = true
	if button_separator:
		button_separator.visible = true
	
	# 按钮可见性控制（根据新的物品类型系统）
	# 查看按钮已移除，详情直接显示在面板中
	
	# type=3 (GIFT) 的一定有打开按钮
	# type=2 (CONSUMABLE)、type=4 (UNLOCK_SPELL)、type=5 (UNLOCK_RECIPE)、type=6 (UNLOCK_FURNACE) 且有 effect 字段的，才有使用按钮
	var item_type = item_info.get("type", 0)
	var has_effect = item_info.has("effect") and not item_info.get("effect", {}).is_empty()
	
	if use_button:
		if item_type == ItemData.ItemType.GIFT:
			# 礼包类，显示打开按钮
			use_button.visible = true
			use_button.text = "打开"
		elif (item_type == ItemData.ItemType.CONSUMABLE or item_type == ItemData.ItemType.UNLOCK_SPELL or item_type == ItemData.ItemType.UNLOCK_RECIPE or item_type == ItemData.ItemType.UNLOCK_FURNACE) and has_effect:
			# 消耗品类或解锁类，且有effect，显示使用按钮
			use_button.visible = true
			use_button.text = "使用"
		else:
			use_button.visible = false
	
	# 丢弃按钮始终显示
	if discard_button:
		discard_button.visible = true
	
	current_selected_index = index
	current_selected_item_id = item_id
	item_detail_panel.visible = true

# 清空物品详情面板
func _clear_item_detail_panel():
	if not item_detail_panel:
		return
	
	var detail_name = item_detail_panel.get_node_or_null("VBoxContainer/MainHBox/InfoVBox/DetailName")
	var detail_desc = item_detail_panel.get_node_or_null("VBoxContainer/MainHBox/DescVBox/ScrollContainer/DetailContent/DetailDesc")
	var detail_type = item_detail_panel.get_node_or_null("VBoxContainer/MainHBox/InfoVBox/DetailInfo/DetailType")
	var detail_count = item_detail_panel.get_node_or_null("VBoxContainer/MainHBox/InfoVBox/DetailInfo/DetailCount")
	var detail_stats = item_detail_panel.get_node_or_null("VBoxContainer/MainHBox/DescVBox/ScrollContainer/DetailContent/DetailStats")
	var desc_title = item_detail_panel.get_node_or_null("VBoxContainer/MainHBox/DescVBox/DescTitle")
	var info_separator = item_detail_panel.get_node_or_null("VBoxContainer/MainHBox/InfoSeparator")
	var button_separator = item_detail_panel.get_node_or_null("VBoxContainer/MainHBox/ButtonSeparator")
	
	if detail_name:
		detail_name.text = ""
	if detail_desc:
		detail_desc.text = ""
	if detail_type:
		detail_type.text = ""
	if detail_count:
		detail_count.text = ""
	if detail_stats:
		detail_stats.visible = false
	if desc_title:
		desc_title.visible = false
	if info_separator:
		info_separator.visible = false
	if button_separator:
		button_separator.visible = false
	
	if view_button:
		view_button.visible = false
	if use_button:
		use_button.visible = false
	if discard_button:
		discard_button.visible = false
	
	current_selected_index = -1
	current_selected_item_id = ""
	_refresh_slot_visuals()

func _begin_action_lock(action_key: String) -> bool:
	return _action_lock.try_begin(action_key)

func _end_action_lock(action_key: String):
	_action_lock.end(action_key, ACTION_COOLDOWN_SECONDS)

func has_pending_test_tasks() -> bool:
	return _action_lock.has_any_in_flight()

func _apply_local_unlock_result(result: Dictionary):
	if not spell_system:
		return
	var reason_code := str(result.get("reason_code", ""))
	if reason_code != "INVENTORY_USE_UNLOCK_SPELL_SUCCEEDED":
		return
	var reason_data = result.get("reason_data", {})
	var effect = reason_data.get("effect", {})
	if not (effect is Dictionary):
		return
	var spell_id := str(effect.get("spell_id", ""))
	if spell_id.is_empty():
		return
	var player_spells: Dictionary = spell_system.get_player_spells() if spell_system.has_method("get_player_spells") else {}
	if not (player_spells is Dictionary):
		return
	if not player_spells.has(spell_id):
		return
	var spell_info = player_spells[spell_id]
	spell_info["obtained"] = true
	if int(spell_info.get("level", 0)) <= 0:
		spell_info["level"] = 1
	if not spell_info.has("use_count"):
		spell_info["use_count"] = 0
	if not spell_info.has("charged_spirit"):
		spell_info["charged_spirit"] = 0
	if game_ui and game_ui.spell_module:
		game_ui.spell_module.update_spell_ui()

func _refresh_after_inventory_action(preserve_selection: bool = true):
	if game_ui and game_ui.has_method("refresh_all_player_data"):
		await game_ui.refresh_all_player_data()
	else:
		await _refresh_inventory_from_server()
	if preserve_selection:
		_restore_selected_item_detail_if_possible()
	else:
		_clear_item_detail_panel()

func _restore_selected_item_detail_if_possible():
	if not inventory:
		_clear_item_detail_panel()
		return
	if current_selected_index < 0:
		_clear_item_detail_panel()
		return

	var item_list = inventory.get_item_list()
	if current_selected_index >= item_list.size():
		_clear_item_detail_panel()
		return

	var item = item_list[current_selected_index]
	if item == null or bool(item.get("empty", true)):
		_clear_item_detail_panel()
		return

	var item_id = str(item.get("id", ""))
	if item_id.is_empty():
		_clear_item_detail_panel()
		return

	current_selected_item_id = item_id
	_show_item_detail(current_selected_index)

# 按钮处理函数
func _on_view_button_pressed():
	if current_selected_item_id.is_empty():
		return
	var item_info = item_data.get_item_data(current_selected_item_id) if item_data else {}
	var name = item_info.get("name", "未知")
	var description = item_info.get("description", "")
	_add_log("查看物品: " + name + " - " + description)

func _on_use_button_pressed():
	if current_selected_item_id.is_empty() or current_selected_index < 0:
		return
	if not api:
		_add_log("网络接口未初始化")
		return
	if not _begin_action_lock("inventory_use"):
		return

	var settle_ok = true
	if game_ui and game_ui.cultivation_module and game_ui.cultivation_module.has_method("flush_pending_and_then"):
		settle_ok = await game_ui.cultivation_module.flush_pending_and_then(func(): pass)
	if not settle_ok:
		_add_log("修炼增量同步失败，暂无法使用物品")
		_end_action_lock("inventory_use")
		return

	var item_id = current_selected_item_id
	var result = await api.inventory_use(item_id)
	if not result.get("success", false):
		var err_msg = _get_inventory_result_message(result, "使用失败")
		if not err_msg.is_empty():
			_add_log(err_msg)
		_end_action_lock("inventory_use")
		return

	item_used.emit(item_id)
	_apply_local_unlock_result(result)
	
	await _refresh_after_inventory_action(true)
	_add_log(_get_inventory_result_message(result, "使用成功"))

	_end_action_lock("inventory_use")

func _on_discard_button_pressed():
	if current_selected_item_id.is_empty() or current_selected_index < 0:
		return

	var item_info = item_data.get_item_data(current_selected_item_id) if item_data else {}
	var item_name = item_info.get("name", "未知")

	# 检查是否为重要物品（需要二次确认）
	if item_data and item_data.is_important(current_selected_item_id):
		_show_discard_confirm_dialog(item_name)
	else:
		# 直接丢弃
		_perform_discard()

# 显示丢弃确认对话框
func _show_discard_confirm_dialog(item_name: String):
	_show_discard_confirm_popup(item_name)

func _on_discard_confirmed():
	_hide_discard_confirm_popup()
	_perform_discard()

func _on_discard_cancelled():
	_add_log("取消丢弃")

# 执行丢弃操作
func _perform_discard():
	if current_selected_item_id.is_empty() or not api:
		return
	if not _begin_action_lock("inventory_discard"):
		return

	var result = await api.inventory_discard(current_selected_item_id, 1)
	if not result.get("success", false):
		var err_msg = _get_inventory_result_message(result, "丢弃失败")
		if not err_msg.is_empty():
			_add_log(err_msg)
		_end_action_lock("inventory_discard")
		return

	item_discarded.emit(current_selected_item_id, 1)
	_add_log(_get_inventory_result_message(result, "丢弃成功"))
	
	await _refresh_after_inventory_action(true)

	_end_action_lock("inventory_discard")

func _on_expand_button_pressed():
	if not api:
		return
	if not _begin_action_lock("inventory_expand"):
		return

	var result = await api.inventory_expand()
	if not result.get("success", false):
		var err_msg = _get_inventory_result_message(result, "扩容失败")
		if not err_msg.is_empty():
			_add_log(err_msg)
		_end_action_lock("inventory_expand")
		return

	_add_log(_get_inventory_result_message(result, "扩容成功"))
	
	await _refresh_after_inventory_action()

	_end_action_lock("inventory_expand")

func _on_sort_button_pressed():
	if not api:
		return
	if not _begin_action_lock("inventory_sort"):
		return

	var result = await api.inventory_organize()
	if not result.get("success", false):
		var err_msg = _get_inventory_result_message(result, "整理失败")
		if not err_msg.is_empty():
			_add_log(err_msg)
		_end_action_lock("inventory_sort")
		return

	await _refresh_after_inventory_action(false)
	_add_log(_get_inventory_result_message(result, "整理成功"))
	_end_action_lock("inventory_sort")

func _refresh_inventory_from_server():
	if not api or not inventory:
		return
	var list_result = await api.inventory_list()
	if list_result.get("success", false):
		if list_result.has("inventory") and list_result["inventory"] is Dictionary:
			inventory.apply_save_data(list_result.get("inventory", {}))
			setup_inventory_grid()
			update_inventory_ui()
			return
	var err_msg = api.network_manager.get_api_error_text_for_ui(list_result, "背包同步失败")
	if not err_msg.is_empty():
		_add_log(err_msg)

# 辅助函数：添加日志（通过信号）

func _add_log(message: String):
	log_message.emit(message)
