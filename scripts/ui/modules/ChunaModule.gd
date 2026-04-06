class_name ChunaModule extends Node

# 储纳模块 - 处理物品管理、物品详情等功能
const ActionLockManager = preload("res://scripts/managers/ActionLockManager.gd")

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
const MAX_SLOTS = 200

# 当前选中的物品
var current_selected_item_id: String = ""
var current_selected_index: int = -1

# 信号连接状态标记
var _signals_connected: bool = false

const ACTION_COOLDOWN_SECONDS := 0.1
var _action_lock := ActionLockManager.new()

func initialize(ui: Node, player_node: Node, inv: Node, item_data_node: Node, spell_sys: Node = null, spell_dt: Node = null, alchemy_sys: Node = null, game_api: Node = null):
	game_ui = ui
	player = player_node
	inventory = inv
	item_data = item_data_node
	spell_system = spell_sys
	spell_data = spell_dt
	alchemy_system = alchemy_sys
	api = game_api
	
	# 检查必需节点
	_check_required_nodes()
	
	_setup_signals()
	_setup_viewport_listener()
	setup_inventory_grid()

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
	if game_ui and game_ui.has_method("refresh_all_player_data"):
		game_ui.refresh_all_player_data()

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
	var current_capacity = 50
	if inventory:
		current_capacity = min(inventory.get_capacity(), MAX_SLOTS)
	
	inventory_grid.columns = GRID_COLS
	
	# 先创建所有格子
	for i in range(current_capacity):
		var slot = _create_slot(i)
		inventory_grid.add_child(slot)
	
	# 等待一帧让布局更新后再调整大小
	await get_tree().process_frame
	_update_slot_sizes()

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
	bg.color = Color(0.2, 0.2, 0.2, 0.5)
	bg.layout_mode = 1
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(bg)
	
	var name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.layout_mode = 1
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 1))
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
	count_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 1))
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(count_label)
	
	slot.gui_input.connect(_on_slot_input.bind(index))
	
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

# 更新储纳UI
func update_inventory_ui():
	print("[ChunaModule] update_inventory_ui 调用")
	print("[ChunaModule] inventory: ", inventory)
	print("[ChunaModule] inventory_grid: ", inventory_grid)
	print("[ChunaModule] item_data: ", item_data)
	
	if not inventory or not inventory_grid:
		print("[ChunaModule] inventory 或 inventory_grid 为空，返回")
		return
	
	# 更新容量显示
	if capacity_label:
		var used = inventory.get_used_slots()
		var cap = inventory.get_capacity()
		capacity_label.text = "容量：" + str(used) + "/" + str(cap)
	
	# 更新扩展按钮状态
	if expand_button:
		expand_button.visible = inventory.can_expand() if inventory.has_method("can_expand") else false
	
	# 更新格子显示
	var item_list = inventory.get_item_list() if inventory else []
	print("[ChunaModule] item_list 数量: ", item_list.size())
	
	for child in inventory_grid.get_children():
		var index = child.get_meta("index", -1)
		if index >= 0 and index < item_list.size():
			var item = item_list[index]
			var name_label = child.get_node_or_null("NameLabel")
			var count_label = child.get_node_or_null("CountLabel")
			
			if item == null or item.get("empty", true):
				if name_label:
					name_label.text = ""
				if count_label:
					count_label.text = ""
			else:
				var item_id = item.get("id", "")
				var count = int(item.get("count", 0))
				var item_info = item_data.get_item_data(item_id) if item_data else {}
				var item_name = item_info.get("name", "未知")
				print("[ChunaModule] 物品 ", index, ": id=", item_id, " name=", item_name, " count=", count)
				var quality = int(item_info.get("quality", 0))
				
				if name_label:
					name_label.text = item_name
					name_label.add_theme_color_override("font_color", _get_display_quality_color(quality))
				if count_label:
					if count > 1:
						count_label.text = "x" + UIUtils.format_number(int(count))
					else:
						count_label.text = ""

# 获取显示用的品质颜色（确保足够亮度）
func _get_display_quality_color(quality: int) -> Color:
	if not item_data or not item_data.has_method("get_item_quality_color"):
		return Color(0.2, 0.2, 0.2, 1)
	
	var quality_color = item_data.get_item_quality_color(quality)
	# 确保颜色不会太暗
	if quality_color.get_luminance() < 0.3:
		quality_color = quality_color.lightened(0.3)
	return quality_color

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
	
	var detail_name = item_detail_panel.get_node_or_null("VBoxContainer/DetailName")
	var detail_desc = item_detail_panel.get_node_or_null("VBoxContainer/ScrollContainer/DetailContent/DetailDesc")
	var detail_type = item_detail_panel.get_node_or_null("VBoxContainer/DetailType")
	var detail_count = item_detail_panel.get_node_or_null("VBoxContainer/DetailInfo/DetailCount")
	var detail_stats = item_detail_panel.get_node_or_null("VBoxContainer/ScrollContainer/DetailContent/DetailStats")
	
	if detail_name:
		detail_name.text = item_name
		detail_name.modulate = _get_display_quality_color(quality)
	if detail_desc:
		detail_desc.text = description
	if detail_type:
		var type_str = ""
		match type:
			0: type_str = "资源"
			1: type_str = "材料"
			2: type_str = "装备"
			3: type_str = "凭证"
		detail_type.text = "类型: " + type_str
	if detail_count:
		detail_count.text = "数量: " + str(int(count))
	
	# 装备属性显示
	if type == 2:
		var attack_val = item_info.get("attack", 0)
		var defense_val = item_info.get("defense", 0)
		var level_req = item_info.get("level_required", 1)
		
		if detail_stats:
			var stats_text = ""
			if attack_val > 0:
				stats_text += "攻击: +" + str(attack_val) + "\n"
			if defense_val > 0:
				stats_text += "防御: +" + str(defense_val) + "\n"
			stats_text += "需求等级: " + str(level_req)
			detail_stats.text = stats_text
			detail_stats.visible = true
	else:
		if detail_stats:
			detail_stats.visible = false
	
	# 按钮可见性控制（根据新的物品类型系统）
	# 查看按钮已移除，详情直接显示在面板中
	
	# type=3 的一定有打开按钮
	# type=2 和 type=4 且有 effect 字段的，才有使用按钮
	var item_type = item_info.get("type", 0)
	var has_effect = item_info.has("effect") and not item_info.get("effect", {}).is_empty()
	
	if use_button:
		if item_type == 3:
			# 礼包类，显示打开按钮
			use_button.visible = true
			use_button.text = "打开"
		elif (item_type == 2 or item_type == 4) and has_effect:
			# 装备类或功能解锁类，且有effect，显示使用按钮
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
	
	var detail_name = item_detail_panel.get_node_or_null("VBoxContainer/DetailName")
	var detail_desc = item_detail_panel.get_node_or_null("VBoxContainer/ScrollContainer/DetailContent/DetailDesc")
	var detail_type = item_detail_panel.get_node_or_null("VBoxContainer/DetailType")
	var detail_count = item_detail_panel.get_node_or_null("VBoxContainer/DetailInfo/DetailCount")
	var detail_stats = item_detail_panel.get_node_or_null("VBoxContainer/ScrollContainer/DetailContent/DetailStats")
	
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
	
	if view_button:
		view_button.visible = false
	if use_button:
		use_button.visible = false
	if discard_button:
		discard_button.visible = false
	
	current_selected_index = -1
	current_selected_item_id = ""

func _begin_action_lock(action_key: String) -> bool:
	return _action_lock.try_begin(action_key)

func _end_action_lock(action_key: String):
	_action_lock.end(action_key, ACTION_COOLDOWN_SECONDS)

func _refresh_after_inventory_action():
	if game_ui and game_ui.has_method("refresh_all_player_data"):
		await game_ui.refresh_all_player_data()
	else:
		await _refresh_inventory_from_server()

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
		var err_msg = api.network_manager.get_api_error_text_for_ui(result, "使用失败")
		if not err_msg.is_empty():
			_add_log(err_msg)
		_end_action_lock("inventory_use")
		return

	item_used.emit(item_id)
	_clear_item_detail_panel()
	
	await _refresh_after_inventory_action()

	var effect = result.get("effect", {})
	var contents = result.get("contents", null)
	if effect is Dictionary and not effect.is_empty():
		_add_log("使用成功")
	if contents is Dictionary and not contents.is_empty():
		_add_log("打开成功，奖励已入包")

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
	var dialog = AcceptDialog.new()
	dialog.title = "确认丢弃"
	dialog.dialog_text = "确定要丢弃 " + item_name + " 吗？\n\n（此物品为重要物品，丢弃后无法找回）"
	dialog.ok_button_text = "确定"
	# 取消按钮使用默认文本
	dialog.confirmed.connect(_on_discard_confirmed)
	dialog.canceled.connect(_on_discard_cancelled)
	add_child(dialog)
	dialog.popup_centered()

func _on_discard_confirmed():
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
		var err_msg = api.network_manager.get_api_error_text_for_ui(result, "丢弃失败")
		if not err_msg.is_empty():
			_add_log(err_msg)
		_end_action_lock("inventory_discard")
		return

	item_discarded.emit(current_selected_item_id, 1)
	_add_log("丢弃成功")
	_clear_item_detail_panel()
	
	await _refresh_after_inventory_action()

	_end_action_lock("inventory_discard")

func _on_expand_button_pressed():
	if not api:
		return
	if not _begin_action_lock("inventory_expand"):
		return

	var result = await api.inventory_expand()
	if not result.get("success", false):
		var err_msg = api.network_manager.get_api_error_text_for_ui(result, "扩容失败")
		if not err_msg.is_empty():
			_add_log(err_msg)
		_end_action_lock("inventory_expand")
		return

	_add_log(result.get("message", "扩容成功"))
	
	await _refresh_after_inventory_action()

	_end_action_lock("inventory_expand")

func _on_sort_button_pressed():
	if not api:
		return
	if not _begin_action_lock("inventory_sort"):
		return

	var result = await api.inventory_organize()
	if not result.get("success", false):
		var err_msg = api.network_manager.get_api_error_text_for_ui(result, "整理失败")
		if not err_msg.is_empty():
			_add_log(err_msg)
		_end_action_lock("inventory_sort")
		return

	_clear_item_detail_panel()
	await _refresh_after_inventory_action()
	_add_log("纳戒已整理")
	_end_action_lock("inventory_sort")

func _refresh_inventory_from_server():
	if not api or not inventory:
		return
	var list_result = await api.inventory_list()
	if list_result.get("success", false):
		var body: Dictionary = list_result
		if list_result.has("data") and list_result["data"] is Dictionary:
			body = list_result["data"]
		if body.has("inventory") and body["inventory"] is Dictionary:
			inventory.apply_save_data(body.get("inventory", {}))
			setup_inventory_grid()
			update_inventory_ui()
			return
	var err_msg = api.network_manager.get_api_error_text_for_ui(list_result, "背包同步失败")
	if not err_msg.is_empty():
		_add_log(err_msg)

# 辅助函数：添加日志（通过信号）

func _add_log(message: String):
	log_message.emit(message)

# 公共接口
## 获取当前选中的物品ID
func get_selected_item_id() -> String:
	return current_selected_item_id

## 获取当前选中的物品索引
func get_selected_index() -> int:
	return current_selected_index

## 清空当前选择
func clear_selection():
	_clear_item_detail_panel()
