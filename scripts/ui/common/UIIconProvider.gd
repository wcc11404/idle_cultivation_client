class_name UIIconProvider
extends RefCounted

const ICON_SPIRIT_STONE := "res://assets/ui/icon_spirit_stone.svg"
const ICON_AUDIO_ON := "res://assets/ui/icon_audio_on.svg"
const ICON_AUDIO_OFF := "res://assets/ui/icon_audio_off.svg"

static var _cache: Dictionary = {}

static func load_svg_texture(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]

	# 1) 优先走 Godot 资源导入链路（跨平台最稳定，Android 推荐）
	var imported: Resource = load(path)
	if imported is Texture2D:
		_cache[path] = imported
		return imported

	# 2) 回退：运行时 SVG 解析（桌面可用，移动端可能失败）
	var svg_source := FileAccess.get_file_as_string(path)
	if svg_source.is_empty():
		# 3) 再回退：尝试同名 PNG
		var png_path := path.get_basename() + ".png"
		var png_res: Resource = load(png_path)
		if png_res is Texture2D:
			_cache[path] = png_res
			return png_res
		push_warning("Failed to read icon source: %s" % path)
		return null

	var image := Image.new()
	var err := image.load_svg_from_string(svg_source)
	if err != OK:
		var fallback_png := path.get_basename() + ".png"
		var fallback_res: Resource = load(fallback_png)
		if fallback_res is Texture2D:
			_cache[path] = fallback_res
			return fallback_res
		push_warning("Failed to parse SVG icon: %s" % path)
		return null

	var texture := ImageTexture.create_from_image(image)
	_cache[path] = texture
	return texture
