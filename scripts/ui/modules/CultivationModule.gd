class_name CultivationModule extends Node

const AttributeCalculator = preload("res://scripts/calculator/AttributeCalculator.gd")
const ActionLockManager = preload("res://scripts/managers/ActionLockManager.gd")

signal cultivation_started
signal cultivation_stopped
signal breakthrough_succeeded(result: Dictionary)
signal breakthrough_failed(result: Dictionary)
signal log_message(message: String)

var game_ui: Node = null
var player: Node = null
var cultivation_system: Node = null
var lianli_system: Node = null
var item_data: Node = null
var alchemy_module: Node = null
var inventory: Node = null
var api: Node = null

var cultivation_panel: Control = null
var cultivate_button: Button = null
var breakthrough_button: Button = null

var health_bar: ProgressBar = null
var health_value: Label = null
var spirit_bar: ProgressBar = null
var spirit_value: Label = null

var attack_label: Label = null
var defense_label: Label = null
var speed_label: Label = null
var spirit_gain_label: Label = null

var status_label: Label = null
var cultivation_figure: TextureRect = null
var cultivation_figure_particles: TextureRect = null

var _accumulated_seconds: float = 0.0
var _pending_count: int = 0
var _flush_in_flight: bool = false
var _report_failure_count: int = 0

const ACTION_COOLDOWN_SECONDS := 0.1
var _action_lock := ActionLockManager.new()

func initialize(ui: Node, player_node: Node, cult_sys: Node, lianli_sys: Node = null, item_data_ref: Node = null, alchemy_mod: Node = null, game_api: Node = null):
	game_ui = ui
	player = player_node
	cultivation_system = cult_sys
	lianli_system = lianli_sys
	item_data = item_data_ref
	alchemy_module = alchemy_mod
	api = game_api
	set_process(true)

func _process(delta: float):
	if not player or not player.get_is_cultivating():
		return

	_accumulated_seconds += delta
	while _accumulated_seconds >= 1.0:
		_accumulated_seconds -= 1.0
		_optimistic_tick_once()

	if _pending_count >= 5 and not _flush_in_flight:
		call_deferred("_auto_flush_report")

func _optimistic_tick_once():
	if not player:
		return
	
	# 灵气乐观更新
	var spirit_gain = player.get_final_spirit_gain_speed() if player.has_method("get_final_spirit_gain_speed") else 0.0
	if spirit_gain > 0:
		player.add_spirit(spirit_gain)
	
	# 生命乐观更新
	_optimistic_heal_once()
	
	# 术法次数乐观更新
	_optimistic_spell_use_once()
	
	_pending_count += 1

func _optimistic_heal_once():
	var spell_system = _get_spell_system()
	if not spell_system or not spell_system.has_method("get_equipped_breathing_heal_effect"):
		return
	
	var heal_effect = spell_system.get_equipped_breathing_heal_effect()
	var heal_percent = heal_effect.get("heal_amount", 0.0)
	if heal_percent > 0:
		var max_health = player.get_final_max_health()
		player.heal(max_health * heal_percent)

func _optimistic_spell_use_once():
	var spell_system = _get_spell_system()
	if not spell_system:
		return
	
	var breathing_type = -1
	if spell_system.get("spell_data"):
		breathing_type = int(spell_system.spell_data.SpellType.BREATHING)
	
	if breathing_type < 0:
		return
		
	var breathing_spells = spell_system.equipped_spells.get(breathing_type, []) if spell_system.get("equipped_spells") else []
	if not breathing_spells.is_empty():
		var spell_id = str(breathing_spells[0])
		if spell_system.has_method("add_spell_use_count"):
			spell_system.add_spell_use_count(spell_id)

func _get_spell_system() -> Node:
	var spell_system = null
	if game_ui and game_ui.get("spell_system"):
		spell_system = game_ui.spell_system
	if not spell_system:
		var game_manager = get_node_or_null("/root/GameManager")
		spell_system = game_manager.get_spell_system() if game_manager and game_manager.has_method("get_spell_system") else null
	return spell_system

func _auto_flush_report():
	await _flush_pending_report(5)

func _flush_pending_report(max_batch: int = -1) -> bool:
	if _flush_in_flight:
		return false
	if not api:
		return false
	if _pending_count <= 0:
		return true

	_flush_in_flight = true
	var report_count = _pending_count if max_batch <= 0 else mini(_pending_count, max_batch)
	var result = await api.cultivation_report(report_count)
	_flush_in_flight = false

	if result.get("success", false):
		_pending_count = maxi(0, _pending_count - report_count)
		_report_failure_count = 0
		_apply_report_result(result, report_count)
		return true

	_report_failure_count += 1
	var err_msg = api.network_manager.get_api_error_text_for_ui(result, "修炼同步失败")
	if not err_msg.is_empty():
		log_message.emit(err_msg)
	
	if _report_failure_count >= 3:
		log_message.emit("同步异常，已停止修炼")
		await _stop_cultivation_internal(true)
	return false

func _apply_report_result(result: Dictionary, _report_count: int):
	if not player:
		return

	# 在线流中，由于已实现生命和术法次数的乐观更新，
	# 此处不再根据 used_count_gained 重复增加次数，以免双倍计数。
	# 状态最终以 refresh_all_player_data (全量同步) 为准。
	
	if game_ui and game_ui.has_method("update_ui"):
		game_ui.update_ui()

func _sync_breathing_spell_use_count(used_count_gained: int):
	if used_count_gained <= 0:
		return

	var spell_system = null
	if game_ui:
		spell_system = game_ui.get("spell_system")
	if not spell_system:
		var game_manager = get_node_or_null("/root/GameManager")
		spell_system = game_manager.get_spell_system() if game_manager and game_manager.has_method("get_spell_system") else null
	if not spell_system or not spell_system.has_method("add_spell_use_count"):
		return

	var breathing_type = -1
	if spell_system.get("spell_data"):
		breathing_type = int(spell_system.spell_data.SpellType.BREATHING)
	if breathing_type < 0:
		return

	var breathing_spells = spell_system.equipped_spells.get(breathing_type, []) if spell_system.get("equipped_spells") else []
	if breathing_spells.is_empty():
		return

	var spell_id = str(breathing_spells[0])
	for _i in range(used_count_gained):
		spell_system.add_spell_use_count(spell_id)

func flush_pending_and_then(action: Callable) -> bool:
	if _pending_count > 0:
		var ok = await _flush_pending_report()
		if not ok:
			return false
	if action.is_valid():
		action.call()
	return true

func _begin_action_lock(action_key: String) -> bool:
	return _action_lock.try_begin(action_key)

func _end_action_lock(action_key: String):
	_action_lock.end(action_key, ACTION_COOLDOWN_SECONDS)

func show_panel():
	if cultivation_panel:
		cultivation_panel.visible = true
	_update_cultivate_button_state()

func hide_panel():
	if cultivation_panel:
		cultivation_panel.visible = false

func update_cultivate_button_state():
	_update_cultivate_button_state()

func _update_cultivate_button_state():
	if not cultivate_button or not player:
		return
	cultivate_button.text = "停止修炼" if player.get_is_cultivating() else "修炼"

func on_cultivate_button_pressed():
	if not player or not api:
		return
	if not _begin_action_lock("cultivate_toggle"):
		return

	if player.get_is_cultivating():
		await _stop_cultivation_internal(false)
		_end_action_lock("cultivate_toggle")
		return

	if game_ui and game_ui.has_method("can_enter_mode"):
		var enter_check = game_ui.can_enter_mode("cultivation")
		if not enter_check.get("ok", false):
			log_message.emit(enter_check.get("message", "请先结束当前行为"))
			_end_action_lock("cultivate_toggle")
			return

	var result = await api.cultivation_start()
	if result.get("success", false):
		player.cultivation_active = true
		_pending_count = 0
		_accumulated_seconds = 0.0
		_report_failure_count = 0
		if game_ui and game_ui.has_method("set_active_mode"):
			game_ui.set_active_mode("cultivation")
		cultivate_button.text = "停止修炼"
		log_message.emit(result.get("message", "开始修炼"))
		cultivation_started.emit()
	else:
		var err_msg = api.network_manager.get_api_error_text_for_ui(result, "开始修炼失败")
		if not err_msg.is_empty():
			log_message.emit(err_msg)

	_end_action_lock("cultivate_toggle")

func _stop_cultivation_internal(by_failure: bool):
	if not player or not api:
		return

	if _pending_count > 0:
		var flush_ok = await _flush_pending_report()
		if not flush_ok and not by_failure:
			log_message.emit("修炼增量尚未同步，请稍后再试")
			return

	var result = await api.cultivation_stop()
	if result.get("success", false):
		player.cultivation_active = false
		_pending_count = 0
		_accumulated_seconds = 0.0
		if game_ui and game_ui.has_method("clear_active_mode"):
			game_ui.clear_active_mode("cultivation")
		if cultivate_button:
			cultivate_button.text = "修炼"
		if game_ui and game_ui.has_method("refresh_all_player_data"):
			await game_ui.refresh_all_player_data()
		cultivation_stopped.emit()
		if not by_failure:
			log_message.emit(result.get("message", "停止修炼"))

func on_breakthrough_button_pressed():
	if not player or not api:
		return
	if not _begin_action_lock("breakthrough"):
		return

	var settled = await flush_pending_and_then(func(): pass)
	if not settled:
		log_message.emit("突破前修炼同步失败，请稍后重试")
		_end_action_lock("breakthrough")
		return

	var result = await api.player_breakthrough()
	if result.get("success", false):
		var msg = "突破成功"
		if result.has("new_realm") and result.has("new_level"):
			msg = "突破成功，当前境界：%s 第%d层" % [str(result.new_realm), int(result.new_level)]
		log_message.emit(msg)
		
		if game_ui and game_ui.has_method("refresh_all_player_data"):
			await game_ui.refresh_all_player_data()
		
		breakthrough_succeeded.emit(result)
	else:
		# 突破异常，按要求技术性报错由 NetworkManager 处理并在控制台打印，业务逻辑失败才反馈 UI
		var err_msg = api.network_manager.get_api_error_text_for_ui(result, "突破失败")
		if not err_msg.is_empty():
			log_message.emit(err_msg)
		breakthrough_failed.emit(result)

	_end_action_lock("breakthrough")


func update_display(status: Dictionary = {}):
	if not player:
		return

	if status.is_empty():
		status = player.get_status_dict()

	if health_bar:
		var final_max_health = player.get_final_max_health()
		health_bar.max_value = final_max_health
		health_bar.value = status.health
	if health_value:
		var final_max_health2 = player.get_final_max_health()
		health_value.text = AttributeCalculator.format_health_spirit(status.health) + "/" + AttributeCalculator.format_health_spirit(final_max_health2)

	if spirit_bar:
		spirit_bar.max_value = player.get_final_max_spirit_energy()
		spirit_bar.value = status.spirit_energy
	if spirit_value:
		spirit_value.text = AttributeCalculator.format_health_spirit(status.spirit_energy) + "/" + AttributeCalculator.format_health_spirit(player.get_final_max_spirit_energy())

	if attack_label:
		attack_label.text = "攻击: " + AttributeCalculator.format_attack_defense(player.get_final_attack())
	if defense_label:
		defense_label.text = "防御: " + AttributeCalculator.format_attack_defense(player.get_final_defense())
	if speed_label:
		speed_label.text = "速度: " + AttributeCalculator.format_speed(player.get_final_speed())
	if spirit_gain_label:
		spirit_gain_label.text = "灵气获取: " + AttributeCalculator.format_spirit_gain_speed(player.get_final_spirit_gain_speed()) + "/秒"

	if status.is_cultivating:
		if status_label:
			status_label.text = "修炼中..."
			status_label.modulate = Color.GREEN
		if cultivation_figure:
			cultivation_figure.visible = false
		if cultivation_figure_particles:
			cultivation_figure_particles.visible = true
	else:
		if status_label:
			status_label.text = "未修炼"
			status_label.modulate = Color.GRAY
		if cultivation_figure:
			cultivation_figure.visible = true
		if cultivation_figure_particles:
			cultivation_figure_particles.visible = false

	if breakthrough_button:
		breakthrough_button.disabled = false
		var breakthrough_info = status.get("can_breakthrough", {})
		if breakthrough_info.get("type") == "realm":
			breakthrough_button.text = "破境"
		else:
			breakthrough_button.text = "突破"

func cleanup():
	pass
