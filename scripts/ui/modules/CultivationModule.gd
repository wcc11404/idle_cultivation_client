class_name CultivationModule extends Node

const ATTRIBUTE_CALCULATOR = preload("res://scripts/core/shared/AttributeCalculator.gd")
const ACTION_LOCK_MANAGER = preload("res://scripts/utils/flow/ActionLockManager.gd")
const CULTIVATION_LOGIC = preload("res://scripts/core/cultivation/CultivationSystem.gd")

signal cultivation_started
signal cultivation_stopped
signal breakthrough_succeeded(result: Dictionary)
signal breakthrough_failed(result: Dictionary)
signal log_message(message: String)

var game_ui: Node = null
var player: Node = null
var item_data: Node = null
var inventory: Node = null
var api: Node = null
var spell_system_ref: Node = null
var realm_system_ref: Node = null

var cultivation_panel: Control = null
var cultivate_button: Button = null
var breakthrough_button: Button = null
var breakthrough_material_labels: Array = []

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

var _pending_elapsed_seconds: float = 0.0
var _flush_in_flight: bool = false
var _optimistic_health_regen_accumulator: float = 0.0
var _optimistic_spell_use_accumulator: float = 0.0
var _last_optimistic_update_at: float = 0.0
var _optimistic_tick_accumulator: float = 0.0
var _next_auto_flush_at: float = 0.0

const REPORT_INTERVAL_SECONDS: float = 5.0
const FLUSH_WAIT_MAX_FRAMES: int = 180
const MIN_FLUSH_SECONDS: float = 1.0

const ACTION_COOLDOWN_SECONDS := 0.1
var _action_lock := ACTION_LOCK_MANAGER.new()

func initialize(
	ui: Node,
	player_node: Node,
	_cult_sys: Node,
	_lianli_sys: Node = null,
	item_data_ref: Node = null,
	_alchemy_mod: Node = null,
	game_api: Node = null,
	spell_sys_ref: Node = null,
	realm_sys_ref: Node = null
):
	game_ui = ui
	player = player_node
	item_data = item_data_ref
	api = game_api
	spell_system_ref = spell_sys_ref
	realm_system_ref = realm_sys_ref
	set_process(true)

func _process(_delta: float):
	if not player or not player.get_is_cultivating():
		return
	var elapsed_seconds = _consume_elapsed_since_last_tick()
	if elapsed_seconds <= 0.0:
		return
	_pending_elapsed_seconds += elapsed_seconds
	_optimistic_tick_accumulator += elapsed_seconds
	_apply_optimistic_whole_seconds_from_accumulator()

	var now_sec = Time.get_unix_time_from_system()
	if _pending_elapsed_seconds >= REPORT_INTERVAL_SECONDS and not _flush_in_flight and now_sec >= _next_auto_flush_at:
		call_deferred("_auto_flush_report")

func _consume_elapsed_since_last_tick() -> float:
	var now_sec = Time.get_unix_time_from_system()
	if _last_optimistic_update_at <= 0.0:
		_last_optimistic_update_at = now_sec
		return 0.0
	var elapsed_seconds = maxf(0.0, now_sec - _last_optimistic_update_at)
	_last_optimistic_update_at = now_sec
	return elapsed_seconds

func _apply_optimistic_progress(elapsed_seconds: float):
	if not player:
		return

	# 灵气乐观更新（按真实经过时间结算）
	var spirit_gain = CULTIVATION_LOGIC.calculate_spirit_gain_per_second(player) * elapsed_seconds
	if spirit_gain > 0:
		player.add_spirit(spirit_gain)

	# 生命乐观更新
	_optimistic_heal_by_elapsed(elapsed_seconds)

	# 术法次数乐观更新
	_optimistic_spell_use_by_elapsed(elapsed_seconds)

	if game_ui and game_ui.has_method("update_ui"):
		game_ui.update_ui()

func _apply_optimistic_whole_seconds_from_accumulator() -> void:
	while _optimistic_tick_accumulator >= 1.0:
		_optimistic_tick_accumulator -= 1.0
		_apply_optimistic_progress(1.0)

func _optimistic_heal_by_elapsed(elapsed_seconds: float):
	var exact_regen = CULTIVATION_LOGIC.calculate_health_regen_per_second(player, _get_spell_system())
	var before_whole = int(_optimistic_health_regen_accumulator)
	_optimistic_health_regen_accumulator += exact_regen * elapsed_seconds
	var after_whole = int(_optimistic_health_regen_accumulator)
	var heal_gain = float(maxi(0, after_whole - before_whole))
	if heal_gain > 0.0:
		player.heal(heal_gain)

func _optimistic_spell_use_by_elapsed(elapsed_seconds: float):
	var spell_system = _get_spell_system()
	if not spell_system:
		return

	_optimistic_spell_use_accumulator += elapsed_seconds
	var gained_use_count = int(floor(_optimistic_spell_use_accumulator))
	if gained_use_count <= 0:
		return
	_optimistic_spell_use_accumulator -= float(gained_use_count)

	var breathing_spells = spell_system.equipped_spells.get("breathing", []) if spell_system.get("equipped_spells") else []
	if not breathing_spells.is_empty():
		var spell_id = str(breathing_spells[0])
		if spell_system.has_method("add_spell_use_count"):
			for _i in range(gained_use_count):
				spell_system.add_spell_use_count(spell_id)

func _get_spell_system() -> Node:
	var spell_system = null
	if spell_system_ref and is_instance_valid(spell_system_ref):
		return spell_system_ref
	if game_ui and game_ui.get("spell_system"):
		spell_system = game_ui.spell_system
	if not spell_system:
		var game_manager = get_node_or_null("/root/GameManager")
		spell_system = game_manager.get_spell_system() if game_manager and game_manager.has_method("get_spell_system") else null
	return spell_system

func _get_realm_system() -> Node:
	if realm_system_ref and is_instance_valid(realm_system_ref):
		return realm_system_ref
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager and game_manager.has_method("get_realm_system"):
		return game_manager.get_realm_system()
	return null

func _get_breakthrough_preview() -> Dictionary:
	if not player:
		return {}

	var realm_system = _get_realm_system()
	if not realm_system or not realm_system.has_method("can_breakthrough"):
		return {}

	var realm_name = str(player.get("realm"))
	var realm_level = int(player.get("realm_level"))
	var spirit_energy_current = float(player.get("spirit_energy"))
	var spirit_stone_current = inventory.get_item_count("spirit_stone") if inventory and inventory.has_method("get_item_count") else 0

	var realm_info = realm_system.get_realm_info(realm_name) if realm_system.has_method("get_realm_info") else {}
	var max_level = int(realm_info.get("max_level", 0))
	var is_realm_breakthrough = max_level > 0 and realm_level >= max_level

	var required_materials: Dictionary = {}
	if realm_system.has_method("get_breakthrough_materials"):
		required_materials = realm_system.get_breakthrough_materials(realm_name, realm_level, is_realm_breakthrough)

	var inventory_items := {}
	for material_id in required_materials.keys():
		var current_count = inventory.get_item_count(str(material_id)) if inventory and inventory.has_method("get_item_count") else 0
		inventory_items[str(material_id)] = current_count

	var preview = realm_system.can_breakthrough(
		realm_name,
		realm_level,
		spirit_stone_current,
		int(spirit_energy_current),
		inventory_items
	)
	preview["spirit_energy_current"] = spirit_energy_current
	preview["spirit_stone_current"] = spirit_stone_current
	preview["required_materials"] = required_materials
	preview["inventory_items"] = inventory_items
	return preview

func _get_preview_item_name(item_id: String) -> String:
	if item_data and item_data.has_method("get_item_name"):
		return item_data.get_item_name(item_id)
	return item_id

func _join_text_parts(parts: Array, separator: String) -> String:
	var result := ""
	for i in range(parts.size()):
		if i > 0:
			result += separator
		result += str(parts[i])
	return result

func _format_breakthrough_amount(value: float) -> String:
	return UIUtils.format_display_number(value)

func _get_breakthrough_cost_name(cost_id: String) -> String:
	match cost_id:
		"spirit_energy":
			return "灵气"
		"spirit_stone":
			return "灵石"
		_:
			return _get_preview_item_name(cost_id)

func _format_breakthrough_cost_entry(cost_id: String, amount: Variant) -> String:
	var numeric_amount = float(amount)
	var formatted_amount = _format_breakthrough_amount(numeric_amount)
	if cost_id == "spirit_energy" or cost_id == "spirit_stone":
		return _get_breakthrough_cost_name(cost_id) + formatted_amount
	return "%s x%s" % [_get_breakthrough_cost_name(cost_id), formatted_amount]

func _get_ordered_resource_ids(resources: Dictionary) -> Array:
	var ordered_ids: Array = []
	for special_id in ["spirit_energy", "spirit_stone"]:
		if resources.has(special_id):
			ordered_ids.append(special_id)
	var other_ids: Array = []
	for raw_id in resources.keys():
		var resource_id = str(raw_id)
		if resource_id == "spirit_energy" or resource_id == "spirit_stone":
			continue
		other_ids.append(resource_id)
	other_ids.sort()
	for resource_id in other_ids:
		ordered_ids.append(resource_id)
	return ordered_ids

func _build_breakthrough_resource_text(resources: Dictionary) -> String:
	if resources.is_empty():
		return ""
	var parts: Array = []
	for resource_id in _get_ordered_resource_ids(resources):
		parts.append(_format_breakthrough_cost_entry(resource_id, resources[resource_id]))
	return _join_text_parts(parts, "、")

func _build_breakthrough_success_message(result: Dictionary) -> String:
	var reason_data = result.get("reason_data", {})
	var consumed_resources = reason_data.get("consumed_resources", {})
	if not (consumed_resources is Dictionary):
		consumed_resources = {}
	var resource_text = _build_breakthrough_resource_text(consumed_resources)
	if resource_text.is_empty():
		return "突破成功"
	return "突破成功，消耗了" + resource_text

func _get_breakthrough_missing_parts(preview: Dictionary) -> Array:
	var missing_parts: Array = []
	var energy_cost = float(preview.get("energy_cost", 0.0))
	var energy_current = float(preview.get("spirit_energy_current", 0.0))
	var missing_energy = int(ceil(max(0.0, energy_cost - energy_current)))
	if missing_energy > 0:
		missing_parts.append("灵气" + UIUtils.format_display_number(float(missing_energy)))

	var stone_cost = int(preview.get("stone_cost", 0))
	var stone_current = int(preview.get("stone_current", preview.get("spirit_stone_current", 0)))
	var missing_stone = maxi(0, stone_cost - stone_current)
	if missing_stone > 0:
		missing_parts.append("灵石" + UIUtils.format_display_number(float(missing_stone)))

	var materials = preview.get("materials", {})
	for raw_material_id in materials.keys():
		var material_id = str(raw_material_id)
		var material_info = materials[raw_material_id]
		if not (material_info is Dictionary):
			continue
		var required = int(material_info.get("required", 0))
		var current = int(material_info.get("current", 0))
		var missing_count = maxi(0, required - current)
		if missing_count > 0:
			missing_parts.append("%s x%s" % [_get_preview_item_name(material_id), UIUtils.format_display_number(float(missing_count))])

	return missing_parts

func _build_breakthrough_preview_text(preview: Dictionary) -> String:
	if preview.is_empty():
		return ""

	if bool(preview.get("can", false)):
		return "可破境" if str(preview.get("type", "")) == "realm" else "可突破"

	var reason = str(preview.get("reason", ""))
	var materials = preview.get("materials", {})
	for raw_material_id in materials.keys():
		var material_id = str(raw_material_id)
		var material_info = materials[raw_material_id]
		if not (material_info is Dictionary):
			continue
		var required = int(material_info.get("required", 0))
		var current = int(material_info.get("current", 0))
		if current < required:
			return "%s不足（%s / %s）" % [_get_preview_item_name(material_id), UIUtils.format_display_number(float(current)), UIUtils.format_display_number(float(required))]

	if reason == "灵气不足":
		var current_energy = float(preview.get("energy_current", preview.get("spirit_energy_current", 0.0)))
		var required_energy = float(preview.get("energy_cost", 0.0))
		return "灵气不足（%s / %s）" % [_format_breakthrough_amount(current_energy), _format_breakthrough_amount(required_energy)]

	if reason == "灵石不足":
		var current_stone = float(preview.get("stone_current", preview.get("spirit_stone_current", 0.0)))
		var required_stone = float(preview.get("stone_cost", 0.0))
		return "灵石不足（%s / %s）" % [_format_breakthrough_amount(current_stone), _format_breakthrough_amount(required_stone)]

	if not reason.is_empty():
		return reason

	var missing_parts = _get_breakthrough_missing_parts(preview)
	if not missing_parts.is_empty():
		return "缺少" + _join_text_parts(missing_parts, "、")

	return "暂不可突破"

func _build_breakthrough_panel_material_entries(preview: Dictionary) -> Array:
	var entries: Array = []

	var energy_required = int(preview.get("energy_cost", 0))
	if energy_required > 0:
		var energy_current = int(floor(float(preview.get("spirit_energy_current", 0.0))))
		entries.append("灵气：%s / %s" % [UIUtils.format_display_number(float(energy_current)), UIUtils.format_display_number(float(energy_required))])

	var stone_required = int(preview.get("stone_cost", 0))
	if stone_required > 0:
		var stone_current = int(preview.get("stone_current", preview.get("spirit_stone_current", 0)))
		entries.append("灵石：%s / %s" % [UIUtils.format_display_number(float(stone_current)), UIUtils.format_display_number(float(stone_required))])

	var materials = preview.get("materials", {})
	if materials is Dictionary:
		var material_ids: Array[String] = []
		for raw_id in materials.keys():
			material_ids.append(str(raw_id))
		material_ids.sort()
		for material_id in material_ids:
			var material_info = materials.get(material_id, {})
			if not (material_info is Dictionary):
				continue
			var current = int(material_info.get("current", 0))
			var required = int(material_info.get("required", 0))
			entries.append("%s：%s / %s" % [_get_preview_item_name(material_id), UIUtils.format_display_number(float(current)), UIUtils.format_display_number(float(required))])
			if entries.size() >= 3:
				break

	return entries

func _resolve_breakthrough_failure_message(result: Dictionary) -> String:
	var reason_code = str(result.get("reason_code", ""))
	var reason_data = result.get("reason_data", {})
	match reason_code:
		"CULTIVATION_BREAKTHROUGH_INSUFFICIENT_RESOURCES":
			var missing_resources = reason_data.get("missing_resources", {})
			if missing_resources is Dictionary and not missing_resources.is_empty():
				return "突破失败，缺少" + _build_breakthrough_resource_text(missing_resources)
			return "突破失败，资源不足"
		"CULTIVATION_BREAKTHROUGH_NOT_AVAILABLE":
			return "当前境界已无法继续突破"
		_:
			return api.network_manager.get_api_error_text_for_ui(result, "突破失败")

func _resolve_cultivation_result_message(result: Dictionary, fallback: String = "") -> String:
	var reason_code = str(result.get("reason_code", ""))
	match reason_code:
		"CULTIVATION_START_SUCCEEDED":
			return "开始修炼"
		"CULTIVATION_START_ALREADY_ACTIVE":
			return "已在修炼状态"
		"CULTIVATION_START_BLOCKED_BY_BATTLE":
			return "正在战斗中，无法开始修炼"
		"CULTIVATION_START_BLOCKED_BY_ALCHEMY":
			return "正在炼丹中，无法开始修炼"
		"CULTIVATION_START_BLOCKED_BY_HERB_GATHERING":
			return "正在采集中，无法开始修炼"
		"CULTIVATION_REPORT_NOT_ACTIVE":
			return "当前未在修炼状态"
		"CULTIVATION_REPORT_TIME_INVALID":
			return "修炼同步异常，请稍后重试"
		"CULTIVATION_STOP_SUCCEEDED":
			return "停止修炼"
		"CULTIVATION_STOP_NOT_ACTIVE":
			return "当前未在修炼状态"
		"CULTIVATION_BREAKTHROUGH_SUCCEEDED":
			return _build_breakthrough_success_message(result)
		"CULTIVATION_BREAKTHROUGH_INSUFFICIENT_RESOURCES", "CULTIVATION_BREAKTHROUGH_NOT_AVAILABLE":
			return _resolve_breakthrough_failure_message(result)
		_:
			return api.network_manager.get_api_error_text_for_ui(result, fallback)

func _get_local_breakthrough_block_message() -> String:
	var preview = _get_breakthrough_preview()
	if preview.is_empty():
		return ""
	if bool(preview.get("can", false)):
		return ""
	return _build_breakthrough_preview_text(preview)

func _auto_flush_report():
	await _flush_pending_report()

func _flush_pending_report(max_elapsed_seconds: float = -1.0) -> bool:
	if _flush_in_flight:
		return await _wait_for_existing_flush_and_check_pending(max_elapsed_seconds)
	if not api:
		return false
	if _pending_elapsed_seconds <= 0.0:
		return true

	_flush_in_flight = true
	var pending_window = _pending_elapsed_seconds if max_elapsed_seconds <= 0.0 else minf(_pending_elapsed_seconds, max_elapsed_seconds)
	if pending_window < MIN_FLUSH_SECONDS:
		# 仅当本地已经发生过至少 1 次整秒乐观结算时才执行 flush。
		# 小于 1 秒的累计不触发同步，留待后续继续累计。
		_flush_in_flight = false
		return true
	var report_elapsed_seconds = pending_window
	var result = await api.cultivation_report(report_elapsed_seconds)
	_flush_in_flight = false

	if result.get("success", false):
		# 只清已上报的 report 累计，不清乐观累计余量。
		_pending_elapsed_seconds = maxf(0.0, _pending_elapsed_seconds - report_elapsed_seconds)
		_next_auto_flush_at = Time.get_unix_time_from_system() + REPORT_INTERVAL_SECONDS
		_apply_report_result(result, report_elapsed_seconds)
		return true

	_next_auto_flush_at = Time.get_unix_time_from_system() + REPORT_INTERVAL_SECONDS
	var err_msg = _resolve_cultivation_result_message(result, "修炼同步失败")
	if not err_msg.is_empty():
		log_message.emit(err_msg)
	return false

func _wait_for_existing_flush_and_check_pending(max_elapsed_seconds: float = -1.0) -> bool:
	var remaining_frames = FLUSH_WAIT_MAX_FRAMES
	while _flush_in_flight and remaining_frames > 0:
		remaining_frames -= 1
		await get_tree().process_frame
	if _flush_in_flight:
		return false
	var pending_window = _pending_elapsed_seconds if max_elapsed_seconds <= 0.0 else minf(_pending_elapsed_seconds, max_elapsed_seconds)
	if pending_window < MIN_FLUSH_SECONDS:
		return true
	# 前一轮 flush 结束后若仍有可上报整秒，继续补一次 flush，
	# 避免调用方误判为“同步失败”。
	return await _flush_pending_report(max_elapsed_seconds)

func _apply_report_result(result: Dictionary, _report_elapsed_seconds: float):
	if not player:
		return

	# 在线流中，由于已实现生命和术法次数的乐观更新，
	# 此处不再根据 used_count_gained 重复增加次数，以免双倍计数。
	# 状态最终以 refresh_all_player_data (全量同步) 为准。
	
	if game_ui and game_ui.has_method("update_ui"):
		game_ui.update_ui()

func flush_pending_and_then(action: Callable) -> bool:
	_settle_pending_optimistic_progress_now()
	if _pending_elapsed_seconds > 0.0:
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
		_pending_elapsed_seconds = 0.0
		_last_optimistic_update_at = Time.get_unix_time_from_system()
		_optimistic_tick_accumulator = 0.0
		_next_auto_flush_at = Time.get_unix_time_from_system() + REPORT_INTERVAL_SECONDS
		_optimistic_health_regen_accumulator = 0.0
		_optimistic_spell_use_accumulator = 0.0
		if game_ui and game_ui.has_method("set_active_mode"):
			game_ui.set_active_mode("cultivation")
		cultivate_button.text = "停止修炼"
		log_message.emit(_resolve_cultivation_result_message(result, "开始修炼"))
		cultivation_started.emit()
	else:
		var err_msg = _resolve_cultivation_result_message(result, "开始修炼失败")
		if not err_msg.is_empty():
			log_message.emit(err_msg)

	_end_action_lock("cultivate_toggle")

func _stop_cultivation_internal(by_failure: bool):
	if not player or not api:
		return

	_settle_pending_optimistic_progress_now()
	if _pending_elapsed_seconds > 0.0:
		var flush_ok = await _flush_pending_report()
		if not flush_ok and not by_failure:
			log_message.emit("修炼同步异常，正在尝试停止修炼")

	var result = await api.cultivation_stop()
	if result.get("success", false):
		player.cultivation_active = false
		_pending_elapsed_seconds = 0.0
		_last_optimistic_update_at = 0.0
		_optimistic_tick_accumulator = 0.0
		_optimistic_health_regen_accumulator = 0.0
		_optimistic_spell_use_accumulator = 0.0
		_next_auto_flush_at = 0.0
		if game_ui and game_ui.has_method("clear_active_mode"):
			game_ui.clear_active_mode("cultivation")
		if cultivate_button:
			cultivate_button.text = "修炼"
			if game_ui and game_ui.has_method("refresh_all_player_data"):
				await game_ui.refresh_all_player_data()
				cultivation_stopped.emit()
				if not by_failure:
					log_message.emit(_resolve_cultivation_result_message(result, "停止修炼"))
	elif not by_failure:
		var err_msg = _resolve_cultivation_result_message(result, "停止修炼失败")
		if not err_msg.is_empty():
			log_message.emit(err_msg)

func on_breakthrough_button_pressed():
	if not player or not api:
		return
	if not _begin_action_lock("breakthrough"):
		return

	var local_block_msg = _get_local_breakthrough_block_message()
	if not local_block_msg.is_empty():
		log_message.emit(local_block_msg)
		_end_action_lock("breakthrough")
		return

	var settled = await flush_pending_and_then(func(): pass)
	if not settled:
		log_message.emit("突破前修炼同步失败，请稍后重试")
		_end_action_lock("breakthrough")
		return

	var result = await api.player_breakthrough()
	if result.get("success", false):
		var msg = _resolve_cultivation_result_message(result, "突破成功")
		log_message.emit(msg)
		
		if game_ui and game_ui.has_method("refresh_all_player_data"):
			await game_ui.refresh_all_player_data()
		
		breakthrough_succeeded.emit(result)
	else:
		var err_msg = _resolve_cultivation_result_message(result, "突破失败")
		if not err_msg.is_empty():
			log_message.emit(err_msg)
		breakthrough_failed.emit(result)

	_end_action_lock("breakthrough")

func _settle_pending_optimistic_progress_now() -> void:
	if not player or not player.get_is_cultivating():
		return
	var elapsed_seconds = _consume_elapsed_since_last_tick()
	if elapsed_seconds <= 0.0:
		return
	_pending_elapsed_seconds += elapsed_seconds
	_optimistic_tick_accumulator += elapsed_seconds
	_apply_optimistic_whole_seconds_from_accumulator()

func reset_local_runtime_state(clear_pending: bool = true) -> void:
	_last_optimistic_update_at = 0.0
	_optimistic_tick_accumulator = 0.0
	_optimistic_health_regen_accumulator = 0.0
	_optimistic_spell_use_accumulator = 0.0
	_next_auto_flush_at = 0.0
	_flush_in_flight = false
	if clear_pending:
		_pending_elapsed_seconds = 0.0


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
		health_value.text = UIUtils.format_display_number_integer(status.health) + " / " + UIUtils.format_display_number_integer(final_max_health2)

	if spirit_bar:
		spirit_bar.max_value = player.get_final_max_spirit_energy()
		spirit_bar.value = status.spirit_energy
	if spirit_value:
		spirit_value.text = UIUtils.format_display_number_integer(status.spirit_energy) + " / " + UIUtils.format_display_number_integer(player.get_final_max_spirit_energy())

	if attack_label:
		attack_label.text = "攻击: " + UIUtils.format_display_number(player.get_final_attack())
	if defense_label:
		defense_label.text = "防御: " + UIUtils.format_display_number(player.get_final_defense())
	if speed_label:
		speed_label.text = "速度: " + UIUtils.format_display_number(player.get_final_speed())
	if spirit_gain_label:
		spirit_gain_label.text = "灵气获取: " + UIUtils.format_display_number(player.get_final_spirit_gain_speed()) + "/秒"

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
		var preview = _get_breakthrough_preview()
		breakthrough_button.tooltip_text = ""
		if not breakthrough_material_labels.is_empty():
			var entries = _build_breakthrough_panel_material_entries(preview)
			for i in range(breakthrough_material_labels.size()):
				var label = breakthrough_material_labels[i]
				if not (label is Label):
					continue
				if i < entries.size():
					label.visible = true
					label.text = str(entries[i])
				else:
					label.visible = false

func cleanup():
	pass
