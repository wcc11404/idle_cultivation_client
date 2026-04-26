extends Node

class_name ServerClient

const GAME_SERVER_API_SCRIPT = preload("res://scripts/network/GameServerAPI.gd")
const SERVER_CONFIG_SCRIPT = preload("res://scripts/network/ServerConfig.gd")

const DEFAULT_USERNAME := "test"
const DEFAULT_PASSWORD := "test123"

var api: GameServerAPI = null
var network_manager: Node = null
var call_counts: Dictionary = {}

func ensure_ready() -> void:
	if api and is_instance_valid(api):
		network_manager = api.network_manager
		return
	api = GAME_SERVER_API_SCRIPT.new()
	add_child(api)
	await get_tree().process_frame
	network_manager = api.network_manager

func configure(api_base: String = SERVER_CONFIG_SCRIPT.DEFAULT_API_BASE) -> void:
	SERVER_CONFIG_SCRIPT.set_api_base(api_base)
	await ensure_ready()
	if network_manager and network_manager.has_method("load_token"):
		network_manager.load_token()

func clear_call_counts() -> void:
	call_counts.clear()

func get_call_count(name: String) -> int:
	return int(call_counts.get(name, 0))

func login_test_account(username: String = DEFAULT_USERNAME, password: String = DEFAULT_PASSWORD) -> Dictionary:
	_count("login")
	var result = await api.login(username, password)
	if result.get("success", false) and network_manager and network_manager.has_method("save_token"):
		var token := str(result.get("token", ""))
		if not token.is_empty():
			network_manager.save_token(token)
	return result

func reset_account() -> Dictionary:
	return await test_post("/test/reset_account", {})

func apply_preset(preset_name: String) -> Dictionary:
	return await test_post("/test/apply_preset", {"preset_name": preset_name})

func test_post(endpoint: String, body: Dictionary) -> Dictionary:
	_count("test_post:" + endpoint)
	await ensure_ready()
	return await network_manager.request("POST", endpoint, body, {"track_network_failure": true})

func test_get(endpoint: String) -> Dictionary:
	_count("test_get:" + endpoint)
	await ensure_ready()
	return await network_manager.request("GET", endpoint, {}, {"track_network_failure": true})

func load_game() -> Dictionary:
	_count("load_game")
	return await api.load_game()

func cultivation_start() -> Dictionary:
	_count("cultivation_start")
	return await api.cultivation_start()

func cultivation_report(elapsed_seconds: float) -> Dictionary:
	_count("cultivation_report")
	return await api.cultivation_report(elapsed_seconds)

func cultivation_stop() -> Dictionary:
	_count("cultivation_stop")
	return await api.cultivation_stop()

func player_breakthrough() -> Dictionary:
	_count("player_breakthrough")
	return await api.player_breakthrough()

func inventory_use(item_id: String) -> Dictionary:
	_count("inventory_use")
	return await api.inventory_use(item_id)

func inventory_discard(item_id: String, count: int) -> Dictionary:
	_count("inventory_discard")
	return await api.inventory_discard(item_id, count)

func inventory_organize() -> Dictionary:
	_count("inventory_organize")
	return await api.inventory_organize()

func inventory_expand() -> Dictionary:
	_count("inventory_expand")
	return await api.inventory_expand()

func inventory_list() -> Dictionary:
	_count("inventory_list")
	return await api.inventory_list()

func spell_equip(spell_id: String, slot_type: String = "") -> Dictionary:
	_count("spell_equip")
	return await api.spell_equip(spell_id, slot_type)

func spell_unequip(spell_id: String, slot_type: String = "") -> Dictionary:
	_count("spell_unequip")
	return await api.spell_unequip(spell_id, slot_type)

func spell_upgrade(spell_id: String) -> Dictionary:
	_count("spell_upgrade")
	return await api.spell_upgrade(spell_id)

func spell_charge(spell_id: String, amount: int) -> Dictionary:
	_count("spell_charge")
	return await api.spell_charge(spell_id, amount)

func spell_list() -> Dictionary:
	_count("spell_list")
	return await api.spell_list()

func alchemy_start() -> Dictionary:
	_count("alchemy_start")
	return await api.alchemy_start()

func alchemy_report(recipe_id: String, count: int) -> Dictionary:
	_count("alchemy_report")
	return await api.alchemy_report(recipe_id, count)

func alchemy_stop() -> Dictionary:
	_count("alchemy_stop")
	return await api.alchemy_stop()

func alchemy_recipes() -> Dictionary:
	_count("alchemy_recipes")
	return await api.alchemy_recipes()

func lianli_simulate(area_id: String) -> Dictionary:
	_count("lianli_simulate")
	return await api.lianli_simulate(area_id)

func lianli_speed_options() -> Dictionary:
	_count("lianli_speed_options")
	return await api.lianli_speed_options()

func lianli_finish(speed: float, index = null) -> Dictionary:
	_count("lianli_finish")
	return await api.lianli_finish(speed, index)

func lianli_foundation_herb_cave() -> Dictionary:
	_count("lianli_foundation_herb_cave")
	return await api.lianli_foundation_herb_cave()

func lianli_tower() -> Dictionary:
	_count("lianli_tower")
	return await api.lianli_tower()

func herb_points() -> Dictionary:
	_count("herb_points")
	return await api.herb_points()

func herb_start(point_id: String) -> Dictionary:
	_count("herb_start")
	return await api.herb_start(point_id)

func herb_report() -> Dictionary:
	_count("herb_report")
	return await api.herb_report()

func herb_stop() -> Dictionary:
	_count("herb_stop")
	return await api.herb_stop()

func task_list() -> Dictionary:
	_count("task_list")
	return await api.task_list()

func task_claim(task_id: String) -> Dictionary:
	_count("task_claim")
	return await api.task_claim(task_id)

func change_nickname(new_nickname: String) -> Dictionary:
	_count("change_nickname")
	return await api.change_nickname(new_nickname)

func get_rank(server_id: String = "default") -> Dictionary:
	_count("get_rank")
	return await api.get_rank(server_id)

func logout() -> Dictionary:
	_count("logout")
	return await api.logout()

func _count(name: String) -> void:
	call_counts[name] = int(call_counts.get(name, 0)) + 1
