class_name ProfileEditPopup extends Panel

const POPUP_STYLE_TEMPLATE = preload("res://scripts/ui/common/PopupStyleTemplate.gd")
const ACTION_BUTTON_TEMPLATE = preload("res://scripts/ui/common/ActionButtonTemplate.gd")
const ACCOUNT_CONFIG_SCRIPT = preload("res://scripts/core/account/AccountConfig.gd")
const SAFE_AREA_HELPER = preload("res://scripts/ui/common/SafeAreaHelper.gd")

signal nickname_submit_requested(new_nickname: String)
signal avatar_submit_requested(avatar_id: String)
signal popup_closed

const COLOR_PANEL_BG := Color(0.917647, 0.854902, 0.72549, 1.0) # #eadab9
const COLOR_PANEL_BORDER := Color(0.713725, 0.639216, 0.513725, 0.95)
const COLOR_TEXT_DARK := Color(0.22, 0.2, 0.18, 1.0)
const COLOR_HINT := Color(0.36, 0.31, 0.25, 1.0)

const COLOR_AVATAR_BORDER_NORMAL := Color(0.713725, 0.639216, 0.513725, 1.0)
const COLOR_AVATAR_BORDER_SELECTED := Color(0.870588, 0.705882, 0.207843, 1.0)

var overlay_host: Control = null
var background: ColorRect = null

var nickname_input: LineEdit = null
var avatar_grid: GridContainer = null
var avatar_submit_button: Button = null

var _selected_avatar_id: String = ""
var _avatar_buttons: Dictionary = {}

func _init():
	name = "ProfileEditPopup"
	visible = false
	z_index = 1100
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process_input(true)

func setup(host: Control):
	overlay_host = host
	background = POPUP_STYLE_TEMPLATE.create_overlay(host, Callable(), 0.58)
	background.name = "ProfileEditOverlay"
	overlay_host.add_child(background)
	_build_layout()
	_apply_styles()
	if get_viewport():
		get_viewport().size_changed.connect(_on_viewport_size_changed)

func _build_layout():
	layout_mode = 1
	anchors_preset = 0
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0
	position = Vector2(120.0, 120.0)
	size = Vector2(520.0, 600.0)

	var margin = MarginContainer.new()
	margin.layout_mode = 1
	margin.anchors_preset = 15
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.grow_horizontal = 2
	margin.grow_vertical = 2
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.name = "RootVBox"
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var nickname_title = Label.new()
	nickname_title.text = "修改昵称"
	nickname_title.add_theme_font_size_override("font_size", 24)
	nickname_title.add_theme_color_override("font_color", COLOR_TEXT_DARK)
	vbox.add_child(nickname_title)

	nickname_input = LineEdit.new()
	nickname_input.custom_minimum_size = Vector2(0, 44)
	nickname_input.placeholder_text = "输入新昵称（4-10位）"
	nickname_input.add_theme_font_size_override("font_size", 20)
	vbox.add_child(nickname_input)

	var nickname_hint = Label.new()
	nickname_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nickname_hint.text = "昵称非法情况：不能为空；长度需4-10位；不能包含空格；不能全是数字；不能包含非法字符或敏感词。"
	nickname_hint.add_theme_font_size_override("font_size", 16)
	nickname_hint.add_theme_color_override("font_color", COLOR_HINT)
	vbox.add_child(nickname_hint)

	var nickname_submit_button = Button.new()
	nickname_submit_button.text = "变更昵称"
	nickname_submit_button.custom_minimum_size = Vector2(0, 42)
	nickname_submit_button.add_theme_font_size_override("font_size", 20)
	nickname_submit_button.pressed.connect(func():
		nickname_submit_requested.emit(nickname_input.text.strip_edges())
	)
	vbox.add_child(nickname_submit_button)
	ACTION_BUTTON_TEMPLATE.apply_profile_blue(nickname_submit_button, nickname_submit_button.custom_minimum_size, 20)

	var separator = HSeparator.new()
	separator.custom_minimum_size = Vector2(0, 12)
	vbox.add_child(separator)

	var avatar_title = Label.new()
	avatar_title.text = "选择头像"
	avatar_title.add_theme_font_size_override("font_size", 24)
	avatar_title.add_theme_color_override("font_color", COLOR_TEXT_DARK)
	vbox.add_child(avatar_title)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 260)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	avatar_grid = GridContainer.new()
	avatar_grid.columns = 4
	avatar_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	avatar_grid.add_theme_constant_override("h_separation", 10)
	avatar_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(avatar_grid)

	_build_avatar_grid()

	avatar_submit_button = Button.new()
	avatar_submit_button.text = "变更头像"
	avatar_submit_button.custom_minimum_size = Vector2(0, 42)
	avatar_submit_button.add_theme_font_size_override("font_size", 20)
	avatar_submit_button.pressed.connect(func():
		avatar_submit_requested.emit(_selected_avatar_id)
	)
	vbox.add_child(avatar_submit_button)
	ACTION_BUTTON_TEMPLATE.apply_profile_blue(avatar_submit_button, avatar_submit_button.custom_minimum_size, 20)

func _build_avatar_grid():
	_avatar_buttons.clear()
	for child in avatar_grid.get_children():
		child.queue_free()

	var avatar_ids: Array = ACCOUNT_CONFIG_SCRIPT.get_available_avatar_ids()
	avatar_ids.sort()
	for avatar_id_variant in avatar_ids:
		var avatar_id = str(avatar_id_variant)
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(104, 96)
		btn.text = ""
		btn.add_theme_stylebox_override("normal", _make_avatar_style(false))
		btn.add_theme_stylebox_override("hover", _make_avatar_style(false, true))
		btn.add_theme_stylebox_override("pressed", _make_avatar_style(true))
		btn.pressed.connect(func():
			_selected_avatar_id = avatar_id
			_refresh_avatar_selection()
		)

		var avatar_texture = TextureRect.new()
		avatar_texture.layout_mode = 1
		avatar_texture.anchors_preset = 8
		avatar_texture.anchor_left = 0.5
		avatar_texture.anchor_top = 0.5
		avatar_texture.anchor_right = 0.5
		avatar_texture.anchor_bottom = 0.5
		avatar_texture.offset_left = -28.0
		avatar_texture.offset_top = -28.0
		avatar_texture.offset_right = 28.0
		avatar_texture.offset_bottom = 28.0
		avatar_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		avatar_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		avatar_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tex = load(ACCOUNT_CONFIG_SCRIPT.get_avatar_path(avatar_id))
		if tex:
			avatar_texture.texture = tex
		btn.add_child(avatar_texture)

		avatar_grid.add_child(btn)
		_avatar_buttons[avatar_id] = btn

func _make_avatar_style(selected: bool, hover: bool = false) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.94902, 0.898039, 0.8, 1.0) if not hover else Color(0.972549, 0.92549, 0.831373, 1.0)
	style.border_color = COLOR_AVATAR_BORDER_SELECTED if selected else COLOR_AVATAR_BORDER_NORMAL
	style.set_border_width_all(3 if selected else 2)
	style.set_corner_radius_all(8)
	return style

func _refresh_avatar_selection():
	for avatar_id in _avatar_buttons.keys():
		var btn = _avatar_buttons[avatar_id] as Button
		if not btn:
			continue
		var is_selected = (str(avatar_id) == _selected_avatar_id)
		btn.add_theme_stylebox_override("normal", _make_avatar_style(is_selected))
		btn.add_theme_stylebox_override("hover", _make_avatar_style(is_selected, true))
		btn.add_theme_stylebox_override("pressed", _make_avatar_style(true))

func _apply_styles():
	add_theme_stylebox_override("panel", POPUP_STYLE_TEMPLATE.build_panel_style({
		"bg_color": COLOR_PANEL_BG,
		"border_color": COLOR_PANEL_BORDER,
		"corner_radius": 12,
		"border_width": 2
	}))

func show_popup(current_nickname: String, current_avatar_id: String):
	if not _avatar_buttons.has(current_avatar_id):
		current_avatar_id = ACCOUNT_CONFIG_SCRIPT.get_default_avatar_id()
	_selected_avatar_id = current_avatar_id
	nickname_input.text = current_nickname
	_refresh_avatar_selection()
	if background:
		background.z_index = z_index - 1
		background.visible = true
	visible = true
	_update_layout()
	call_deferred("_update_layout")

func hide_popup():
	visible = false
	if background:
		background.visible = false

func get_nickname_text() -> String:
	if not nickname_input:
		return ""
	return nickname_input.text.strip_edges()

func get_selected_avatar_id() -> String:
	return _selected_avatar_id

func _on_viewport_size_changed():
	if visible:
		_update_layout()

func _update_layout():
	var safe_rect := SAFE_AREA_HELPER.get_safe_inner_rect(self)
	var viewport_size = safe_rect.size
	var desired_w = clamp(viewport_size.x * 0.74, 420.0, 620.0)
	var desired_h = clamp(viewport_size.y * 0.82, 520.0, 760.0)
	var popup_pos := safe_rect.position + (safe_rect.size - Vector2(desired_w, desired_h)) * 0.5
	position = popup_pos
	size = Vector2(desired_w, desired_h)

func _input(event: InputEvent):
	if not visible:
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_event = event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if get_global_rect().has_point(mouse_event.position):
		return
	hide_popup()
	popup_closed.emit()
	get_viewport().set_input_as_handled()
