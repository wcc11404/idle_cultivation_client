class_name ItemData extends Node

enum ItemType {
	CURRENCY = 0,
	MATERIAL = 1,
	CONSUMABLE = 2,
	GIFT = 3,
	UNLOCK_SPELL = 4,
	UNLOCK_RECIPE = 5,
	UNLOCK_FURNACE = 6,
}

const QUALITY_COLORS: Array = [
	Color("#111111"),
	Color("#1F6A25"),
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

func get_item_type_name(item_id: String) -> String:
	return get_item_type_name_by_value(get_item_type(item_id))

func get_item_type_name_by_value(item_type: int) -> String:
	match item_type:
		ItemType.CURRENCY:
			return "货币"
		ItemType.MATERIAL:
			return "材料"
		ItemType.CONSUMABLE:
			return "消耗品"
		ItemType.GIFT:
			return "宝箱/礼包"
		ItemType.UNLOCK_SPELL:
			return "解锁术法"
		ItemType.UNLOCK_RECIPE:
			return "解锁丹方"
		ItemType.UNLOCK_FURNACE:
			return "解锁炼丹炉"
		_:
			return "未知"

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

func get_item_effect(item_id: String) -> Dictionary:
	var data = get_item_data(item_id)
	return data.get("effect", {})

func get_item_content(item_id: String) -> Dictionary:
	var data = get_item_data(item_id)
	return data.get("content", {})

func item_exists(item_id: String) -> bool:
	return item_data.has(item_id)

func get_use_text(item_id: String) -> String:
	var item_type = get_item_type(item_id)
	match item_type:
		ItemType.GIFT:
			return "打开"
		ItemType.CONSUMABLE, ItemType.UNLOCK_SPELL, ItemType.UNLOCK_RECIPE, ItemType.UNLOCK_FURNACE:
			return "使用"
		_:
			return ""

func is_important(item_id: String) -> bool:
	var data = get_item_data(item_id)
	var quality = data.get("quality", 0)
	return quality >= 4

func is_currency(item_id: String) -> bool:
	return get_item_type(item_id) == ItemType.CURRENCY

func is_material(item_id: String) -> bool:
	return get_item_type(item_id) == ItemType.MATERIAL

func is_consumable(item_id: String) -> bool:
	return get_item_type(item_id) == ItemType.CONSUMABLE

func is_gift(item_id: String) -> bool:
	return get_item_type(item_id) == ItemType.GIFT

func is_unlock_spell(item_id: String) -> bool:
	return get_item_type(item_id) == ItemType.UNLOCK_SPELL

func is_unlock_recipe(item_id: String) -> bool:
	return get_item_type(item_id) == ItemType.UNLOCK_RECIPE

func is_unlock_furnace(item_id: String) -> bool:
	return get_item_type(item_id) == ItemType.UNLOCK_FURNACE

func get_all_item_ids() -> Array:
	return item_data.keys()

func get_items_by_type(item_type: int) -> Array:
	var result = []
	for item_id in item_data.keys():
		if item_data[item_id].get("type", ItemType.MATERIAL) == item_type:
			result.append(item_id)
	return result
