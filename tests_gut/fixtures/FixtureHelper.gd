extends RefCounted

static func find_inventory_slot_index(inventory: Node, item_id: String) -> int:
	if not inventory or not inventory.get("slots"):
		return -1
	for index in range(inventory.slots.size()):
		var slot = inventory.slots[index]
		if slot is Dictionary and not bool(slot.get("empty", true)) and str(slot.get("id", "")) == item_id:
			return index
	return -1

static func extract_raw_log_messages(log_manager: Node) -> Array:
	var messages: Array = []
	if not log_manager or not log_manager.has_method("get_logs"):
		return messages
	for entry in log_manager.get_logs():
		if entry is Dictionary:
			messages.append(str(entry.get("raw_message", "")))
	return messages

static func contains_log_message(log_manager: Node, needle: String) -> bool:
	for message in extract_raw_log_messages(log_manager):
		if str(message).contains(needle):
			return true
	return false
