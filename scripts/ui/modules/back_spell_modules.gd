class_name SpellModule extends Node

# 术法模块 - 处理术法列表、详情、装备/升级/合成等功能

# 信号
signal spell_equipped(spell_id: String)
signal spell_unequipped(spell_id: String)
signal spell_upgraded(spell_id: String)
signal spell_viewed(spell_id: String)
signal log_message(message: String)  # 日志消息信号

# 引用
var game_ui: Node = null
var player: Node = null
var spell_system: Node = null
var spell_data: Node = null
var save_manager: Node = null

# UI节点引用
var spell_panel: Control = null
var spell_tab: Button = null

# 术法弹窗
var spell_detail_popup: SpellDetailPopup = null
var spell_cards: Dictionary = {}
var current_viewing_spell: String = ""
var current_multiplier_index: int = 0

# 常量
const MULTIPLIERS = [10, 100, 999999]
const MULTIPLIER_LABELS = ["x10", "x100", "Max"]

# 卡片对象池
var _card_pool: Array[Control] = []
var _max_pool_size: int = 20

# 信号连接状态标记
var _signals_connected: bool = false

func initialize(ui: Node, player_node: Node, spell_sys: Node, spell_dt: Node):
	game_ui = ui
	player = player_node
	spell_system = spell_sys
	spell_data = spell_dt
	
	# 获取save_manager
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		save_manager = game_manager.get_save_manager()
	
	_setup_signals()

func _setup_signals():
	"""连接按钮信号，防止重复连接"""
	if _signals_connected:
		return
	
	if spell_tab and not spell_tab.pressed.is_connected(_on_spell_tab_pressed):
		spell_tab.pressed.connect(_on_spell_tab_pressed)
	
	_signals_connected = true

func cleanup():
	"""清理资源，断开信号连接"""
	if spell_tab and spell_tab.pressed.is_connected(_on_spell_tab_pressed):
		spell_tab.pressed.disconnect(_on_spell_tab_pressed)
	
	# 清理弹窗
	if spell_detail_popup:
		spell_detail_popup.cleanup()
		spell_detail_popup = null
	
	# 清理卡片对象池
	for card in _card_pool:
		if is_instance_valid(card):
			card.queue_free()
	_card_pool.clear()
	
	# 清空卡片引用
	spell_cards.clear()
	
	_signals_connected = false

func show_tab():
	"""显示术法标签页"""
	if spell_panel:
		spell_panel.visible = true
	_init_spell_ui()

func hide_tab():
	"""隐藏术法标签页"""
	if spell_panel:
		spell_panel.visible = false
	_on_spell_detail_close_pressed()

func _on_spell_tab_pressed():
	"""术法标签页按钮按下"""
	_show_neishi_sub_panel(spell_panel)
	_init_spell_ui()

func _show_neishi_sub_panel(active_panel: Control):
	"""显示内室子面板"""
	# 通知game_ui更新标签样式
	if game_ui and game_ui.has_method("_update_neishi_tab_buttons"):
		game_ui._update_neishi_tab_buttons(active_panel)

func _init_spell_ui():
	"""初始化术法UI"""
	if not spell_panel or not spell_system or not spell_data:
		return
	
	# 保存当前弹窗状态
	var was_viewing_spell = current_viewing_spell
	var was_popup_visible = false
	if spell_detail_popup:
		was_popup_visible = spell_detail_popup.is_popup_visible()
	
	# 回收卡片到对象池
	for spell_id in spell_cards.keys():
		var card = spell_cards[spell_id]
		if is_instance_valid(card):
			_return_card_to_pool(card)
	
	spell_cards.clear()
	
	# 清空现有内容（保留滚动容器结构）
	for child in spell_panel.get_children():
		if child.name != "SpellScrollContainer":
			child.queue_free()
	
	# 获取或创建滚动容器
	var scroll_container = spell_panel.get_node_or_null("SpellScrollContainer")
	if not scroll_container:
		scroll_container = ScrollContainer.new()
		scroll_container.name = "SpellScrollContainer"
		scroll_container.layout_mode = 1
		scroll_container.anchors_preset = 15  # PRESET_FULL_RECT
		scroll_container.anchor_right = 1.0
		scroll_container.anchor_bottom = 1.0
		scroll_container.offset_left = 10.0
		scroll_container.offset_top = 10.0
		scroll_container.offset_right = -10.0
		scroll_container.offset_bottom = -10.0
		scroll_container.grow_horizontal = 2  # GROW_DIRECTION_BOTH
		scroll_container.grow_vertical = 2  # GROW_DIRECTION_BOTH
		spell_panel.add_child(scroll_container)
	
	# 确保禁用横向滚动（无论是否新创建）
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	
	# 隐藏横向滚动条（如果存在）
	var h_scroll = scroll_container.get_node_or_null("_h_scroll")
	if h_scroll:
		h_scroll.visible = false
	
	# 获取或创建主容器
	var main_container = scroll_container.get_node_or_null("SpellMainContainer")
	if not main_container:
		main_container = VBoxContainer.new()
		main_container.name = "SpellMainContainer"
		main_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll_container.add_child(main_container)
	else:
		# 清空主容器中的旧内容
		for child in main_container.get_children():
			child.queue_free()
	
	# 创建分类容器
	var categories = {
		"吐纳心法": 0,
		"主动术法": 1,
		"被动术法": 2,
		"杂学术法": 3
	}
	
	for category_name in categories.keys():
		var spell_type = categories[category_name]
		_create_spell_category(main_container, category_name, spell_type)
	
	# 创建详情弹窗
	_create_spell_detail_popup()
	
	# 如果之前正在查看术法且弹窗是可见的，恢复显示
	if was_viewing_spell and was_popup_visible:
		current_viewing_spell = was_viewing_spell
		if spell_detail_popup:
			spell_detail_popup.show_popup()
			_update_spell_detail_popup()

func _create_spell_category(parent: Node, category_name: String, spell_type: int):
	"""创建术法分类"""
	# 分类标题（带装备数量显示，-1表示无限制）
	var category_label = Label.new()
	var limit = spell_data.get_equipment_limit(spell_type) if spell_data else 1
	var equipped_count = 0
	if spell_system:
		equipped_count = spell_system.get_equipped_count(spell_type)
	# 无限制时不显示数量
	if limit < 0:
		category_label.text = category_name
	else:
		category_label.text = category_name + " " + str(equipped_count) + "/" + str(limit)
	category_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	category_label.add_theme_font_size_override("font_size", 18)
	category_label.modulate = Color(0.2, 0.2, 0.2, 1)
	category_label.name = "CategoryLabel_" + str(spell_type)
	parent.add_child(category_label)
	
	# 术法卡片容器 - 使用GridContainer自动换行
	var cards_container = GridContainer.new()
	cards_container.name = category_name + "Container"
	cards_container.columns = 4
	cards_container.add_theme_constant_override("h_separation", 10)
	cards_container.add_theme_constant_override("v_separation", 10)
	parent.add_child(cards_container)
	
	# 获取该类型的术法
	if spell_data:
		var spell_ids = spell_data.get_spell_ids_by_type(spell_type)
		for spell_id in spell_ids:
			_create_spell_card(cards_container, spell_id)
	
	# 添加分割线
	var separator = HSeparator.new()
	separator.custom_minimum_size = Vector2(0, 20)
	# 设置分割线样式，使其更粗更明显
	var separator_style = StyleBoxLine.new()
	separator_style.color = Color(0.5, 0.5, 0.5, 0.5)
	separator_style.thickness = 2
	separator.add_theme_stylebox_override("separator", separator_style)
	parent.add_child(separator)

func _get_card_from_pool() -> Control:
	"""从对象池获取卡片"""
	if _card_pool.is_empty():
		return _create_spell_card_template()
	return _card_pool.pop_back()

func _return_card_to_pool(card: Control):
	"""将卡片返回对象池"""
	if _card_pool.size() >= _max_pool_size:
		card.queue_free()
		return
	
	# 断开所有信号连接
	for child in card.get_children():
		if child is VBoxContainer:
			for sub_child in child.get_children():
				if sub_child is HBoxContainer:
					for button in sub_child.get_children():
						if button is Button and button.pressed.get_connections().size() > 0:
							for conn in button.pressed.get_connections():
								button.pressed.disconnect(conn.callable)
	
	card.get_parent().remove_child(card)
	_card_pool.append(card)

func _create_spell_card_template() -> Control:
	"""创建术法卡片模板"""
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(130, 160)
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.95, 0.95, 0.95, 0.8)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.7, 0.7, 0.7, 0.8)
	card.add_theme_stylebox_override("panel", panel_style)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)
	
	# 术法名称
	var name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.modulate = Color(0.2, 0.2, 0.2, 1)
	vbox.add_child(name_label)
	
	# 状态标签
	var status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(status_label)
	
	# 按钮容器
	var button_container = HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_theme_constant_override("separation", 5)
	vbox.add_child(button_container)
	
	# 查看按钮
	var view_button = Button.new()
	view_button.name = "ViewButton"
	view_button.text = "查看"
	button_container.add_child(view_button)
	
	# 装备/卸下按钮
	var equip_button = Button.new()
	equip_button.name = "EquipButton"
	button_container.add_child(equip_button)
	
	return card

func _create_spell_card(parent: Node, spell_id: String):
	"""创建术法卡片"""
	var spell_info = spell_system.get_spell_info(spell_id) if spell_system else {}
	if spell_info.is_empty():
		return
	
	# 从对象池获取或创建新卡片
	var card = _get_card_from_pool()
	card.name = "SpellCard_" + spell_id
	
	# 更新卡片内容
	_update_spell_card_content(card, spell_info, spell_id)
	
	parent.add_child(card)
	spell_cards[spell_id] = card

func _update_spell_card_content(card: Control, spell_info: Dictionary, spell_id: String):
	var vbox = card.get_child(0) as VBoxContainer
	if not vbox:
		return
	
	var spell_type = spell_info.get("type", -1)
	var is_misc = (spell_type == spell_data.SpellType.MISC) if spell_data else false
	
	# 更新名称
	var name_label = vbox.get_node_or_null("NameLabel") as Label
	if name_label:
		name_label.text = spell_info.get("name", "")
	
	# 更新状态
	var status_label = vbox.get_node_or_null("StatusLabel") as Label
	if status_label:
		if not spell_info.get("obtained", false):
			status_label.text = "未获取"
			status_label.modulate = Color.GRAY
		else:
			status_label.text = "Lv." + str(spell_info.get("level", 0))
			status_label.modulate = Color.GREEN if spell_info.get("equipped", false) else Color(0.2, 0.2, 0.2, 1)
	
	# 更新按钮
	var button_container = vbox.get_child(2) as HBoxContainer
	if button_container:
		var view_button = button_container.get_node_or_null("ViewButton") as Button
		var equip_button = button_container.get_node_or_null("EquipButton") as Button
		
		if view_button:
			for conn in view_button.pressed.get_connections():
				view_button.pressed.disconnect(conn.callable)
			view_button.pressed.connect(_on_spell_view_button_pressed.bind(spell_id))
		
		if equip_button:
			if is_misc:
				equip_button.visible = false
			else:
				equip_button.visible = true
				for conn in equip_button.pressed.get_connections():
					equip_button.pressed.disconnect(conn.callable)
				
				if spell_info.get("obtained", false):
					if spell_info.get("equipped", false):
						equip_button.text = "卸下"
					else:
						equip_button.text = "装备"
					equip_button.disabled = false
					equip_button.pressed.connect(_on_spell_equip_button_pressed.bind(spell_id))
				else:
					equip_button.text = "装备"
					equip_button.disabled = true

func _create_spell_detail_popup():
	"""创建术法详情弹窗"""
	# 清理旧的弹窗
	if spell_detail_popup:
		spell_detail_popup.cleanup()
		spell_detail_popup = null
	
	# 创建新的弹窗
	spell_detail_popup = SpellDetailPopup.new()
	if game_ui:
		spell_detail_popup.setup(game_ui)
		game_ui.add_child(spell_detail_popup)
	
	# 连接信号
	spell_detail_popup.upgrade_pressed.connect(_on_spell_upgrade_button_pressed)
	spell_detail_popup.charge_pressed.connect(_on_spell_charge_button_pressed)
	spell_detail_popup.multiplier_pressed.connect(_on_spell_multiplier_button_pressed)
	spell_detail_popup.close_pressed.connect(_on_spell_detail_close_pressed)

func _on_spell_view_button_pressed(spell_id: String):
	"""查看术法详情"""
	current_viewing_spell = spell_id
	current_multiplier_index = 0
	if spell_detail_popup:
		_update_spell_detail_popup()
		spell_detail_popup.show_popup()
	spell_viewed.emit(spell_id)

func _on_spell_equip_button_pressed(spell_id: String):
	"""装备/卸下术法"""
	var spell_info = spell_system.get_spell_info(spell_id)
	if spell_info.is_empty():
		_add_log("获取术法信息失败")
		return
	
	if spell_info.get("equipped", false):
		# 卸下
		var result = spell_system.unequip_spell(spell_id)
		if result.success:
			_add_log("卸下术法：" + spell_info.get("name", ""))
			# 卸下术法后保存术法系统
			_save_spell_system()
		else:
			_add_log(result.reason)
			return  # 卸下失败，不刷新UI
	else:
		# 装备
		var result = spell_system.equip_spell(spell_id)
		if result.success:
			_add_log("装备术法：" + spell_info.get("name", ""))
			# 装备术法后保存术法系统
			_save_spell_system()
		else:
			_add_log(result.reason)
			return  # 装备失败，不刷新UI
	
	# 刷新UI
	_init_spell_ui()

func _save_spell_system():
	if not save_manager:
		var game_manager = get_node_or_null("/root/GameManager")
		if game_manager:
			save_manager = game_manager.get_save_manager()
	
	if save_manager and save_manager.has_method("save_partial"):
		await save_manager.save_partial(["spell_system"])

func _on_spell_upgrade_button_pressed():
	"""升级术法"""
	if current_viewing_spell.is_empty() or not spell_system:
		return
	
	var result = spell_system.upgrade_spell(current_viewing_spell)
	if result.success:
		_add_log("术法升级成功！")
		_update_spell_detail_popup()
		_init_spell_ui()
		spell_upgraded.emit(current_viewing_spell)
	else:
		_add_log("升级失败：" + result.reason)

func _on_spell_detail_close_pressed():
	"""关闭术法详情弹窗"""
	if spell_detail_popup:
		spell_detail_popup.hide_popup()
	current_viewing_spell = ""



func _on_spell_charge_button_pressed():
	"""充入灵气"""
	if current_viewing_spell.is_empty() or not spell_system:
		return
	
	var multiplier = MULTIPLIERS[current_multiplier_index]
	var result = spell_system.charge_spell_spirit(current_viewing_spell, multiplier)
	if result.success:
		_update_spell_detail_popup()
		if game_ui and game_ui.has_method("update_ui"):
			game_ui.update_ui()
	else:
		_add_log("充灵失败：" + result.reason)

func _on_spell_multiplier_button_pressed():
	"""切换倍数"""
	current_multiplier_index = (current_multiplier_index + 1) % MULTIPLIERS.size()
	_update_spell_detail_popup()

func _update_spell_detail_popup():
	"""更新术法详情弹窗"""
	if not spell_detail_popup or current_viewing_spell.is_empty():
		return
	
	if not spell_system or not spell_system.spell_data:
		return
	
	var spell_info = spell_system.get_spell_info(current_viewing_spell)
	if spell_info.is_empty():
		return
	
	var spell_config = spell_system.spell_data.get_spell_data(current_viewing_spell)
	
	# 使用SpellDetailPopup的update_content方法更新内容
	spell_detail_popup.update_content(spell_info, spell_config, spell_system, spell_system.spell_data, current_multiplier_index, MULTIPLIERS)

func _update_use_count_label_only():
	"""只更新使用次数label（用于实时更新，避免重绘整个弹窗）"""
	if not spell_detail_popup or current_viewing_spell.is_empty():
		return
	
	if not spell_system or not spell_system.spell_data:
		return
	
	var spell_info = spell_system.get_spell_info(current_viewing_spell)
	if spell_info.is_empty():
		return
	
	# 使用SpellDetailPopup的update_use_count_only方法
	spell_detail_popup.update_use_count_only(spell_info, spell_system.spell_data)

func _get_attribute_name(attr: String) -> String:
	"""获取属性名称"""
	match attr:
		"attack": return "攻击力"
		"defense": return "防御力"
		"health": return "气血值"
		"spirit_gain": return "灵气获取"
		"speed": return "速度"
		_: return attr

func _format_spell_number(value: float) -> String:
	"""格式化术法数值"""
	if value == int(value):
		return str(int(value))
	return str(value)

func _format_spell_percent(value: float) -> String:
	"""格式化百分比"""
	var percent = value * 100
	if percent == int(percent):
		return str(int(percent)) + "%"
	var result = "%.2f" % percent
	result = result.replace(".00", "")
	if result.ends_with("0") and result.find(".") != -1:
		result = result.substr(0, result.length() - 1)
	return result + "%"

func _format_effect_description(description: String, effect: Dictionary) -> String:
	"""格式化效果描述"""
	# 替换description中的占位符
	var result = description
	
	# 通用占位符替换
	for key in effect.keys():
		var value = effect[key]
		var placeholder = "{" + key + "}"
		if result.find(placeholder) != -1:
			# 根据值类型格式化
			var formatted_value = str(value)
			if key.find("percent") != -1 or key.find("chance") != -1:
				# 百分比值/概率值 - 自动*100并添加%符号
				# 统一规范：数值都用小数存储（如0.25表示25%）
				var percent_value = value * 100.0
				# 使用is_equal_approx避免浮点数精度问题
				if is_equal_approx(percent_value, round(percent_value)):
					formatted_value = str(int(round(percent_value))) + "%"
				else:
					formatted_value = "%.1f" % percent_value + "%"
			elif key.find("value") != -1:
				# 固定值
				formatted_value = _format_spell_number(value)
			elif key == "efficiency":
				# 效率倍数
				formatted_value = _format_spell_number(value)
			elif key == "heal_percent":
				# 治疗百分比（如0.002表示0.2%）
				var percent_value = value * 100.0
				if percent_value == int(percent_value):
					formatted_value = str(int(percent_value)) + "%"
				else:
					formatted_value = "%.2f" % percent_value + "%"
			result = result.replace(placeholder, formatted_value)
	
	return result

func _add_log(message: String):
	"""添加日志（通过信号）"""
	log_message.emit(message)

# 公共接口
## 获取当前查看的术法ID
func get_current_viewing_spell() -> String:
	return current_viewing_spell

## 刷新术法UI
func refresh_spell_ui():
	_init_spell_ui()

## 处理术法使用（供外部调用）
func on_spell_used(spell_id: String):
	if current_viewing_spell == spell_id:
		_update_use_count_label_only()