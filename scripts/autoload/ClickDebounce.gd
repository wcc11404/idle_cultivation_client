extends Node

const CLICK_DEBOUNCE_UTILS := preload("res://scripts/utils/ClickDebounceUtils.gd")
const CLICK_DEBOUNCE_MS := 200
const GLOBAL_POINTER_ACTION_KEY := "__global_pointer_click__"


func _ready() -> void:
	set_process_input(true)


func _input(event: InputEvent) -> void:
	if not _is_click_press_event(event):
		return

	if not CLICK_DEBOUNCE_UTILS.should_accept(GLOBAL_POINTER_ACTION_KEY, CLICK_DEBOUNCE_MS):
		get_viewport().set_input_as_handled()
		return


func _is_click_press_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		return mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT

	if event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		return touch_event.pressed

	return false
