extends Node

class_name ModuleHarness

const MAIN_SCENE = preload("res://scenes/app/Main.tscn")
const SERVER_CONFIG_SCRIPT = preload("res://scripts/network/ServerConfig.gd")
const TEST_SESSION_HELPER_SCRIPT = preload("res://tests_gut/support/SessionHelper.gd")
const TEST_SERVER_CLIENT_SCRIPT = preload("res://tests_gut/support/ServerClient.gd")
const SERVER_STATE_ADAPTER_SCRIPT = preload("res://tests_gut/support/ServerStateAdapter.gd")

var client: ServerClient = null
var game_ui: Control = null

func bootstrap(api_base: String = SERVER_CONFIG_SCRIPT.DEFAULT_API_BASE, preset_name: String = "") -> void:
	TEST_SESSION_HELPER_SCRIPT.reset_local_session(api_base)
	await _ensure_client(api_base)
	var login_result = await client.login_test_account()
	if not login_result.get("success", false):
		push_error("测试账号登录失败: %s" % [str(login_result)])
		return
	await client.reset_account()
	if not preset_name.is_empty():
		await client.apply_preset(preset_name)
	await _spawn_game_ui()
	await sync_full_state()
	clear_logs()
	client.clear_call_counts()

func cleanup() -> void:
	_stop_runtime_modules()
	if game_ui and is_instance_valid(game_ui):
		if game_ui.has_method("begin_test_shutdown"):
			game_ui.begin_test_shutdown()
		if game_ui.has_method("await_pending_test_tasks"):
			await game_ui.await_pending_test_tasks()
	if game_ui and is_instance_valid(game_ui):
		if game_ui.get_parent() == self:
			remove_child(game_ui)
		game_ui.free()
	game_ui = null
	if client and is_instance_valid(client):
		if client.get_parent() == self:
			remove_child(client)
		client.free()
	client = null
	for child in get_children():
		if is_instance_valid(child):
			remove_child(child)
			child.free()
	TEST_SESSION_HELPER_SCRIPT.reset_local_session()
	await get_tree().process_frame
	await get_tree().process_frame

func _stop_runtime_modules() -> void:
	if not game_ui or not is_instance_valid(game_ui):
		return
	if game_ui.has_method("set_process"):
		game_ui.set_process(false)
	var runtime_modules := [
		game_ui.get("cultivation_module"),
		game_ui.get("chuna_module"),
		game_ui.get("spell_module"),
		game_ui.get("alchemy_module"),
		game_ui.get("lianli_module"),
		game_ui.get("herb_gather_module"),
		game_ui.get("settings_module"),
		game_ui.get("neishi_module")
	]
	for module in runtime_modules:
		if module and is_instance_valid(module):
			if module.has_method("set_process"):
				module.set_process(false)
			if module.has_method("cleanup"):
				module.cleanup()
	if game_ui.get("alchemy_module"):
		game_ui.alchemy_module._is_alchemizing = false
		game_ui.alchemy_module._runtime_tick_in_flight = false
	if game_ui.get("lianli_module"):
		game_ui.lianli_module._is_timeline_running = false
		game_ui.lianli_module._finish_in_flight = false
		game_ui.lianli_module._is_waiting = false

func reset_and_sync(preset_name: String = "") -> void:
	await client.reset_account()
	if not preset_name.is_empty():
		await client.apply_preset(preset_name)
	await sync_full_state()
	clear_logs()
	client.clear_call_counts()

func apply_preset_and_sync(preset_name: String) -> void:
	await client.apply_preset(preset_name)
	await sync_full_state()
	clear_logs()
	client.clear_call_counts()

func sync_full_state() -> Dictionary:
	if game_ui and game_ui.has_method("refresh_all_player_data"):
		await game_ui.refresh_all_player_data()
		return {"success": true}
	return await SERVER_STATE_ADAPTER_SCRIPT.sync_full_state(client, get_game_manager())

func clear_logs() -> void:
	var log_manager = get_log_manager()
	if log_manager and log_manager.has_method("clear_logs"):
		log_manager.clear_logs()

func get_log_messages() -> Array:
	var messages: Array = []
	var log_manager = get_log_manager()
	if not log_manager or not log_manager.has_method("get_logs"):
		return messages
	for entry in log_manager.get_logs():
		if entry is Dictionary:
			messages.append(str(entry.get("raw_message", "")))
	return messages

func last_log() -> String:
	var messages = get_log_messages()
	if messages.is_empty():
		return ""
	return str(messages.back())

func get_log_manager() -> Node:
	if game_ui:
		return game_ui.log_manager
	return null

func get_game_manager() -> Node:
	return get_node_or_null("/root/GameManager")

func get_player() -> Node:
	var game_manager = get_game_manager()
	return game_manager.get_player() if game_manager and game_manager.has_method("get_player") else null

func get_inventory() -> Node:
	var game_manager = get_game_manager()
	return game_manager.get_inventory() if game_manager and game_manager.has_method("get_inventory") else null

func get_spell_system() -> Node:
	var game_manager = get_game_manager()
	return game_manager.get_spell_system() if game_manager and game_manager.has_method("get_spell_system") else null

func get_alchemy_system() -> Node:
	var game_manager = get_game_manager()
	return game_manager.get_alchemy_system() if game_manager and game_manager.has_method("get_alchemy_system") else null

func get_item_data() -> Node:
	var game_manager = get_game_manager()
	return game_manager.get_item_data() if game_manager and game_manager.has_method("get_item_data") else null

func _ensure_client(api_base: String) -> void:
	if client and is_instance_valid(client):
		await client.configure(api_base)
		return
	client = TEST_SERVER_CLIENT_SCRIPT.new()
	client.name = "TestServerClient"
	add_child(client)
	await client.configure(api_base)

func _spawn_game_ui() -> void:
	if game_ui and is_instance_valid(game_ui):
		if game_ui.get_parent() == self:
			remove_child(game_ui)
		game_ui.free()
		await get_tree().process_frame
	game_ui = MAIN_SCENE.instantiate()
	game_ui.name = "TestMainUI"
	add_child(game_ui)
	await get_tree().process_frame
	await get_tree().process_frame
	_bind_api_to_scene()

func _bind_api_to_scene() -> void:
	if not game_ui or not client:
		return
	game_ui.api = client
	if game_ui.has_method("set_background_server_refresh_enabled"):
		game_ui.set_background_server_refresh_enabled(false)
	if game_ui.cultivation_module:
		game_ui.cultivation_module.api = client
		game_ui.cultivation_module.spell_system_ref = get_spell_system()
		var game_manager = get_game_manager()
		game_ui.cultivation_module.realm_system_ref = game_manager.get_realm_system() if game_manager and game_manager.has_method("get_realm_system") else null
	if game_ui.chuna_module:
		game_ui.chuna_module.api = client
		var gm = get_game_manager()
		game_ui.chuna_module.recipe_data_ref = gm.get_recipe_data() if gm and gm.has_method("get_recipe_data") else null
	if game_ui.spell_module:
		game_ui.spell_module.api = client
	if game_ui.alchemy_module:
		game_ui.alchemy_module.api = client
	if game_ui.lianli_module:
		game_ui.lianli_module.api = client
	if game_ui.herb_gather_module:
		game_ui.herb_gather_module.api = client
	if game_ui.settings_module:
		game_ui.settings_module.api = client
