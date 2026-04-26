class_name ClickDebounceUtils
extends RefCounted

const DEFAULT_COOLDOWN_MS := 200

static var _last_action_ms_by_key: Dictionary = {}


static func should_accept(
	action_key: String,
	cooldown_ms: int = DEFAULT_COOLDOWN_MS,
	now_ms: int = -1
) -> bool:
	if action_key.is_empty():
		return true

	var now: int = now_ms if now_ms >= 0 else Time.get_ticks_msec()
	var last_ms: int = int(_last_action_ms_by_key.get(action_key, -1000000))

	if now - last_ms < cooldown_ms:
		return false

	_last_action_ms_by_key[action_key] = now
	return true


static func reset_action(action_key: String) -> void:
	if _last_action_ms_by_key.has(action_key):
		_last_action_ms_by_key.erase(action_key)


static func reset_all() -> void:
	_last_action_ms_by_key.clear()
