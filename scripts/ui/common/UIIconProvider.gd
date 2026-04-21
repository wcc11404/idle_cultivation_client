class_name UIIconProvider
extends RefCounted

const ICON_SPIRIT_STONE := "res://assets/ui/icon_spirit_stone.svg"
const ICON_AUDIO_ON := "res://assets/ui/icon_audio_on.svg"
const ICON_AUDIO_OFF := "res://assets/ui/icon_audio_off.svg"

static var _cache: Dictionary = {}

static func load_svg_texture(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]

	var svg_source := FileAccess.get_file_as_string(path)
	if svg_source.is_empty():
		push_warning("Failed to read icon source: %s" % path)
		return null

	var image := Image.new()
	var err := image.load_svg_from_string(svg_source)
	if err != OK:
		push_warning("Failed to parse SVG icon: %s" % path)
		return null

	var texture := ImageTexture.create_from_image(image)
	_cache[path] = texture
	return texture
