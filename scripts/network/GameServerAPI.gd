extends Node

class_name GameServerAPI

var network_manager = null

func _ready():
	network_manager = get_node_or_null("/root/GlobalNetworkManager")
	if not network_manager:
		const NetworkManager = preload("res://scripts/network/NetworkManager.gd")
		network_manager = NetworkManager.new()
		add_child(network_manager)

func _critical_options(retry_count: int = 0, show_retry_toast: bool = false) -> Dictionary:
	return {
		"retry_count": retry_count,
		"track_network_failure": true,
		"show_retry_toast": show_retry_toast
	}

# ==================== 认证 ====================

func register(username: String, password: String) -> Dictionary:
	return await network_manager.request("POST", "/auth/register", {
		"username": username,
		"password": password
	}, _critical_options())

func login(username: String, password: String) -> Dictionary:
	return await network_manager.request("POST", "/auth/login", {
		"username": username,
		"password": password
	}, _critical_options())

func refresh_token() -> Dictionary:
	return await network_manager.request("POST", "/auth/refresh", {}, _critical_options())

func logout() -> Dictionary:
	return await network_manager.request("POST", "/auth/logout", {}, _critical_options())

func change_nickname(new_nickname: String) -> Dictionary:
	return await network_manager.request("POST", "/auth/change_nickname", {
		"nickname": new_nickname
	}, _critical_options())

# ==================== 基础数据 ====================

func load_game() -> Dictionary:
	return await network_manager.request("GET", "/game/data", {}, _critical_options())

func save_game(data: Dictionary) -> Dictionary:
	return await network_manager.request("POST", "/game/save", {
		"data": data
	}, _critical_options())

func claim_offline_reward() -> Dictionary:
	return await network_manager.request("POST", "/game/claim_offline_reward", {}, _critical_options())

func get_rank(server_id: String = "default") -> Dictionary:
	return await network_manager.request("GET", "/game/rank?server_id=" + server_id)

# ==================== 修炼 ====================

func cultivation_start() -> Dictionary:
	return await network_manager.request("POST", "/game/player/cultivation/start", {}, _critical_options())

func cultivation_report(count: int) -> Dictionary:
	return await network_manager.request("POST", "/game/player/cultivation/report", {
		"count": count
	}, _critical_options())

func cultivation_stop() -> Dictionary:
	return await network_manager.request("POST", "/game/player/cultivation/stop", {}, _critical_options())

func player_breakthrough() -> Dictionary:
	return await network_manager.request("POST", "/game/player/breakthrough", {}, _critical_options())

# ==================== 背包 ====================

func inventory_use(item_id: String) -> Dictionary:
	return await network_manager.request("POST", "/game/inventory/use", {
		"item_id": item_id
	}, _critical_options())

func inventory_discard(item_id: String, count: int) -> Dictionary:
	return await network_manager.request("POST", "/game/inventory/discard", {
		"item_id": item_id,
		"count": count
	}, _critical_options())

func inventory_organize() -> Dictionary:
	return await network_manager.request("POST", "/game/inventory/organize", {}, _critical_options())

func inventory_expand() -> Dictionary:
	return await network_manager.request("POST", "/game/inventory/expand", {}, _critical_options())

func inventory_list() -> Dictionary:
	return await network_manager.request("GET", "/game/inventory/list", {}, _critical_options())

# ==================== 术法 ====================

func spell_equip(spell_id: String, slot_type: String = "") -> Dictionary:
	var body: Dictionary = {
		"spell_id": spell_id
	}
	if not slot_type.is_empty():
		body["slot_type"] = slot_type
	return await network_manager.request("POST", "/game/spell/equip", body, _critical_options())

func spell_unequip(spell_id: String, slot_type: String = "") -> Dictionary:
	var body: Dictionary = {
		"spell_id": spell_id
	}
	if not slot_type.is_empty():
		body["slot_type"] = slot_type
	return await network_manager.request("POST", "/game/spell/unequip", body, _critical_options())

func spell_upgrade(spell_id: String) -> Dictionary:
	return await network_manager.request("POST", "/game/spell/upgrade", {
		"spell_id": spell_id
	}, _critical_options())

func spell_charge(spell_id: String, amount: int) -> Dictionary:
	return await network_manager.request("POST", "/game/spell/charge", {
		"spell_id": spell_id,
		"amount": amount
	}, _critical_options())

func spell_list() -> Dictionary:
	return await network_manager.request("GET", "/game/spell/list", {}, _critical_options())

# ==================== 炼丹 ====================

func alchemy_start() -> Dictionary:
	return await network_manager.request("POST", "/game/alchemy/start", {}, _critical_options())

func alchemy_report(recipe_id: String, count: int) -> Dictionary:
	return await network_manager.request("POST", "/game/alchemy/report", {
		"recipe_id": recipe_id,
		"count": count
	}, _critical_options(1, true))

func alchemy_stop() -> Dictionary:
	return await network_manager.request("POST", "/game/alchemy/stop", {}, _critical_options())

func alchemy_recipes() -> Dictionary:
	return await network_manager.request("GET", "/game/alchemy/recipes", {}, _critical_options())

# ==================== 历练 ====================

func lianli_simulate(area_id: String) -> Dictionary:
	return await network_manager.request("POST", "/game/lianli/simulate", {
		"area_id": area_id
	}, _critical_options())

func lianli_finish(speed: float, index: int = -1) -> Dictionary:
	var body := {"speed": speed}
	if index >= 0:
		body["index"] = index
	return await network_manager.request("POST", "/game/lianli/finish", body, _critical_options(1, true))

func lianli_foundation_herb_cave() -> Dictionary:
	return await network_manager.request("GET", "/game/dungeon/foundation_herb_cave", {}, _critical_options())

func lianli_tower() -> Dictionary:
	return await network_manager.request("GET", "/game/tower/highest_floor", {}, _critical_options())
