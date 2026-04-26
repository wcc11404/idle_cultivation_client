class_name DisplayPanelTemplate
extends RefCounted

const DEFAULT_CONTENT_LEFT_INSET := 12
const DEFAULT_HEADER_BOTTOM_GAP := 8
const DEFAULT_ACCENT_WIDTH := 4
const DEFAULT_ACCENT_HEIGHT := 24
const DEFAULT_ROW_SEPARATION := 8
const DEFAULT_ACCENT_COLOR := Color(0.870588, 0.705882, 0.207843, 1.0)
const DEFAULT_TITLE_COLOR := Color(0.22, 0.2, 0.18, 1.0)
const DEFAULT_LINE_COLOR := Color(0.82, 0.78, 0.71, 1.0)
const DEFAULT_TITLE_FONT_SIZE := 22

# 约束说明：
# 1) 展示面板内所有后续新增内容，左侧起点都应与标题首字左侧对齐。
# 2) 标题行与下方内容留白使用固定值，避免不同面板视觉节奏不一致。
# 3) 如果某个面板结构特殊，至少保证“内容左边距”和“标题下方留白”遵循这两个默认值。

static func apply_to_row(header_row: HBoxContainer, config: Dictionary = {}) -> void:
	if header_row == null:
		return

	var accent := header_row.get_node_or_null("HeaderAccent")
	var current_accent_color := DEFAULT_ACCENT_COLOR
	var current_accent_size := Vector2(float(DEFAULT_ACCENT_WIDTH), float(DEFAULT_ACCENT_HEIGHT))
	if accent is ColorRect:
		current_accent_color = accent.color
		current_accent_size = accent.custom_minimum_size

	var title := header_row.get_node_or_null("HeaderTitle")
	var current_title_color := DEFAULT_TITLE_COLOR
	var current_title_size := DEFAULT_TITLE_FONT_SIZE
	if title is Label:
		current_title_color = title.get_theme_color("font_color")
		current_title_size = title.get_theme_font_size("font_size")

	var line := header_row.get_node_or_null("HeaderLine")
	var current_line_color := DEFAULT_LINE_COLOR
	if line is HSeparator:
		current_line_color = line.self_modulate

	var current_row_separation := DEFAULT_ROW_SEPARATION
	if header_row.has_theme_constant_override("separation"):
		current_row_separation = header_row.get_theme_constant("separation")
	var accent_color: Color = Color(config.get("accent_color", current_accent_color))
	var title_color: Color = Color(config.get("title_color", current_title_color))
	var line_color: Color = Color(config.get("line_color", current_line_color))
	var title_text: String = str(config.get("title_text", ""))
	var title_font_size: int = int(config.get("title_font_size", current_title_size))
	var accent_width: float = float(config.get("accent_width", current_accent_size.x))
	var accent_height: float = float(config.get("accent_height", current_accent_size.y))
	var row_separation: int = int(config.get("row_separation", current_row_separation))

	header_row.add_theme_constant_override("separation", row_separation)

	if accent is ColorRect:
		accent.custom_minimum_size = Vector2(accent_width, accent_height)
		accent.color = accent_color

	if title is Label:
		title.add_theme_color_override("font_color", title_color)
		title.add_theme_font_size_override("font_size", title_font_size)
		if title_text != "":
			title.text = title_text

	if line is HSeparator:
		line.self_modulate = line_color

static func build_standard_header_config(extra: Dictionary = {}) -> Dictionary:
	var config := {
		"accent_width": DEFAULT_ACCENT_WIDTH,
		"accent_height": DEFAULT_ACCENT_HEIGHT,
		"accent_color": DEFAULT_ACCENT_COLOR,
		"row_separation": DEFAULT_ROW_SEPARATION,
		"title_font_size": DEFAULT_TITLE_FONT_SIZE,
		"title_color": DEFAULT_TITLE_COLOR,
		"line_color": DEFAULT_LINE_COLOR,
	}
	for key in extra.keys():
		config[key] = extra[key]
	return config

static func get_content_left_inset_from_header_config(header_config: Dictionary = {}) -> int:
	var accent_width := int(header_config.get("accent_width", DEFAULT_ACCENT_WIDTH))
	var row_separation := int(header_config.get("row_separation", DEFAULT_ROW_SEPARATION))
	return max(0, accent_width + row_separation)

static func apply_content_layout(
	left_pad_controls: Array,
	left_margin_container: MarginContainer = null,
	header_bottom_spacer: Control = null,
	config: Dictionary = {}
) -> void:
	var default_content_left_inset: int = DEFAULT_CONTENT_LEFT_INSET
	var default_header_bottom_gap: int = DEFAULT_HEADER_BOTTOM_GAP
	if left_margin_container:
		default_content_left_inset = int(left_margin_container.get_theme_constant("margin_left"))
	elif left_pad_controls.size() > 0 and left_pad_controls[0] is Control:
		default_content_left_inset = int((left_pad_controls[0] as Control).custom_minimum_size.x)

	if header_bottom_spacer:
		default_header_bottom_gap = int(header_bottom_spacer.custom_minimum_size.y)

	var content_left_inset: int = int(config.get("content_left_inset", default_content_left_inset))
	var header_bottom_gap: int = int(config.get("header_bottom_gap", default_header_bottom_gap))

	for node in left_pad_controls:
		if node is Control:
			node.custom_minimum_size.x = float(content_left_inset)

	if left_margin_container:
		left_margin_container.add_theme_constant_override("margin_left", content_left_inset)

	if header_bottom_spacer:
		header_bottom_spacer.custom_minimum_size.y = float(header_bottom_gap)
