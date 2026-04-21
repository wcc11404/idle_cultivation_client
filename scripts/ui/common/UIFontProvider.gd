class_name UIFontProvider
extends RefCounted

const UI_FONT_PATH := "res://assets/fonts/SourceHanSansSC-VF.ttf"

static var _ui_theme: Theme = null

static func get_theme() -> Theme:
	if _ui_theme:
		return _ui_theme
	var font_file := FontFile.new()
	var load_err := font_file.load_dynamic_font(UI_FONT_PATH)
	if load_err != OK:
		push_warning("Failed to load UI font: %s" % UI_FONT_PATH)
		return Theme.new()
	font_file.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	font_file.hinting = TextServer.HINTING_LIGHT
	font_file.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	font_file.force_autohinter = false
	var font := FontVariation.new()
	font.base_font = font_file
	font.variation_opentype = {"wght": 900}
	font.variation_embolden = 1.1
	var theme := Theme.new()
	theme.set_default_font(font)
	theme.set_default_font_size(16)
	theme.set_color("font_outline_color", "Label", Color(0.12, 0.11, 0.10, 0.35))
	theme.set_constant("outline_size", "Label", 1)
	theme.set_color("font_outline_color", "RichTextLabel", Color(0.12, 0.11, 0.10, 0.3))
	theme.set_constant("outline_size", "RichTextLabel", 1)
	theme.set_color("font_outline_color", "LineEdit", Color(0.12, 0.11, 0.10, 0.22))
	theme.set_constant("outline_size", "LineEdit", 1)
	_ui_theme = theme
	return _ui_theme

static func apply_to_root(root: Control) -> void:
	if not root:
		return
	root.theme = get_theme()
