class_name SafeAreaHelper
extends RefCounted

static func get_safe_margins(control: Control) -> Dictionary:
	var viewport_rect := control.get_viewport().get_visible_rect()
	var viewport_size := viewport_rect.size
	var margins := {
		"left": 0.0,
		"top": 0.0,
		"right": 0.0,
		"bottom": 0.0,
	}
	var os_name := OS.get_name()
	if os_name != "Android" and os_name != "iOS":
		return margins
	if not DisplayServer.has_method("get_display_safe_area"):
		return margins
	var safe_rect_variant = DisplayServer.get_display_safe_area()
	if typeof(safe_rect_variant) != TYPE_RECT2I and typeof(safe_rect_variant) != TYPE_RECT2:
		return margins
	var safe_rect: Rect2 = Rect2(safe_rect_variant)
	if safe_rect.size.x <= 0.0 or safe_rect.size.y <= 0.0:
		return margins
	var window_size := Vector2(DisplayServer.window_get_size())
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		return margins
	var scale_x := viewport_size.x / window_size.x
	var scale_y := viewport_size.y / window_size.y
	margins.left = max(0.0, safe_rect.position.x) * scale_x
	margins.top = max(0.0, safe_rect.position.y) * scale_y
	margins.right = max(0.0, window_size.x - safe_rect.end.x) * scale_x
	margins.bottom = max(0.0, window_size.y - safe_rect.end.y) * scale_y
	return margins

static func get_safe_inner_rect(control: Control) -> Rect2:
	var viewport_rect := control.get_viewport().get_visible_rect()
	var margins := get_safe_margins(control)
	var inner_rect := Rect2(
		Vector2(margins.left, margins.top),
		Vector2(
			max(0.0, viewport_rect.size.x - margins.left - margins.right),
			max(0.0, viewport_rect.size.y - margins.top - margins.bottom)
		)
	)
	if inner_rect.size.x <= 0.0 or inner_rect.size.y <= 0.0:
		return viewport_rect
	return inner_rect

static func get_centered_rect(target_size: Vector2, container_rect: Rect2) -> Rect2:
	var position := container_rect.position + (container_rect.size - target_size) * 0.5
	return Rect2(position, target_size)
