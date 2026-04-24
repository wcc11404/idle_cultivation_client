extends RefCounted

class_name ServerStateAdapter

static func apply_game_data(game_manager: Node, data: Dictionary) -> void:
	if not game_manager:
		return
	if data.has("account_info"):
		game_manager.apply_save_data(data.account_info)

	var player = game_manager.get_player() if game_manager.has_method("get_player") else null
	var inventory = game_manager.get_inventory() if game_manager.has_method("get_inventory") else null
	var spell_system = game_manager.get_spell_system() if game_manager.has_method("get_spell_system") else null
	var lianli_system = game_manager.get_lianli_system() if game_manager.has_method("get_lianli_system") else null
	var alchemy_system = game_manager.get_alchemy_system() if game_manager.has_method("get_alchemy_system") else null

	if player and data.has("player"):
		player.apply_save_data(data.player)
	if inventory and data.has("inventory"):
		inventory.apply_save_data(data.inventory)
	if spell_system and data.has("spell_system"):
		spell_system.apply_save_data(data.spell_system)
	if lianli_system and data.has("lianli_system"):
		lianli_system.apply_save_data(data.lianli_system)
	if alchemy_system and data.has("alchemy_system"):
		alchemy_system.apply_save_data(data.alchemy_system)

static func sync_full_state(client: Node, game_manager: Node) -> Dictionary:
	if not client:
		return {"success": false}
	var result = await client.load_game()
	if result.get("success", false):
		apply_game_data(game_manager, result.get("data", {}))
	return result

static func sync_inventory(client: Node, inventory: Node) -> Dictionary:
	if not client:
		return {"success": false}
	var result = await client.inventory_list()
	if result.get("success", false) and inventory and result.get("inventory", {}) is Dictionary:
		inventory.apply_save_data(result.get("inventory", {}))
	return result

static func sync_spells(client: Node, spell_system: Node, spell_data: Node = null) -> Dictionary:
	if not client:
		return {"success": false}
	var result = await client.spell_list()
	if result.get("success", false) and spell_system:
		if spell_data and spell_data.has_method("apply_remote_config"):
			var remote_spell_config = result.get("spells_config", {})
			if remote_spell_config is Dictionary and not remote_spell_config.is_empty():
				spell_data.apply_remote_config({"spells": remote_spell_config})
		spell_system.apply_save_data({
			"player_spells": result.get("player_spells", {}),
			"equipped_spells": result.get("equipped_spells", {})
		})
	return result
