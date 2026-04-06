class_name SpellModule extends Node

const ActionLockManager = preload("res://scripts/managers/ActionLockManager.gd")

signal spell_equipped(spell_id: String)
signal spell_unequipped(spell_id: String)
signal spell_upgraded(spell_id: String)
signal spell_viewed(spell_id: String)
signal log_message(message: String)

var game_ui: Node = null
var player: Node = null
var spell_system: Node = null
var spell_data: Node = null
var api: Node = null

var spell_panel: Control = null
var spell_tab: Button = null
var spell_detail_popup: SpellDetailPopup = null
var spell_cards: Dictionary = {}
var current_viewing_spell: String = ""
var current_multiplier_index: int = 0

const MULTIPLIERS = [10, 100, 999999]
const MULTIPLIER_LABELS = ["x10", "x100", "Max"]

var _card_pool: Array[Control] = []
var _max_pool_size: int = 30
var _signals_connected: bool = false

const ACTION_COOLDOWN_SECONDS := 0.1
var _action_lock := ActionLockManager.new()

const TYPE_ORDER = ["breathing", "active", "opening", "production"]
const TYPE_NAMES = {
	"breathing": "吐纳心法",
	"active": "主动术法",
	"opening": "开局术法",
	"production": "生产术法"
}

func initialize(ui: Node, player_node: Node, spell_sys: Node, spell_dt: Node, game_api: Node = null):
	game_ui = ui
	player = player_node
	spell_system = spell_sys
	spell_data = spell_dt
	api = game_api
	_setup_signals()

func _setup_signals():
	if _signals_connected:
		return
	if spell_tab and not spell_tab.pressed.is_connected(_on_spell_tab_pressed):
		spell_tab.pressed.connect(_on_spell_tab_pressed)
	_signals_connected = true

func cleanup():
	if spell_tab and spell_tab.pressed.is_connected(_on_spell_tab_pressed):
		spell_tab.pressed.disconnect(_on_spell_tab_pressed)
	if spell_detail_popup:
		spell_detail_popup.cleanup()
		spell_detail_popup = null
	for card in _card_pool:
		if is_instance_valid(card):
			card.queue_free()
	_card_pool.clear()
	spell_cards.clear()
	_signals_connected = false

func show_tab():
	if spell_panel:
		spell_panel.visible = true
	update_spell_ui()
	call_deferred("_refresh_spell_from_server")

func hide_tab():
	if spell_panel:
		spell_panel.visible = false
	_on_spell_detail_close_pressed()

func _on_spell_tab_pressed():
	if game_ui and game_ui.neishi_module:
		game_ui.neishi_module.show_spell_panel()
	else:
		show_tab()

func update_spell_ui():
	if not spell_panel or not spell_system or not spell_data:
		return
	
	var was_viewing_spell = current_viewing_spell
	var was_popup_visible = false
	if spell_detail_popup:
		was_popup_visible = spell_detail_popup.is_popup_visible()
	
	for spell_id in spell_cards.keys():
		var card = spell_cards[spell_id]
		if is_instance_valid(card):
			_return_card_to_pool(card)
	spell_cards.clear()
	
	for child in spell_panel.get_children():
		if child.name != "SpellScrollContainer":
			child.queue_free()
	
	var scroll_container = spell_panel.get_node_or_null("SpellScrollContainer")
	if not scroll_container:
		scroll_container = ScrollContainer.new()
		scroll_container.name = "SpellScrollContainer"
		scroll_container.layout_mode = 1
		scroll_container.anchors_preset = 15
		scroll_container.anchor_right = 1.0
		scroll_container.anchor_bottom = 1.0
		scroll_container.offset_left = 10.0
		scroll_container.offset_top = 10.0
		scroll_container.offset_right = -10.0
		scroll_container.offset_bottom = -10.0
		scroll_container.grow_horizontal = 2
		scroll_container.grow_vertical = 2
		spell_panel.add_child(scroll_container)
	
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	
	var main_vbox = scroll_container.get_node_or_null("MainVBox")
	if not main_vbox:
		main_vbox = VBoxContainer.new()
		main_vbox.name = "MainVBox"
		main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		main_vbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		scroll_container.add_child(main_vbox)
	
	while main_vbox.get_child_count() > 0:
		var c = main_vbox.get_child(0)
		main_vbox.remove_child(c)
		c.queue_free()
	
	var spells = spell_system.get_player_spells()
	if spells == null:
		spells = {}
	
	var spells_by_type: Dictionary = {}
	for spell_id in spells.keys():
		var info = spell_data.get_spell_data(spell_id)
		if info.is_empty():
			continue
		var type_str = info.get("type", "active")
		if not spells_by_type.has(type_str):
			spells_by_type[type_str] = []
		spells_by_type[type_str].append({"id": spell_id, "info": info, "data": spells[spell_id]})
	
	for type_key in TYPE_ORDER:
		if not spells_by_type.has(type_key) or spells_by_type[type_key].is_empty():
			continue
		
		var limit = spell_data.get_equipment_limit(type_key) if spell_data else 1
		var equipped_count = spell_system.get_equipped_count(type_key) if spell_system else 0
		
		var type_label = Label.new()
		if limit < 0:
			type_label.text = TYPE_NAMES.get(type_key, type_key)
		else:
			type_label.text = TYPE_NAMES.get(type_key, type_key) + " " + str(equipped_count) + "/" + str(limit)
		type_label.add_theme_font_size_override("font_size", 18)
		type_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
		main_vbox.add_child(type_label)
		
		var grid = GridContainer.new()
		grid.name = type_key + "_grid"
		grid.columns = 4
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		main_vbox.add_child(grid)
		
		for spell_entry in spells_by_type[type_key]:
			var spell_id = spell_entry.id
			var card = _create_spell_card(spell_id, spell_entry.info, spell_entry.data)
			grid.add_child(card)
			spell_cards[spell_id] = card
		
		var separator = HSeparator.new()
		separator.custom_minimum_size = Vector2(0, 20)
		main_vbox.add_child(separator)
	
	if was_popup_visible and not was_viewing_spell.is_empty() and spell_cards.has(was_viewing_spell):
		_show_spell_detail(was_viewing_spell)

func _create_spell_card(spell_id: String, info: Dictionary, data: Dictionary) -> Control:
	var card: Control
	if _card_pool.size() > 0:
		card = _card_pool.pop_back()
		card.visible = true
	else:
		card = _create_card_template()
	
	var vbox = card.get_child(0) as VBoxContainer
	var name_label = vbox.get_node_or_null("NameLabel") as Label
	var status_label = vbox.get_node_or_null("StatusLabel") as Label
	var button_container = vbox.get_child(2) as HBoxContainer
	var view_btn = button_container.get_node_or_null("ViewButton") as Button
	var equip_btn = button_container.get_node_or_null("EquipButton") as Button
	
	var spell_name = info.get("name", "未知术法")
	if name_label:
		name_label.text = spell_name
	
	var obtained = data.get("obtained", false)
	var level = data.get("level", 0)
	var is_equipped = spell_system.is_spell_equipped(spell_id) if spell_system else false
	var spell_type = info.get("type", "")
	var is_production = (spell_type == "production")
	
	if status_label:
		if not obtained or level <= 0:
			status_label.text = "未获取"
			status_label.add_theme_color_override("font_color", Color.GRAY)
		else:
			status_label.text = "Lv." + str(level)
			if is_equipped:
				status_label.add_theme_color_override("font_color", Color.GREEN)
			else:
				status_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	
	if view_btn:
		for conn in view_btn.pressed.get_connections():
			view_btn.pressed.disconnect(conn.callable)
		view_btn.pressed.connect(_on_view_button_pressed.bind(spell_id))
	
	if equip_btn:
		if is_production:
			equip_btn.visible = false
		else:
			equip_btn.visible = true
			for conn in equip_btn.pressed.get_connections():
				equip_btn.pressed.disconnect(conn.callable)
			
			if obtained and level > 0:
				if is_equipped:
					equip_btn.text = "卸下"
				else:
					equip_btn.text = "装备"
				equip_btn.disabled = false
				equip_btn.pressed.connect(_on_equip_button_pressed.bind(spell_id))
			else:
				equip_btn.text = "装备"
				equip_btn.disabled = true
	
	return card

func _create_card_template() -> Control:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(130, 160)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.95, 0.95, 0.9)
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.border_color = Color(0.7, 0.7, 0.7, 0.8)
	card.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)
	
	var name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	vbox.add_child(name_label)
	
	var status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(status_label)
	
	var button_container = HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_theme_constant_override("separation", 5)
	vbox.add_child(button_container)
	
	var view_button = Button.new()
	view_button.name = "ViewButton"
	view_button.text = "查看"
	button_container.add_child(view_button)
	
	var equip_button = Button.new()
	equip_button.name = "EquipButton"
	button_container.add_child(equip_button)
	
	return card

func _return_card_to_pool(card: Control):
	if card.get_parent():
		card.get_parent().remove_child(card)
	if _card_pool.size() < _max_pool_size:
		_card_pool.append(card)
		card.visible = false
	else:
		card.queue_free()

func _on_view_button_pressed(spell_id: String):
	_show_spell_detail(spell_id)

func _on_equip_button_pressed(spell_id: String):
	current_viewing_spell = spell_id
	_on_spell_equip_toggle()

func _show_spell_detail(spell_id: String):
	current_viewing_spell = spell_id
	if not spell_detail_popup:
		_create_spell_detail_popup()
	_update_spell_detail_popup()
	spell_detail_popup.show_popup()
	spell_viewed.emit(spell_id)

func _create_spell_detail_popup():
	spell_detail_popup = SpellDetailPopup.new()
	spell_detail_popup.name = "SpellDetailPopup"
	add_child(spell_detail_popup)
	spell_detail_popup.setup(self)
	spell_detail_popup.close_requested.connect(_on_spell_detail_close_pressed)
	spell_detail_popup.equip_requested.connect(_on_spell_equip_toggle)
	spell_detail_popup.upgrade_requested.connect(_on_spell_upgrade_pressed)
	spell_detail_popup.charge_requested.connect(_on_spell_charge_pressed)
	spell_detail_popup.multiplier_changed.connect(_on_multiplier_changed)

func _update_spell_detail_popup():
	if not spell_detail_popup or current_viewing_spell.is_empty():
		return
	var info = spell_data.get_spell_data(current_viewing_spell)
	var player_spells = spell_system.get_player_spells()
	var data = player_spells.get(current_viewing_spell, {})
	var display_data = data.duplicate()
	if not display_data.has("id"):
		display_data["id"] = current_viewing_spell
	spell_detail_popup.update_content(display_data, info, spell_system, spell_data, current_multiplier_index, MULTIPLIERS)

func _update_use_count_label_only():
	if spell_detail_popup and not current_viewing_spell.is_empty():
		var player_spells = spell_system.get_player_spells()
		var data = player_spells.get(current_viewing_spell, {})
		var info = spell_data.get_spell_data(current_viewing_spell)
		var display_data = data.duplicate()
		if not display_data.has("id"):
			display_data["id"] = current_viewing_spell
		spell_detail_popup.update_use_count_only(display_data, info, spell_data)

func _on_spell_detail_close_pressed():
	current_viewing_spell = ""
	if spell_detail_popup:
		spell_detail_popup.hide_popup()

func _on_multiplier_changed():
	current_multiplier_index = (current_multiplier_index + 1) % MULTIPLIERS.size()
	if spell_detail_popup:
		_update_spell_detail_popup()

func _on_spell_equip_toggle():
	if current_viewing_spell.is_empty(): return
	if not _begin_action_lock("spell_equip_toggle"): return
	
	var is_currently_equipped = spell_system.is_spell_equipped(current_viewing_spell)
	var slot_type = _get_slot_type_by_spell(current_viewing_spell)
	var result
	if is_currently_equipped:
		result = await api.spell_unequip(current_viewing_spell, slot_type)
	else:
		result = await api.spell_equip(current_viewing_spell, slot_type)
		
	if not result.get("success", false):
		var err_msg = api.network_manager.get_api_error_text_for_ui(result, "术法操作失败")
		if not err_msg.is_empty():
			_add_log(err_msg)
		_end_action_lock("spell_equip_toggle")
		return
	
	if is_currently_equipped:
		spell_system.unequip_spell(current_viewing_spell)
		_add_log("术法卸载成功")
		spell_unequipped.emit(current_viewing_spell)
	else:
		spell_system.equip_spell(current_viewing_spell)
		_add_log("术法装备成功")
		spell_equipped.emit(current_viewing_spell)
		
	update_spell_ui()
	_update_spell_detail_popup()
	_end_action_lock("spell_equip_toggle")

func _on_spell_upgrade_pressed():
	if current_viewing_spell.is_empty(): return
	var result = await api.spell_upgrade(current_viewing_spell)
	if result.get("success", false):
		_add_log("术法升级成功")
		await _refresh_after_spell_action()
		_update_spell_detail_popup()
		spell_upgraded.emit(current_viewing_spell)
	else:
		var err_msg = api.network_manager.get_api_error_text_for_ui(result, "升级失败")
		if not err_msg.is_empty():
			_add_log(err_msg)

func _on_spell_charge_pressed():
	if current_viewing_spell.is_empty(): return
	var multiplier = MULTIPLIERS[current_multiplier_index]
	var result = await api.spell_charge(current_viewing_spell, multiplier)
	if result.get("success", false):
		await _refresh_after_spell_action()
		_update_spell_detail_popup()
	else:
		var err_msg = api.network_manager.get_api_error_text_for_ui(result, "充灵失败")
		if not err_msg.is_empty():
			_add_log(err_msg)

func _refresh_after_spell_action():
	await _refresh_spell_from_server()
	update_spell_ui()

func _refresh_spell_from_server():
	if not api or not spell_system:
		return
	var result = await api.spell_list()
	if not result.get("success", false):
		var err_msg = api.network_manager.get_api_error_text_for_ui(result, "术法同步失败")
		if not err_msg.is_empty():
			_add_log(err_msg)
		return

	var body: Dictionary = result
	if result.has("data") and result["data"] is Dictionary:
		body = result["data"]
	
	if spell_data and spell_data.has_method("apply_remote_config"):
		var remote_spell_config = body.get("spells_config", {})
		if remote_spell_config is Dictionary and not remote_spell_config.is_empty():
			spell_data.apply_remote_config({"spells": remote_spell_config})

	var payload = {
		"player_spells": body.get("player_spells", body.get("spells", {})),
		"equipped_spells": body.get("equipped_spells", {})
	}
	spell_system.apply_save_data(payload)
	update_spell_ui()

func _get_slot_type_by_spell(spell_id: String) -> String:
	if not spell_data:
		return "active"
	var spell_info = spell_data.get_spell_data(spell_id)
	var raw_type = spell_info.get("type", "active")
	var type_str = str(raw_type).to_lower()
	match type_str:
		"breathing", "production":
			return "breathing"
		"active", "attack":
			return "active"
		"passive", "opening":
			return "opening"
		_:
			return "active"

func _add_log(message: String):
	log_message.emit(message)

func get_current_viewing_spell() -> String:
	return current_viewing_spell

func refresh_spell_ui():
	update_spell_ui()

func on_spell_used(spell_id: String):
	if current_viewing_spell == spell_id:
		_update_use_count_label_only()

func _begin_action_lock(action: String) -> bool:
	return _action_lock.try_begin(action)

func _end_action_lock(action: String):
	_action_lock.end(action, ACTION_COOLDOWN_SECONDS)
