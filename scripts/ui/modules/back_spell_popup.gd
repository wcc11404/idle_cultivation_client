class_name SpellDetailPopup extends Panel

## 术法详情弹窗 - 独立管理弹窗UI
## 负责显示术法详细信息、升级条件、充灵操作等

# 信号
signal upgrade_pressed
signal charge_pressed
signal multiplier_pressed
signal close_pressed

# UI节点引用
var background: ColorRect = null
var vbox: VBoxContainer = null

# 按钮引用（用于外部更新）
var charge_button: Button = null
var multiplier_button: Button = null
var upgrade_button: Button = null

# 常量
const MULTIPLIER_LABELS = ["x10", "x100", "Max"]

func _init():
	name = "SpellDetailPopup"
	visible = false
	z_index = 100
	custom_minimum_size = Vector2(400, 550)

func setup(parent_node: Node):
	"""初始化弹窗，创建所有UI元素"""
	_create_background(parent_node)
	_create_popup_content()

func _create_background(parent_node: Node):
	"""创建背景遮罩层"""
	background = ColorRect.new()
	background.name = "SpellPopupBackground"
	background.visible = false
	background.z_index = 99
	background.color = Color(0, 0, 0, 0.3)
	background.layout_mode = 1
	background.anchors_preset = 15  # PRESET_FULL_RECT
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	background.grow_horizontal = 2  # GROW_DIRECTION_BOTH
	background.grow_vertical = 2  # GROW_DIRECTION_BOTH
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	background.gui_input.connect(_on_background_clicked)
	
	if parent_node:
		parent_node.add_child(background)

func _create_popup_content():
	"""创建弹窗内容"""
	# 设置布局为居中
	layout_mode = 1
	anchors_preset = 8  # PRESET_CENTER
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -200.0
	offset_top = -275.0
	offset_right = 200.0
	offset_bottom = 275.0
	grow_horizontal = 2  # GROW_DIRECTION_BOTH
	grow_vertical = 2  # GROW_DIRECTION_BOTH
	
	vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.layout_mode = 1
	vbox.anchors_preset = 15  # PRESET_FULL_RECT
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 20.0
	vbox.offset_top = 20.0
	vbox.offset_right = -20.0
	vbox.offset_bottom = -20.0
	vbox.grow_horizontal = 2  # GROW_DIRECTION_BOTH
	vbox.grow_vertical = 2  # GROW_DIRECTION_BOTH
	add_child(vbox)
	
	# 标题
	var title = Label.new()
	title.name = "TitleLabel"
	title.text = "术法详情"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# 类型
	var type_label = Label.new()
	type_label.name = "TypeLabel"
	type_label.text = "类型："
	vbox.add_child(type_label)
	
	# 等级
	var level_label = Label.new()
	level_label.name = "LevelLabel"
	level_label.text = "等级："
	vbox.add_child(level_label)
	
	# 分隔线
	vbox.add_child(_create_thick_separator())
	
	# 属性加成
	var attr_title = Label.new()
	attr_title.text = "【属性加成】"
	vbox.add_child(attr_title)
	
	var attr_value = Label.new()
	attr_value.name = "AttributeValue"
	attr_value.text = ""
	vbox.add_child(attr_value)
	
	# 分隔线
	vbox.add_child(_create_thick_separator())
	
	# 术法效果
	var effect_title = Label.new()
	effect_title.text = "【术法效果】"
	vbox.add_child(effect_title)
	
	var effect_value = Label.new()
	effect_value.name = "EffectValue"
	effect_value.text = ""
	effect_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(effect_value)
	
	# 分隔线
	vbox.add_child(_create_thick_separator())
	
	# 升级条件
	var upgrade_title = Label.new()
	upgrade_title.text = "【升级条件】"
	vbox.add_child(upgrade_title)
	
	var max_level_label = Label.new()
	max_level_label.name = "MaxLevelLabel"
	max_level_label.text = "已达到最高等级"
	max_level_label.visible = false
	vbox.add_child(max_level_label)
	
	var use_count_label = Label.new()
	use_count_label.name = "UseCountLabel"
	use_count_label.text = "使用次数："
	vbox.add_child(use_count_label)
	
	# 灵气充入容器
	var spirit_charge_container = HBoxContainer.new()
	spirit_charge_container.name = "SpiritChargeContainer"
	spirit_charge_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	spirit_charge_container.add_theme_constant_override("separation", 8)
	vbox.add_child(spirit_charge_container)
	
	var spirit_charge_label = Label.new()
	spirit_charge_label.name = "SpiritChargeLabel"
	spirit_charge_label.text = "所需灵气："
	spirit_charge_container.add_child(spirit_charge_label)
	
	var spirit_amount_label = Label.new()
	spirit_amount_label.name = "SpiritAmountLabel"
	spirit_amount_label.text = "0/0"
	spirit_charge_container.add_child(spirit_amount_label)
	
	charge_button = Button.new()
	charge_button.name = "ChargeButton"
	charge_button.text = "+"
	charge_button.pressed.connect(func(): charge_pressed.emit())
	spirit_charge_container.add_child(charge_button)
	
	multiplier_button = Button.new()
	multiplier_button.name = "MultiplierButton"
	multiplier_button.text = "x10"
	multiplier_button.pressed.connect(func(): multiplier_pressed.emit())
	spirit_charge_container.add_child(multiplier_button)
	
	# 占位
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	
	# 按钮容器
	var button_container = HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(button_container)
	
	# 升级按钮
	upgrade_button = Button.new()
	upgrade_button.name = "UpgradeButton"
	upgrade_button.text = "升级"
	upgrade_button.pressed.connect(func(): upgrade_pressed.emit())
	button_container.add_child(upgrade_button)
	
	# 关闭按钮
	var close_button = Button.new()
	close_button.text = "关闭"
	close_button.pressed.connect(func(): close_pressed.emit())
	button_container.add_child(close_button)

func show_popup():
	"""显示弹窗"""
	if background:
		background.visible = true
	visible = true

func hide_popup():
	"""隐藏弹窗"""
	if background:
		background.visible = false
	visible = false

func is_popup_visible() -> bool:
	"""检查弹窗是否可见"""
	return visible

func update_content(spell_info: Dictionary, spell_config: Dictionary, 
					spell_system: Node, spell_data: Node, 
					multiplier_index: int, multipliers: Array):
	"""更新弹窗内容"""
	if not vbox:
		return
	
	# 更新标题
	var title_label = vbox.get_node_or_null("TitleLabel")
	if title_label:
		title_label.text = spell_info.get("name", "")
	
	# 更新类型
	var type_label = vbox.get_node_or_null("TypeLabel")
	if type_label:
		type_label.text = "类型：" + spell_info.get("type_name", "")
	
	# 更新等级
	var level_label = vbox.get_node_or_null("LevelLabel")
	if level_label:
		level_label.text = "等级：" + str(spell_info.get("level", 0)) + "/" + str(spell_info.get("max_level", 3))
	
	# 获取当前等级数据
	var current_level = spell_info.get("level", 0)
	if current_level <= 0:
		current_level = 1
	var level_data = spell_data.get_spell_level_data(spell_info.get("id", ""), current_level) if spell_data else {}
	
	# 更新属性加成
	_update_attribute_value(level_data)
	
	# 更新术法效果
	_update_effect_value(spell_config, level_data)
	
	# 更新升级条件
	_update_upgrade_conditions(spell_info, spell_data, multiplier_index, multipliers)

func _update_attribute_value(level_data: Dictionary):
	"""更新属性加成显示"""
	var attr_value = vbox.get_node_or_null("AttributeValue")
	if not attr_value:
		return
	
	var attr_bonus = level_data.get("attribute_bonus", {})
	var attr_text = ""
	for attr in attr_bonus.keys():
		var value = attr_bonus[attr]
		if attr == "speed":
			attr_text += "速度 +" + str(value) + "\n"
		else:
			attr_text += _get_attribute_name(attr) + " ×" + str(value) + "\n"
	attr_value.text = attr_text

func _update_effect_value(spell_config: Dictionary, level_data: Dictionary):
	"""更新术法效果显示"""
	var effect_value = vbox.get_node_or_null("EffectValue")
	if not effect_value:
		return
	
	var effect = level_data.get("effect", {})
	var description = spell_config.get("description", "")
	effect_value.text = _format_effect_description(description, effect)

func _update_upgrade_conditions(spell_info: Dictionary, spell_data: Node, 
								multiplier_index: int, multipliers: Array):
	"""更新升级条件显示"""
	var max_level_label = vbox.get_node_or_null("MaxLevelLabel")
	var use_count_label = vbox.get_node_or_null("UseCountLabel")
	var spirit_charge_container = vbox.get_node_or_null("SpiritChargeContainer")
	
	var current_level = spell_info.get("level", 0)
	var max_level = spell_info.get("max_level", 3)
	
	if current_level <= 0:
		if max_level_label:
			max_level_label.visible = false
		if use_count_label:
			use_count_label.visible = true
			use_count_label.text = "使用次数：-/-"
		if spirit_charge_container:
			spirit_charge_container.visible = true
			var spirit_amount_label = spirit_charge_container.get_node_or_null("SpiritAmountLabel")
			if spirit_amount_label:
				spirit_amount_label.text = "-/-"
		_set_buttons_enabled(false, multiplier_index)
	elif current_level >= max_level:
		if max_level_label:
			max_level_label.visible = true
		if use_count_label:
			use_count_label.visible = false
		if spirit_charge_container:
			spirit_charge_container.visible = false
		_set_buttons_enabled(false, multiplier_index)
	else:
		if max_level_label:
			max_level_label.visible = false
		if use_count_label:
			use_count_label.visible = true
		if spirit_charge_container:
			spirit_charge_container.visible = true
		
		var current_level_data = spell_data.get_spell_level_data(spell_info.get("id", ""), current_level) if spell_data else {}
		var use_count_required = current_level_data.get("use_count_required", 0)
		var spirit_cost = current_level_data.get("spirit_cost", 0)
		var charged_spirit = spell_info.get("charged_spirit", 0)
		
		if use_count_label:
			use_count_label.text = "使用次数：" + str(spell_info.get("use_count", 0)) + "/" + str(use_count_required)
		if spirit_charge_container:
			var spirit_amount_label = spirit_charge_container.get_node_or_null("SpiritAmountLabel")
			if spirit_amount_label:
				spirit_amount_label.text = str(charged_spirit) + "/" + str(spirit_cost)
		
		_set_buttons_enabled(true, multiplier_index)

func _set_buttons_enabled(enabled: bool, multiplier_index: int):
	"""设置按钮状态"""
	if charge_button:
		charge_button.disabled = not enabled
	if multiplier_button:
		multiplier_button.disabled = not enabled
		multiplier_button.text = MULTIPLIER_LABELS[multiplier_index] if multiplier_index < MULTIPLIER_LABELS.size() else "x10"
	if upgrade_button:
		upgrade_button.disabled = not enabled

func update_use_count_only(spell_info: Dictionary, spell_data: Node):
	"""只更新使用次数（用于实时更新）"""
	var max_level_label = vbox.get_node_or_null("MaxLevelLabel")
	var use_count_label = vbox.get_node_or_null("UseCountLabel")
	if not use_count_label:
		return
	
	var current_level = spell_info.get("level", 0)
	var max_level = spell_info.get("max_level", 3)
	
	if current_level <= 0:
		if max_level_label:
			max_level_label.visible = false
		use_count_label.visible = true
		use_count_label.text = "使用次数：-/-"
	elif current_level >= max_level:
		if max_level_label:
			max_level_label.visible = true
		use_count_label.visible = false
	else:
		if max_level_label:
			max_level_label.visible = false
		use_count_label.visible = true
		var current_level_data = spell_data.get_spell_level_data(spell_info.get("id", ""), current_level) if spell_data else {}
		var use_count_required = current_level_data.get("use_count_required", 0)
		use_count_label.text = "使用次数：" + str(spell_info.get("use_count", 0)) + "/" + str(use_count_required)
	
	use_count_label.queue_redraw()

func _on_background_clicked(event: InputEvent):
	"""点击背景关闭弹窗"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_pressed.emit()

func cleanup():
	"""清理资源"""
	if background:
		background.queue_free()
		background = null
	queue_free()

# ==================== 辅助函数 ====================

func _get_attribute_name(attr: String) -> String:
	match attr:
		"attack": return "攻击力"
		"defense": return "防御力"
		"health": return "气血值"
		"spirit_gain": return "灵气获取"
		"speed": return "速度"
		"max_spirit": return "最大灵气"
		_: return attr

func _format_spell_number(value: float) -> String:
	if value == int(value):
		return str(int(value))
	return str(value)

func _format_spell_percent(value: float) -> String:
	var percent = value * 100
	if percent == int(percent):
		return str(int(percent)) + "%"
	var result = "%.2f" % percent
	result = result.replace(".00", "")
	if result.ends_with("0") and result.find(".") != -1:
		result = result.substr(0, result.length() - 1)
	return result + "%"

func _format_effect_description(description: String, effect: Dictionary) -> String:
	var result = description
	
	for key in effect.keys():
		var value = effect[key]
		var placeholder = "{" + key + "}"
		if result.find(placeholder) != -1:
			var formatted_value = str(value)
			if key.find("percent") != -1 or key.find("chance") != -1:
				var percent_value = value * 100.0
				if is_equal_approx(percent_value, round(percent_value)):
					formatted_value = str(int(round(percent_value))) + "%"
				else:
					formatted_value = "%.1f" % percent_value + "%"
			elif key == "speed_rate":
				var percent_value = value * 100.0
				if is_equal_approx(percent_value, round(percent_value)):
					formatted_value = str(int(round(percent_value)))
				else:
					formatted_value = "%.1f" % percent_value
			elif key.find("value") != -1:
				formatted_value = _format_spell_number(value)
			elif key == "efficiency":
				formatted_value = _format_spell_number(value)
			elif key == "heal_percent":
				var percent_value = value * 100.0
				if percent_value == int(percent_value):
					formatted_value = str(int(percent_value)) + "%"
				else:
					formatted_value = "%.2f" % percent_value + "%"
			result = result.replace(placeholder, formatted_value)
	
	return result

func _create_thick_separator() -> HSeparator:
	"""创建粗分割线，使其在不同分辨率下都能清晰显示"""
	var separator = HSeparator.new()
	var separator_style = StyleBoxLine.new()
	separator_style.color = Color(0.5, 0.5, 0.5, 0.5)
	separator_style.thickness = 2
	separator.add_theme_stylebox_override("separator", separator_style)
	return separator