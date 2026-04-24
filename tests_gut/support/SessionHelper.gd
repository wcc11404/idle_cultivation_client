extends RefCounted

class_name SessionHelper

const SERVER_CONFIG_SCRIPT = preload("res://scripts/network/ServerConfig.gd")

static func reset_local_session(api_base: String = SERVER_CONFIG_SCRIPT.DEFAULT_API_BASE) -> void:
	_clear_session_files()
	SERVER_CONFIG_SCRIPT.set_api_base(api_base)
	var network_manager = _get_global_network_manager()
	if network_manager and network_manager.has_method("clear_token"):
		network_manager.clear_token()
	if network_manager and network_manager.has_method("load_token"):
		network_manager.load_token()

static func _clear_session_files() -> void:
	for path in [SERVER_CONFIG_SCRIPT.TOKEN_FILE, SERVER_CONFIG_SCRIPT.SERVER_CONFIG_FILE]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

static func _get_global_network_manager() -> Node:
	var main_loop = Engine.get_main_loop()
	if main_loop is SceneTree:
		return main_loop.root.get_node_or_null("/root/GlobalNetworkManager")
	return null
