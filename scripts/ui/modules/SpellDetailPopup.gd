class_name SpellDetailPopup extends Panel

const PopupStyleTemplate = preload("res://scripts/ui/common/PopupStyleTemplate.gd")
const ActionButtonTemplate = preload("res://scripts/ui/common/ActionButtonTemplate.gd")
const SafeAreaHelper = preload("res://scripts/ui/common/SafeAreaHelper.gd")

## 术法详情弹窗 - 独立管理弹窗UI
## 负责显示术法详细信息、升级条件、充灵操作等

# 信号
signal upgrade_requested
signal charge_requested
signal multiplier_changed
signal close_requested

# UI节点引用
var background: ColorRect = null
var vbox: VBoxContainer = null

# 按钮引用（用于外部更新）
var charge_button: Button = null
var multiplier_button: Button = null
var upgrade_button: Button = null
var close_button: Button = null
var overlay_host: Control = null

# 常量
const MULTIPLIER_LABELS = ["x10", "x100", "Max"]

func _init():
	name = "SpellDetailPopup"
	visible = false
	z_index = 100
	set_process_input(true)

func setup(parent_node: Node):
	"""初始化弹窗，创建所有UI元素"""
	if parent_node is Control:
		overlay_host = parent_node
	else:
		overlay_host = get_tree().current_scene as Control
	_create_background()
	_create_popup_content()
	_apply_popup_theme()
	if get_viewport():
		get_viewport().size_changed.connect(_on_viewport_size_changed)

func _create_background():
	"""创建背景遮罩层"""
	if not overlay_host:
		return
	background = PopupStyleTemplate.create_overlay(self, Callable(), 0.62)
	background.name = "SpellPopupBackground"
	overlay_host.add_child(background)

func _input(event: InputEvent) -> void:
	# 当弹窗显示时：点击外部关闭，点击内部不关闭
	if not visible:
		return
	if not (event is InputEventMouseButton):
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var mouse_event := event as InputEventMouseButton
	if get_global_rect().has_point(mouse_event.position):
		return
	close_requested.emit()
	get_viewport().set_input_as_handled()

func _create_popup_content():
	"""创建弹窗内容"""
	layout_mode = 1
	anchors_preset = 0
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0
	position = Vector2(180.0, 180.0)
	size = Vector2(360.0, 440.0)
	mouse_filter = Control.MOUSE_FILTER_STOP  # 阻止事件传递到背景
	
	vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.layout_mode = 1
	vbox.anchors_preset = 15
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 20.0
	vbox.offset_top = 20.0
	vbox.offset_right = -20.0
	vbox.offset_bottom = -20.0
	vbox.grow_horizontal = 2
	vbox.grow_vertical = 2
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)
	
	# 标题
	var title = Label.new()
	title.name = "TitleLabel"
	title.text = "术法详情"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.22, 0.2, 0.18, 1))
	vbox.add_child(title)
	
	# 类型
	var type_label = Label.new()
	type_label.name = "TypeLabel"
	type_label.text = "类型："
	type_label.add_theme_font_size_override("font_size", 21)
	type_label.add_theme_color_override("font_color", Color(0.22, 0.2, 0.18, 1))
	vbox.add_child(type_label)
	
	# 等级
	var level_label = Label.new()
	level_label.name = "LevelLabel"
	level_label.text = "等级："
	level_label.add_theme_font_size_override("font_size", 21)
	level_label.add_theme_color_override("font_color", Color(0.22, 0.2, 0.18, 1))
	vbox.add_child(level_label)
	
	# 分隔线
	vbox.add_child(_create_section_gap(4))
	vbox.add_child(_create_thick_separator())
	vbox.add_child(_create_section_gap(2))
	
	# 属性加成
	var attr_title = Label.new()
	attr_title.name = "AttrTitleLabel"
	attr_title.text = "【属性加成】"
	attr_title.add_theme_font_size_override("font_size", 23)
	attr_title.add_theme_color_override("font_color", Color(0.24, 0.22, 0.19, 1))
	vbox.add_child(attr_title)
	
	var attr_value = Label.new()
	attr_value.name = "AttributeValue"
	attr_value.text = ""
	attr_value.add_theme_font_size_override("font_size", 19)
	attr_value.add_theme_color_override("font_color", Color(0.24, 0.22, 0.19, 1))
	vbox.add_child(attr_value)
	
	# 分隔线
	vbox.add_child(_create_section_gap(4))
	vbox.add_child(_create_thick_separator())
	vbox.add_child(_create_section_gap(2))
	
	# 术法效果
	var effect_title = Label.new()
	effect_title.name = "EffectTitleLabel"
	effect_title.text = "【术法效果】"
	effect_title.add_theme_font_size_override("font_size", 23)
	effect_title.add_theme_color_override("font_color", Color(0.24, 0.22, 0.19, 1))
	vbox.add_child(effect_title)
	
	var effect_value = Label.new()
	effect_value.name = "EffectValue"
	effect_value.text = ""
	effect_value.add_theme_font_size_override("font_size", 19)
	effect_value.add_theme_color_override("font_color", Color(0.24, 0.22, 0.19, 1))
	effect_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(effect_value)
	
	# 分隔线
	vbox.add_child(_create_section_gap(4))
	vbox.add_child(_create_thick_separator())
	vbox.add_child(_create_section_gap(2))
	
	# 升级条件
	var upgrade_title = Label.new()
	upgrade_title.name = "UpgradeTitleLabel"
	upgrade_title.text = "【升级条件】"
	upgrade_title.add_theme_font_size_override("font_size", 23)
	upgrade_title.add_theme_color_override("font_color", Color(0.24, 0.22, 0.19, 1))
	vbox.add_child(upgrade_title)
	
	var max_level_label = Label.new()
	max_level_label.name = "MaxLevelLabel"
	max_level_label.text = "已达到最高等级"
	max_level_label.add_theme_font_size_override("font_size", 19)
	max_level_label.add_theme_color_override("font_color", Color(0.5, 0.18, 0.16, 1))
	max_level_label.visible = false
	vbox.add_child(max_level_label)

	var upgrade_conditions_box = VBoxContainer.new()
	upgrade_conditions_box.name = "UpgradeConditionsBox"
	upgrade_conditions_box.alignment = BoxContainer.ALIGNMENT_CENTER
	upgrade_conditions_box.add_theme_constant_override("separation", 8)
	vbox.add_child(upgrade_conditions_box)

	var use_count_row = HBoxContainer.new()
	use_count_row.name = "UseCountRow"
	use_count_row.alignment = BoxContainer.ALIGNMENT_CENTER
	use_count_row.add_theme_constant_override("separation", 16)
	upgrade_conditions_box.add_child(use_count_row)

	var use_count_label = Label.new()
	use_count_label.name = "UseCountLabel"
	use_count_label.text = "使用次数："
	use_count_label.custom_minimum_size = Vector2(120, 0)
	use_count_label.add_theme_font_size_override("font_size", 19)
	use_count_label.add_theme_color_override("font_color", Color(0.24, 0.22, 0.19, 1))
	use_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	use_count_row.add_child(use_count_label)

	var use_count_value_label = Label.new()
	use_count_value_label.name = "UseCountValueLabel"
	use_count_value_label.text = "0 / 0"
	use_count_value_label.custom_minimum_size = Vector2(72, 0)
	use_count_value_label.add_theme_font_size_override("font_size", 19)
	use_count_value_label.add_theme_color_override("font_color", Color(0.24, 0.22, 0.19, 1))
	use_count_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	use_count_row.add_child(use_count_value_label)

	var use_count_empty_container = Control.new()
	use_count_empty_container.name = "UseCountEmptyContainer"
	use_count_empty_container.custom_minimum_size = Vector2(118, 0)
	use_count_row.add_child(use_count_empty_container)

	var spirit_charge_row = HBoxContainer.new()
	spirit_charge_row.name = "SpiritChargeRow"
	spirit_charge_row.alignment = BoxContainer.ALIGNMENT_CENTER
	spirit_charge_row.add_theme_constant_override("separation", 16)
	upgrade_conditions_box.add_child(spirit_charge_row)

	var spirit_charge_label = Label.new()
	spirit_charge_label.name = "SpiritChargeLabel"
	spirit_charge_label.text = "所需灵气："
	spirit_charge_label.custom_minimum_size = Vector2(120, 0)
	spirit_charge_label.add_theme_font_size_override("font_size", 19)
	spirit_charge_label.add_theme_color_override("font_color", Color(0.24, 0.22, 0.19, 1))
	spirit_charge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spirit_charge_row.add_child(spirit_charge_label)

	var spirit_amount_label = Label.new()
	spirit_amount_label.name = "SpiritAmountLabel"
	spirit_amount_label.text = "0 / 0"
	spirit_amount_label.custom_minimum_size = Vector2(72, 0)
	spirit_amount_label.add_theme_font_size_override("font_size", 19)
	spirit_amount_label.add_theme_color_override("font_color", Color(0.24, 0.22, 0.19, 1))
	spirit_amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spirit_charge_row.add_child(spirit_amount_label)

	var spirit_action_container = HBoxContainer.new()
	spirit_action_container.name = "SpiritActionContainer"
	spirit_action_container.custom_minimum_size = Vector2(118, 0)
	spirit_action_container.alignment = BoxContainer.ALIGNMENT_CENTER
	spirit_action_container.add_theme_constant_override("separation", 8)
	spirit_charge_row.add_child(spirit_action_container)

	charge_button = Button.new()
	charge_button.name = "ChargeButton"
	charge_button.text = "+"
	charge_button.custom_minimum_size = Vector2(48, 42)
	charge_button.add_theme_font_size_override("font_size", 24)
	charge_button.pressed.connect(func(): charge_requested.emit())
	spirit_action_container.add_child(charge_button)

	multiplier_button = Button.new()
	multiplier_button.name = "MultiplierButton"
	multiplier_button.text = "x10"
	multiplier_button.custom_minimum_size = Vector2(62, 42)
	multiplier_button.add_theme_font_size_override("font_size", 22)
	multiplier_button.pressed.connect(func(): multiplier_changed.emit())
	spirit_action_container.add_child(multiplier_button)
	
	# 轻量留白（避免使用 EXPAND_FILL 把弹窗高度异常撑大）
	vbox.add_child(_create_section_gap(8))
	
	# 按钮容器
	var button_container = HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_theme_constant_override("separation", 10)
	vbox.add_child(button_container)
	
	# 升级按钮
	upgrade_button = Button.new()
	upgrade_button.name = "UpgradeButton"
	upgrade_button.text = "升级"
	upgrade_button.custom_minimum_size = Vector2(124, 46)
	upgrade_button.add_theme_font_size_override("font_size", 22)
	upgrade_button.pressed.connect(func(): upgrade_requested.emit())
	button_container.add_child(upgrade_button)
	
	# 关闭按钮
	close_button = Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(124, 46)
	close_button.add_theme_font_size_override("font_size", 22)
	close_button.pressed.connect(func(): close_requested.emit())
	button_container.add_child(close_button)

func _apply_popup_theme():
	add_theme_stylebox_override("panel", PopupStyleTemplate.build_panel_style({
		"bg_color": PopupStyleTemplate.POPUP_BG_COLOR,
		"border_color": PopupStyleTemplate.POPUP_BORDER_COLOR,
		"corner_radius": 12,
		"border_width": 2
	}))
	_apply_action_button_styles()

func _apply_action_button_styles():
	if charge_button:
		ActionButtonTemplate.apply_spell_view_brown(charge_button, charge_button.custom_minimum_size, 24)
	if multiplier_button:
		ActionButtonTemplate.apply_spell_view_brown(multiplier_button, multiplier_button.custom_minimum_size, 22)
	if upgrade_button:
		ActionButtonTemplate.apply_cultivation_yellow(upgrade_button, upgrade_button.custom_minimum_size, 22)
	if close_button:
		ActionButtonTemplate.apply_breakthrough_red(close_button, close_button.custom_minimum_size, 22)

func show_popup():
	"""显示弹窗"""
	if background:
		background.z_index = z_index - 1
		background.visible = true
	visible = true
	_update_popup_layout()
	# 首次显示时等一帧再二次布局，避免初次高度异常
	call_deferred("_update_popup_layout")

func _on_viewport_size_changed():
	if visible:
		_update_popup_layout()

func _update_popup_layout():
	if not vbox:
		return
	# 基于内容和屏幕动态计算弹窗尺寸，避免写死宽高导致比例异常
	var safe_rect := SafeAreaHelper.get_safe_inner_rect(self)
	var viewport_size = safe_rect.size
	var content_min_size = vbox.get_combined_minimum_size()
	var popup_width = clamp(content_min_size.x + 40.0, 360.0, max(360.0, viewport_size.x - 40.0))
	# 高度上限按屏幕 82%，并且不让无意义留白撑高
	var max_height = max(420.0, floor(viewport_size.y * 0.82))
	var popup_height = clamp(content_min_size.y + 34.0, 420.0, max_height)
	var popup_pos := safe_rect.position + (safe_rect.size - Vector2(popup_width, popup_height)) * 0.5
	position = popup_pos
	size = Vector2(popup_width, popup_height)

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
		title_label.text = spell_config.get("name", "")
	
	# 更新类型
	var type_label = vbox.get_node_or_null("TypeLabel")
	if type_label:
		var type_str = spell_config.get("type", "active")
		var type_name = spell_data.get_spell_type_name(type_str) if spell_data else type_str
		type_label.text = "类型：" + type_name
	
	# 更新等级
	var level_label = vbox.get_node_or_null("LevelLabel")
	if level_label:
		var current_level = int(spell_info.get("level", 0))
		var max_level = int(spell_config.get("max_level", 3))
		level_label.text = "等级：%s（%d / %d）" % [_format_level_tier_name(current_level), current_level, max_level]
	
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
	_update_upgrade_conditions(spell_info, spell_config, spell_data, multiplier_index, multipliers)

func _update_attribute_value(level_data: Dictionary):
	"""更新属性加成显示"""
	var attr_value = vbox.get_node_or_null("AttributeValue")
	if not attr_value:
		return
	
	var attr_bonus = level_data.get("attribute_bonus", {})
	var attr_text = ""
	var keys = attr_bonus.keys()
	for i in range(keys.size()):
		var attr = keys[i]
		var value = attr_bonus[attr]
		if attr == "speed":
			attr_text += "速度 +" + UIUtils.format_display_number(float(value))
		else:
			attr_text += _get_attribute_name(attr) + " ×" + UIUtils.format_display_number(float(value))
		if i < keys.size() - 1:
			attr_text += "\n"
	attr_value.text = attr_text

func _update_effect_value(spell_config: Dictionary, level_data: Dictionary):
	"""更新术法效果显示"""
	var effect_value = vbox.get_node_or_null("EffectValue")
	if not effect_value:
		return
	
	var effect = level_data.get("effect", {})
	var description = spell_config.get("description", "")
	effect_value.text = _format_effect_description(description, effect)

func _update_upgrade_conditions(spell_info: Dictionary, spell_config: Dictionary, spell_data: Node, 
								multiplier_index: int, multipliers: Array):
	"""更新升级条件显示"""
	var max_level_label = vbox.get_node_or_null("MaxLevelLabel")
	var use_count_container = vbox.get_node_or_null("UseCountRow")
	var use_count_value_label = vbox.get_node_or_null("UseCountRow/UseCountValueLabel")
	var spirit_charge_container = vbox.get_node_or_null("SpiritChargeRow")
	var spirit_action_container = vbox.get_node_or_null("SpiritActionContainer")
	
	var current_level = spell_info.get("level", 0)
	var max_level = int(spell_config.get("max_level", 3))
	
	if current_level <= 0:
		if max_level_label:
			max_level_label.visible = false
		if use_count_container:
			use_count_container.visible = true
		if use_count_value_label:
			use_count_value_label.text = "- / -"
		if spirit_charge_container:
			spirit_charge_container.visible = true
			var spirit_amount_label = vbox.get_node_or_null("SpiritChargeRow/SpiritAmountLabel")
			if spirit_amount_label:
				spirit_amount_label.text = "- / -"
		if spirit_action_container:
			spirit_action_container.visible = true
		_set_buttons_enabled(false, multiplier_index)
	elif current_level >= max_level:
		if max_level_label:
			max_level_label.visible = true
		if use_count_container:
			use_count_container.visible = false
		if spirit_charge_container:
			spirit_charge_container.visible = false
		if spirit_action_container:
			spirit_action_container.visible = false
		_set_buttons_enabled(false, multiplier_index)
	else:
		if max_level_label:
			max_level_label.visible = false
		if use_count_container:
			use_count_container.visible = true
		if spirit_charge_container:
			spirit_charge_container.visible = true
		if spirit_action_container:
			spirit_action_container.visible = true
		
		var current_level_data = spell_data.get_spell_level_data(spell_info.get("id", ""), current_level) if spell_data else {}
		var use_count_required = int(current_level_data.get("use_count_required", 0))
		var spirit_cost = int(current_level_data.get("spirit_cost", 0))
		var charged_spirit = int(spell_info.get("charged_spirit", 0))
		
		if use_count_value_label:
			use_count_value_label.text = UIUtils.format_display_number(float(spell_info.get("use_count", 0))) + " / " + UIUtils.format_display_number(float(use_count_required))
		if spirit_charge_container:
			var spirit_amount_label = vbox.get_node_or_null("SpiritChargeRow/SpiritAmountLabel")
			if spirit_amount_label:
				spirit_amount_label.text = UIUtils.format_display_number(float(charged_spirit)) + " / " + UIUtils.format_display_number(float(spirit_cost))
		
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

func update_use_count_only(spell_info: Dictionary, spell_config: Dictionary, spell_data: Node):
	"""只更新使用次数（用于实时更新）"""
	var max_level_label = vbox.get_node_or_null("MaxLevelLabel")
	var use_count_container = vbox.get_node_or_null("UseCountContainer")
	var use_count_value_label = vbox.get_node_or_null("UseCountContainer/UseCountValueLabel")
	if not use_count_container or not use_count_value_label:
		return
	
	var current_level = spell_info.get("level", 0)
	var max_level = int(spell_config.get("max_level", 3))
	
	if current_level <= 0:
		if max_level_label:
			max_level_label.visible = false
		use_count_container.visible = true
		use_count_value_label.text = "- / -"
	elif current_level >= max_level:
		if max_level_label:
			max_level_label.visible = true
		use_count_container.visible = false
	else:
		if max_level_label:
			max_level_label.visible = false
		use_count_container.visible = true
		var current_level_data = spell_data.get_spell_level_data(spell_info.get("id", ""), current_level) if spell_data else {}
		var use_count_required = int(current_level_data.get("use_count_required", 0))
		use_count_value_label.text = UIUtils.format_display_number(float(spell_info.get("use_count", 0))) + " / " + UIUtils.format_display_number(float(use_count_required))
	
	use_count_value_label.queue_redraw()
	
	if current_level > 0 and current_level < max_level:
		_set_buttons_enabled(true, 0)

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
	return UIUtils.format_display_number(value)

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

func _format_level_tier_name(level: int) -> String:
	var names = ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
	if level >= 1 and level < names.size():
		return names[level] + "重"
	if level == 10:
		return "十重"
	return str(level) + "重"

func _create_thick_separator() -> HSeparator:
	"""创建粗分割线，使其在不同分辨率下都能清晰显示"""
	var separator = HSeparator.new()
	var separator_style = StyleBoxLine.new()
	separator_style.color = Color(0.66, 0.6, 0.5, 0.55)
	separator_style.thickness = 2
	separator.add_theme_stylebox_override("separator", separator_style)
	separator.custom_minimum_size = Vector2(0, 6)
	return separator

func _create_section_gap(height: int) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, float(max(0, height)))
	return spacer
