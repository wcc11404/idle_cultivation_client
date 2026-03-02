class_name ItemData extends Node

enum ItemType {
	CURRENCY = 0,
	MATERIAL = 1,
	CONSUMABLE = 2,
	GIFT = 3,
	UNLOCK = 4,
}

const QUALITY_COLORS: Array = [
	Color("#D3D3D3"),
	Color.GREEN,
	Color("#00BFFF"),
	Color("#EE82EE"),
	Color.ORANGE
]

var item_data: Dictionary = {}

func _ready():
	_load_config()

func _load_config():
	var file = FileAccess.open("res://scripts/core/inventory/items.json", FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		var data = JSON.parse_string(json_text)
		if data:
			item_data = data.get("items", {})

func get_item_data(item_id: String) -> Dictionary:
	return item_data.get(item_id, {})

func get_item_name(item_id: String) -> String:
	var data = get_item_data(item_id)
	return data.get("name", "未知物品")

func get_item_quality_color(quality: int) -> Color:
	if quality >= 0 and quality < QUALITY_COLORS.size():
		return QUALITY_COLORS[quality]
	return QUALITY_COLORS[0]

func get_item_type(item_id: String) -> int:
	var data = get_item_data(item_id)
	return data.get("type", ItemType.MATERIAL)

func get_max_stack(item_id: String) -> int:
	var data = get_item_data(item_id)
	return int(data.get("max_stack", 1))

func can_stack(item_id: String) -> bool:
	var data = get_item_data(item_id)
	var max_stack = data.get("max_stack", 1)
	return max_stack > 1

func get_item_description(item_id: String) -> String:
	var data = get_item_data(item_id)
	return data.get("description", "")

func get_item_icon(item_id: String) -> String:
	var data = get_item_data(item_id)
	return data.get("icon", "")

func get_item_quality(item_id: String) -> int:
	var data = get_item_data(item_id)
	return int(data.get("quality", 0))

func get_use_text(item_id: String) -> String:
	var item_type = get_item_type(item_id)
	match item_type:
		ItemType.GIFT:
			return "打开"
		ItemType.CONSUMABLE, ItemType.UNLOCK:
			return "使用"
		_:
			return ""

func is_important(item_id: String) -> bool:
	var data = get_item_data(item_id)
	var quality = data.get("quality", 0)
	var item_type = data.get("type", ItemType.MATERIAL)
	return quality >= 4 or item_type == ItemType.UNLOCK
