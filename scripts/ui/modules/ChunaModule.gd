class_name ChunaModule extends Node

# 储纳模块 - 处理物品管理、物品详情等功能

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

func initialize(ui: Node, player_node: Node, inv: Node, item_data_node: Node, spell_sys: Node = null, spell_dt: Node = null):
	game_ui = ui
	player = player_node
	inventory = inv
	item_data = item_data_node
	spell_system = spell_sys
	spell_data = spell_dt
	
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
	if not inventory or not inventory_grid:
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
	var item_list = inventory.get_item_list()
	
	for child in inventory_grid.get_children():
		var index = child.get_meta("index", -1)
		if index >= 0 and index < item_list.size():
			var item = item_list[index]
			var name_label = child.get_node_or_null("NameLabel")
			var count_label = child.get_node_or_null("CountLabel")
			
			if item.get("empty", true):
				if name_label:
					name_label.text = ""
				if count_label:
					count_label.text = ""
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
	
	var item_info = item_data.get_item_data(current_selected_item_id) if item_data else {}
	var content = item_info.get("content", {})
	var effect = item_info.get("effect", {})
	var item_name = item_info.get("name", "未知")
	
	# 处理有效果的物品
	if not effect.is_empty():
		var effect_type = effect.get("type", "")
		var effect_amount = int(effect.get("amount", 0))
		
		match effect_type:
			"add_spirit_energy_unlimited":
				if player:
					player.add_spirit_energy_unlimited(effect_amount)
					_add_log("使用" + item_name + "，灵气增加" + str(effect_amount) + "点！")
				else:
					_add_log("玩家未初始化，无法使用")
					return
			"add_spirit_energy":
				if player:
					player.add_spirit_energy(effect_amount)
					_add_log("使用" + item_name + "，灵气增加" + str(effect_amount) + "点！")
				else:
					_add_log("玩家未初始化，无法使用")
					return
			"add_health":
				if player:
					player.heal(effect_amount)
					_add_log("使用" + item_name + "，气血值恢复" + str(effect_amount) + "点！")
				else:
					_add_log("玩家未初始化，无法使用")
					return
			"add_spirit_and_health":
				if player:
					var spirit_amount = int(effect.get("spirit_amount", 0))
					var health_amount = int(effect.get("health_amount", 0))
					var unlimited = effect.get("unlimited", false)
					if unlimited:
						player.add_spirit_energy_unlimited(spirit_amount)
					else:
						player.add_spirit(spirit_amount)
					player.heal(health_amount)
					_add_log("使用" + item_name + "，灵气增加" + str(spirit_amount) + "点，气血值恢复" + str(health_amount) + "点！")
				else:
					_add_log("玩家未初始化，无法使用")
					return
			"unlock_spell":
				if spell_system:
					var spell_id = effect.get("spell_id", "")
					var result = spell_system.obtain_spell(spell_id)
					if result:
						var spell_name = spell_data.get_spell_name(spell_id) if spell_data else spell_id
						_add_log("使用" + item_name + "，成功解锁术法")
						# 通知GameUI刷新术法UI
						if game_ui and game_ui.has_method("_init_spell_ui"):
							game_ui._init_spell_ui()
					else:
						_add_log("该术法已解锁")
						return
				else:
					_add_log("术法系统未初始化，无法使用")
					return
			"unlock_feature":
				var feature_id = effect.get("feature_id", "")
				match feature_id:
					"alchemy":
						if player:
							if player.has_alchemy_furnace:
								_add_log("已拥有丹炉")
								return
							player.has_alchemy_furnace = true
							_add_log("使用" + item_name + "，成功解锁炼丹功能")
							# 通知GameUI刷新炼丹房UI
							if game_ui and game_ui.has_method("refresh_alchemy_ui"):
								game_ui.refresh_alchemy_ui()
						else:
							_add_log("玩家未初始化，无法使用")
							return
					_:
						_add_log("未知功能：" + feature_id)
						return
			"learn_recipe":
				var recipe_id = effect.get("recipe_id", "")
				if not recipe_id:
					# 尝试从物品ID推断丹方ID
					if current_selected_item_id.begins_with("recipe_"):
						recipe_id = current_selected_item_id.replace("recipe_", "")
					else:
						_add_log("无效的丹方ID")
						return
				
				if not player:
					_add_log("玩家未初始化，无法使用")
					return
				
				# 检查是否已学会
				if recipe_id in player.learned_recipes:
					_add_log("已学会该丹方")
					return
				
				# 添加到已学会列表
				player.learned_recipes.append(recipe_id)
				_add_log("使用" + item_name + "，成功学会丹方")
				
				# 通知GameUI刷新炼丹房UI
				if game_ui and game_ui.has_method("refresh_alchemy_ui"):
					game_ui.refresh_alchemy_ui()
			_:
				_add_log("未知效果类型：" + effect_type)
				return
		
		# 消耗物品
		if inventory:
			inventory.remove_item(current_selected_item_id, 1)
		item_used.emit(current_selected_item_id)
		update_inventory_ui()
		_clear_item_detail_panel()
		return
	
	# 处理有内容的物品（如新手礼包）
	if not content.is_empty():
		# 检查境界限制
		var requirement = item_info.get("requirement", {})
		if not requirement.is_empty():
			var game_manager = get_node_or_null("/root/GameManager")
			if game_manager and player:
				var realm_system = game_manager.get_realm_system()
				if realm_system:
					if not realm_system.check_realm_requirement(player.realm, player.realm_level, requirement):
						_add_log("境界不足，无法打开")
						return
		
		for content_id in content.keys():
			var content_count = int(content[content_id])
			if inventory:
				inventory.add_item(content_id, content_count)
				# 物品添加的日志由 _on_item_added 处理
		
		# 消耗物品
		if inventory:
			inventory.remove_item(current_selected_item_id, 1)
		item_used.emit(current_selected_item_id)
		update_inventory_ui()
		_clear_item_detail_panel()
		return
	
	_add_log("该物品无法使用")

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
	if current_selected_item_id.is_empty():
		return
	
	var item_info = item_data.get_item_data(current_selected_item_id) if item_data else {}
	var item_name = item_info.get("name", "未知")
	
	# 从背包中移除物品
	if inventory:
		inventory.remove_item(current_selected_item_id, 1)
		item_discarded.emit(current_selected_item_id, 1)
		_add_log("丢弃物品: " + item_name)
		update_inventory_ui()
		_clear_item_detail_panel()

func _on_expand_button_pressed():
	if not inventory:
		return
	
	var current_slots = inventory_grid.get_child_count() if inventory_grid else 0
	if current_slots >= MAX_SLOTS:
		_add_log("纳戒储纳已达到上限 (" + str(MAX_SLOTS) + " 格)")
		return
	
	if inventory.has_method("expand_capacity") and inventory.expand_capacity():
		var new_capacity = min(inventory.get_capacity(), MAX_SLOTS)
		_add_log("纳戒储纳上限已扩容至 " + str(new_capacity) + " 格")
		
		# 添加新的格子而不是重新创建所有格子
		for i in range(current_slots, new_capacity):
			var slot = _create_slot(i)
			inventory_grid.add_child(slot)
		
		# 等待布局更新后调整大小
		await get_tree().process_frame
		_update_slot_sizes()
		update_inventory_ui()
	else:
		_add_log("背包已达到最大容量")

func _on_sort_button_pressed():
	if not inventory:
		return
	
	if inventory.has_method("sort_by_id"):
		inventory.sort_by_id()
		_clear_item_detail_panel()
		update_inventory_ui()
		_add_log("纳戒已整理")

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
