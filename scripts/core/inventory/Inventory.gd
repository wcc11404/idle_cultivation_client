class_name Inventory extends Node

signal item_added(item_id: String, count: int)
signal item_removed(item_id: String, count: int)
signal inventory_full()
signal capacity_changed(new_capacity: int)

const DEFAULT_SIZE = 40
const MAX_SIZE = 40
const EXPAND_STEP = 10

var slots: Array = []
var capacity: int = DEFAULT_SIZE

var item_data: Node = null

func _ready():
	var game_manager = get_node("/root/GameManager")
	if game_manager:
		item_data = game_manager.get_item_data()
	
	init_slots()

func init_slots():
	slots.clear()
	for i in range(MAX_SIZE):
		slots.append({"empty": true, "id": "", "count": 0})

func get_used_slots() -> int:
	var used = 0
	for i in range(capacity):
		if not slots[i]["empty"]:
			used += 1
	return used

func get_capacity() -> int:
	return capacity

func can_expand() -> bool:
	return capacity < MAX_SIZE

func expand_capacity() -> bool:
	if not can_expand():
		return false
	
	capacity = min(capacity + EXPAND_STEP, MAX_SIZE)
	capacity_changed.emit(capacity)
	return true

func add_item(item_id: String, count: int = 1) -> bool:
	if count <= 0:
		return false

	if not item_data or not item_data.item_data.has(item_id):
		return false

	var max_stack = item_data.get_max_stack(item_id)
	var can_stack = item_data.can_stack(item_id)
	
	var remaining_count = count
	
	if can_stack:
		for i in range(capacity):
			if remaining_count <= 0:
				break
			if not slots[i]["empty"] and slots[i]["id"] == item_id:
				var current_count = slots[i]["count"]
				var can_add = min(remaining_count, max_stack - current_count)
				if can_add > 0:
					slots[i]["count"] = current_count + can_add
					remaining_count -= can_add
	
	if remaining_count > 0:
		for i in range(capacity):
			if remaining_count <= 0:
				break
			if slots[i]["empty"]:
				var add_count = min(remaining_count, max_stack)
				slots[i] = {"empty": false, "id": item_id, "count": add_count}
				remaining_count -= add_count
	
	if remaining_count < count:
		item_added.emit(item_id, count - remaining_count)
		return remaining_count == 0
	else:
		inventory_full.emit()
		return false

func remove_item(item_id: String, count: int = 1) -> bool:
	var remaining_count = count
	var removed = false
	
	for i in range(capacity):
		if remaining_count <= 0:
			break
		if not slots[i]["empty"] and slots[i]["id"] == item_id:
			var current_count = slots[i]["count"]
			var remove_count = min(remaining_count, current_count)
			
			if remove_count > 0:
				slots[i]["count"] = current_count - remove_count
				remaining_count -= remove_count
				
				if slots[i]["count"] <= 0:
					slots[i] = {"empty": true, "id": "", "count": 0}
				
				removed = true
	
	if removed:
		item_removed.emit(item_id, count - remaining_count)
	
	return removed

func has_item(item_id: String, count: int = 1) -> bool:
	var total = 0
	for i in range(capacity):
		if not slots[i]["empty"] and slots[i]["id"] == item_id:
			total += slots[i]["count"]
			if total >= count:
				return true
	return total >= count

func get_item_count(item_id: String) -> int:
	var total = 0
	for i in range(capacity):
		if not slots[i]["empty"] and slots[i]["id"] == item_id:
			total += slots[i]["count"]
	return total

func get_item_list() -> Array:
	var result = []
	for i in range(capacity):
		result.append({
			"index": i,
			"empty": slots[i]["empty"],
			"id": slots[i]["id"],
			"count": slots[i]["count"]
		})
	return result

func clear():
	for i in range(MAX_SIZE):
		slots[i] = {"empty": true, "id": "", "count": 0}

func get_save_data() -> Dictionary:
	var sparse_slots = {}
	for i in range(capacity):
		if not slots[i]["empty"]:
			sparse_slots[str(i)] = {
				"id": slots[i]["id"],
				"count": slots[i]["count"]
			}
	
	return {
		"capacity": capacity,
		"slots": sparse_slots
	}

func apply_save_data(data: Dictionary):
	if data.has("capacity"):
		capacity = data["capacity"]
	else:
		capacity = DEFAULT_SIZE
	
	init_slots()
	
	if data.has("slots"):
		var slots_data = data["slots"]
		
		if typeof(slots_data) == TYPE_ARRAY:
			for i in range(min(slots_data.size(), MAX_SIZE)):
				var slot = slots_data[i]
				if typeof(slot) == TYPE_DICTIONARY and not slot.get("empty", true):
					slots[i] = {
						"empty": false,
						"id": slot.get("id", ""),
						"count": int(slot.get("count", 0))
					}
		elif typeof(slots_data) == TYPE_DICTIONARY:
			for key in slots_data.keys():
				var index = int(key)
				if index >= 0 and index < MAX_SIZE:
					var slot = slots_data[key]
					if typeof(slot) == TYPE_DICTIONARY:
						slots[index] = {
							"empty": false,
							"id": slot.get("id", ""),
							"count": int(slot.get("count", 0))
						}
					else:
						pass
