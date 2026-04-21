extends Control

const LOGIN_SCENE := preload("res://scenes/app/Login.tscn")

const PRESET_BASE := Vector2i(1080, 1920)
const PRESET_ANDROID_TALL := Vector2i(1080, 2400)
const PRESET_IPHONE_NOTCH := Vector2i(1125, 2436)

var _preview_container: SubViewportContainer = null
var _preview_viewport: SubViewport = null
var _preview_size: Vector2i = PRESET_BASE
var _size_label: Label = null
var _hint_label: Label = null

func _ready() -> void:
	_build_preview_viewport()
	_build_debug_toolbar()
	_apply_preview_size(PRESET_BASE)
	if get_viewport() and not get_viewport().size_changed.is_connected(_on_root_viewport_changed):
		get_viewport().size_changed.connect(_on_root_viewport_changed)

func _build_preview_viewport() -> void:
	_preview_container = SubViewportContainer.new()
	_preview_container.name = "PreviewContainer"
	_preview_container.stretch = true
	_preview_container.mouse_filter = Control.MOUSE_FILTER_STOP
	_preview_container.z_index = 10
	add_child(_preview_container)

	_preview_viewport = SubViewport.new()
	_preview_viewport.name = "PreviewViewport"
	_preview_viewport.disable_3d = true
	_preview_viewport.transparent_bg = false
	_preview_viewport.handle_input_locally = true
	_preview_container.add_child(_preview_viewport)

	var login_instance := LOGIN_SCENE.instantiate()
	if login_instance is Control:
		var login_control := login_instance as Control
		login_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		login_control.grow_horizontal = Control.GROW_DIRECTION_BOTH
		login_control.grow_vertical = Control.GROW_DIRECTION_BOTH
	_preview_viewport.add_child(login_instance)

func _build_debug_toolbar() -> void:
	var panel := PanelContainer.new()
	panel.name = "DebugToolbar"
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 12.0
	panel.offset_top = 12.0
	panel.custom_minimum_size = Vector2(520, 98)
	panel.z_index = 5000
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "长屏预览"
	vbox.add_child(title)

	_size_label = Label.new()
	vbox.add_child(_size_label)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 8)
	vbox.add_child(button_row)

	button_row.add_child(_build_preset_button("1080×1920", PRESET_BASE))
	button_row.add_child(_build_preset_button("1080×2400", PRESET_ANDROID_TALL))
	button_row.add_child(_build_preset_button("1125×2436", PRESET_IPHONE_NOTCH))

	_hint_label = Label.new()
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_hint_label)

func _build_preset_button(label: String, preset_size: Vector2i) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(150, 36)
	button.pressed.connect(func() -> void:
		_apply_preview_size(preset_size)
	)
	return button

func _apply_preview_size(target_size: Vector2i) -> void:
	_preview_size = target_size
	if _preview_viewport:
		_preview_viewport.size = target_size
	var window := get_window()
	if window:
		DisplayServer.window_set_size(target_size, window.get_window_id())
	if _size_label:
		_size_label.text = "当前预览：%d×%d" % [target_size.x, target_size.y]
	if _hint_label:
		_hint_label.text = "点击预设会同步修改真实运行窗口和内部预览分辨率；若仍不变化，说明当前平台窗口管理器拦截了编辑器启动窗口。"
	_update_preview_container_layout()

func _on_root_viewport_changed() -> void:
	_update_preview_container_layout()

func _update_preview_container_layout() -> void:
	if not _preview_container:
		return
	var root_size: Vector2 = get_viewport_rect().size
	var available_rect: Rect2 = Rect2(
		Vector2(16.0, 126.0),
		Vector2(
			max(100.0, root_size.x - 32.0),
			max(100.0, root_size.y - 142.0)
		)
	)
	var scale_factor: float = min(
		available_rect.size.x / float(_preview_size.x),
		available_rect.size.y / float(_preview_size.y)
	)
	var fitted_size: Vector2 = Vector2(_preview_size) * scale_factor
	var fitted_pos: Vector2 = available_rect.position + (available_rect.size - fitted_size) * 0.5
	_preview_container.position = fitted_pos
	_preview_container.size = fitted_size
