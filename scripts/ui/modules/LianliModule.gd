class_name LianliModule extends Node

## 历练模块 - 管理历练和无尽塔功能
## 包括战斗UI更新、战斗控制、战斗日志等
const ACTION_LOCK_MANAGER = preload("res://scripts/utils/flow/ActionLockManager.gd")
const UI_UTILS = preload("res://scripts/utils/UIUtils.gd")

# 信号
signal log_message(message: String)
signal battle_log_message(message: String)
signal battle_ended(victory: bool, loot: Array, enemy_name: String)
signal lianli_waiting(time_remaining: float)
signal continue_button_enabled

# 引用
var game_ui: Node = null
var player: Node = null
var lianli_system: Node = null
var lianli_area_data: Node = null
var item_data_ref: Node = null
var inventory: Node = null
var chuna_module: Node = null
var log_manager: Node = null
var alchemy_module: Node = null
var api: Node = null
var spell_data: Node = null
var spell_system: Node = null

# UI节点引用（由GameUI设置）
var lianli_panel: Control = null
var lianli_scene_panel: Control = null
var lianli_select_panel: Control = null
var lianli_status_label: Label = null
var area_name_label: Label = null
var reward_info_label: Label = null

# 战斗UI
var enemy_name_label: Label = null
var enemy_health_bar: ProgressBar = null
var enemy_health_value: Label = null
var player_health_bar_lianli: ProgressBar = null
var player_health_value_lianli: Label = null

# 控制按钮
var continuous_checkbox: CheckBox = null
var continue_button: Button = null
var lianli_speed_button: Button = null
var exit_lianli_button: Button = null

# 状态
var current_lianli_area_id: String = ""
var current_battle_max_speed: float = 1.0

# 历练速度选项
const LIANLI_SPEEDS = [1.0, 1.5, 2.0]
const DEFAULT_LIANLI_SPEED := 1.0
const LIANLI_SPEED_BLOCKED_MESSAGE := "达到金丹境界以后可以开启1.5倍速，开通VIP可以开启2倍速"
var current_lianli_speed: float = DEFAULT_LIANLI_SPEED
var available_lianli_speeds: Array = [DEFAULT_LIANLI_SPEED]

var _battle_timeline: Array = []
var _timeline_cursor: int = 0
var _timeline_elapsed: float = 0.0
var _timeline_total: float = 0.0
var _is_timeline_running: bool = false
var _simulate_victory: bool = false
var _simulate_loot: Array = []
var _current_enemy_data: Dictionary = {}
var _finish_in_flight: bool = false
var _simulated_player_health_after: float = 0.0
var _simulated_player_max_health: float = 0.0
var _enemy_hp_tween: Tween = null
var _player_hp_tween: Tween = null
var _finish_time_invalid_prompted: bool = false

# 等待状态
var _is_waiting: bool = false
var _wait_timer: float = 0.0
var _wait_interval: float = 4.0
const BASE_WAIT_INTERVAL_MIN: float = 3.0
const BASE_WAIT_INTERVAL_MAX: float = 5.0

const ACTION_COOLDOWN_SECONDS := 0.1
var _action_lock := ACTION_LOCK_MANAGER.new()

func _begin_action_lock(action_key: String) -> bool:
	return _action_lock.try_begin(action_key)

func _end_action_lock(action_key: String):
	_action_lock.end(action_key, ACTION_COOLDOWN_SECONDS)

func _set_local_lianli_state(active: bool, in_battle: bool = false, waiting: bool = false, area_id: String = current_lianli_area_id):
	if not lianli_system:
		return
	lianli_system.is_in_lianli = active
	lianli_system.is_in_battle = in_battle
	lianli_system.is_waiting = waiting
	if active:
		lianli_system.current_area_id = area_id
		if lianli_area_data:
			lianli_system.is_in_tower = lianli_area_data.is_tower_area(area_id)
			if lianli_system.is_in_tower and lianli_system.current_tower_floor <= 0:
				lianli_system.current_tower_floor = max(1, int(lianli_system.tower_highest_floor) + 1)
		else:
			lianli_system.is_in_tower = false
	else:
		lianli_system.current_area_id = ""
		lianli_system.is_in_tower = false
		lianli_system.current_tower_floor = 0

func _get_lianli_result_message(result: Dictionary, fallback: String = "") -> String:
	var reason_code = str(result.get("reason_code", ""))
	match reason_code:
		"LIANLI_SIMULATE_BLOCKED_BY_CULTIVATION":
			return "正在修炼中，无法开始历练"
		"LIANLI_SIMULATE_BLOCKED_BY_ALCHEMY":
			return "正在炼丹中，无法开始历练"
		"LIANLI_SIMULATE_BLOCKED_BY_HERB_GATHERING":
			return "正在采集中，无法开始历练"
		"LIANLI_SIMULATE_HEALTH_INSUFFICIENT":
			return "气血不足，无法进入历练区域"
		"LIANLI_SIMULATE_TOWER_CLEARED":
			return "已达无尽塔最高层"
		"LIANLI_SIMULATE_DAILY_LIMIT_REACHED":
			return "今日副本次数已用完"
		"LIANLI_SIMULATE_SUCCEEDED":
			return ""
		"LIANLI_FINISH_NOT_ACTIVE":
			return "当前未在历练战斗中"
		"LIANLI_FINISH_SPEED_INVALID":
			return "当前倍速未解锁，请重新选择历练倍速"
		"LIANLI_FINISH_TIME_INVALID":
			return "历练结算同步异常，请稍后重试"
		"LIANLI_FINISH_FULLY_SETTLED", "LIANLI_FINISH_PARTIALLY_SETTLED":
			return ""
		_:
			return api.network_manager.get_api_error_text_for_ui(result, fallback)

func _ready():
	set_process(true)

func initialize(ui: Node, player_node: Node, lianli_sys: Node, 
					area_data: Node = null, 
					item_data: Node = null, inv: Node = null, 
					chuna: Node = null, log_mgr: Node = null, alchemy_mod: Node = null, 
					game_api: Node = null,
					spell_data_node: Node = null, spell_system_node: Node = null):
	game_ui = ui
	player = player_node
	lianli_system = lianli_sys
	lianli_area_data = area_data
	item_data_ref = item_data
	inventory = inv
	chuna_module = chuna
	log_manager = log_mgr
	alchemy_module = alchemy_mod
	api = game_api
	spell_data = spell_data_node
	spell_system = spell_system_node
	_update_lianli_speed_button_text()
	_update_battle_info()

func _process(delta: float):
	# 处理等待状态
	if _is_waiting:
		_wait_timer += delta
		var time_remaining = max(0.0, _wait_interval - _wait_timer)
		on_lianli_waiting(time_remaining)
		
		if _wait_timer >= _wait_interval:
			_wait_timer = 0.0
			_is_waiting = false
			await _simulate_next_battle()
		return
	
	if not _is_timeline_running or _finish_in_flight:
		return

	var speed = current_lianli_speed
	_timeline_elapsed += delta * speed
	# 更新本次战斗的最大速度
	if speed > current_battle_max_speed:
		current_battle_max_speed = speed

	while _timeline_cursor < _battle_timeline.size() and float(_battle_timeline[_timeline_cursor].get("time", 0.0)) <= _timeline_elapsed:
		var event = _battle_timeline[_timeline_cursor]
		var next_event_time = 0.0
		if _timeline_cursor + 1 < _battle_timeline.size():
			next_event_time = float(_battle_timeline[_timeline_cursor + 1].get("time", 0.0))
		else:
			next_event_time = _timeline_total
		
		var duration = max(0.01, (next_event_time - float(event.get("time", 0.0))) / speed)
		_apply_timeline_event(event, duration)
		_timeline_cursor += 1

	if _timeline_cursor >= _battle_timeline.size():
		_is_timeline_running = false
		_finish_in_flight = true
		await _finish_current_battle(true)
		_finish_in_flight = false

func _process_battle_event(event: Dictionary, duration: float) -> void:
	var event_type = str(event.get("type", ""))
	var info = event.get("info", {})
	if not (info is Dictionary):
		return
	
	var spell_id = str(info.get("spell_id", "norm_attack"))
	
	if event_type == "player_action":
		var enemy_health_after = float(info.get("target_health_after", info.get("self_health_after", enemy_health_bar.value if enemy_health_bar else 0.0)))
		if info.has("target_health_after"):
			_animate_health_bar(enemy_health_bar, enemy_health_value, max(0.0, enemy_health_after), duration, true)
		elif info.has("self_health_after") and player_health_bar_lianli:
			_simulated_player_health_after = enemy_health_after
			_simulated_player_max_health = float(info.get("self_max_health_after", _simulated_player_max_health))
			player_health_bar_lianli.max_value = _simulated_player_max_health
			if player_health_value_lianli:
				player_health_value_lianli.text = _format_health_pair(max(0.0, enemy_health_after), _simulated_player_max_health)
			_animate_health_bar(player_health_bar_lianli, player_health_value_lianli, max(0.0, enemy_health_after), duration, false)
		
		_update_spell_proficiency(spell_id)
	else:
		var player_health_after = float(info.get("target_health_after", _simulated_player_health_after))
		_simulated_player_health_after = player_health_after
		_animate_health_bar(player_health_bar_lianli, player_health_value_lianli, max(0.0, player_health_after), duration, false)
	
	var log_msg = _generate_battle_log_message(event)
	if not log_msg.is_empty():
		if log_manager:
			log_manager.add_battle_log(log_msg)
		else:
			log_message.emit(log_msg)

func _generate_battle_log_message(event: Dictionary) -> String:
	var event_type = str(event.get("type", ""))
	var info = event.get("info", {})
	if not (info is Dictionary):
		return ""
	
	var effect_type = str(info.get("effect_type", ""))
	var spell_id = str(info.get("spell_id", "norm_attack"))
	
	var actor_name: String
	var target_name: String
	
	if event_type == "player_action":
		actor_name = "玩家"
		target_name = str(_current_enemy_data.get("name", "敌人"))
	else:
		actor_name = str(_current_enemy_data.get("name", "敌人"))
		target_name = "玩家"
	
	var spell_name = spell_id
	if spell_data:
		spell_name = spell_data.get_spell_name(spell_id)
	
	if effect_type == "undispellable_buff":
		var log_effect = str(info.get("log_effect", ""))
		return actor_name + "使用" + spell_name + "，" + log_effect
	elif effect_type == "instant_damage":
		var damage = info.get("damage", 0.0)
		var damage_str = UI_UTILS.format_display_number(float(damage))
		return actor_name + "使用" + spell_name + "对" + target_name + "造成" + damage_str + "点伤害"
	
	return ""

func _update_spell_proficiency(spell_id: String) -> void:
	if spell_id == "norm_attack":
		return
	
	if not spell_system:
		return
	
	spell_system.add_spell_use_count(spell_id)

func _apply_timeline_event(event: Dictionary, duration: float = 0.12):
	_process_battle_event(event, duration)

func _animate_health_bar(bar: ProgressBar, value_label: Label, target_health: float, duration: float, is_enemy: bool):
	if not bar:
		return

	var clamped_target = clamp(target_health, 0.0, bar.max_value)
	if value_label:
		value_label.text = _format_health_pair(clamped_target, bar.max_value)

	var tween_duration = clamp(duration, 0.12, 0.35)

	if is_enemy:
		if _enemy_hp_tween:
			_enemy_hp_tween.kill()
		_enemy_hp_tween = create_tween()
		_enemy_hp_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_enemy_hp_tween.tween_property(bar, "value", clamped_target, tween_duration)
	else:
		if _player_hp_tween:
			_player_hp_tween.kill()
		_player_hp_tween = create_tween()
		_player_hp_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_player_hp_tween.tween_property(bar, "value", clamped_target, tween_duration)

func _start_timeline_from_simulation(sim_result: Dictionary, area_id: String):
	_battle_timeline = sim_result.get("battle_timeline", [])
	_timeline_cursor = 0
	_timeline_elapsed = 0.0
	_timeline_total = float(sim_result.get("total_time", 0.0))
	_simulate_victory = bool(sim_result.get("victory", false))
	_simulate_loot = sim_result.get("loot", [])
	_current_enemy_data = sim_result.get("enemy_data", {})
	_simulated_player_health_after = float(sim_result.get("player_health_after", player.health if player else 0.0))
	_simulated_player_max_health = player.get_combat_max_health() if player else 0.0
	current_lianli_area_id = area_id
	_finish_time_invalid_prompted = false
	# 初始化本次战斗的最大速度
	current_battle_max_speed = current_lianli_speed

	if game_ui and game_ui.has_method("set_active_mode"):
		game_ui.set_active_mode("lianli")
	_set_local_lianli_state(true, true, false, area_id)
	show_lianli_scene_panel()

	if enemy_name_label:
		enemy_name_label.text = str(_current_enemy_data.get("name", "敌人")) + " Lv." + str(int(_current_enemy_data.get("level", 1)))
	if enemy_health_bar:
		var enemy_max_hp = float(_current_enemy_data.get("health", 1.0))
		enemy_health_bar.step = 0.01
		enemy_health_bar.max_value = enemy_max_hp
		enemy_health_bar.value = enemy_max_hp
	if enemy_health_value and enemy_health_bar:
		enemy_health_value.text = _format_health_pair(enemy_health_bar.value, enemy_health_bar.max_value)

	if player and player_health_bar_lianli:
		var player_max_hp = player.get_combat_max_health()
		_simulated_player_max_health = player_max_hp
		player_health_bar_lianli.step = 0.01
		player_health_bar_lianli.max_value = player_max_hp
		player_health_bar_lianli.value = player.health
	if player_health_value_lianli and player_health_bar_lianli:
		player_health_value_lianli.text = _format_health_pair(player_health_bar_lianli.value, player_health_bar_lianli.max_value)

	if lianli_status_label:
		lianli_status_label.text = "战斗中..."
		lianli_status_label.modulate = Color.YELLOW

	# 进入战斗场景后立即刷新一次区域/奖励信息，避免首次进入显示为空。
	_update_battle_info()

	_set_continuous_default()
	_update_button_container()
	_is_timeline_running = true

func _format_health_pair(current: float, maximum: float) -> String:
	return "%s / %s" % [
		UI_UTILS.format_display_number_integer(current),
		UI_UTILS.format_display_number_integer(maximum)
	]

func _finish_current_battle(full_settle: bool):
	if not api:
		log_message.emit("网络接口未初始化")
		return

	var settle_index = null
	if not full_settle:
		# 用户在首个战斗事件前点击退出时，使用 -1 表示“仅退出不结算任何事件”。
		# 其余场景保持按已处理事件索引部分结算。
		if _timeline_cursor <= 0:
			settle_index = -1
		else:
			settle_index = max(0, _timeline_cursor - 1)
	# 使用本次战斗的最大速度
	var finish_result = await api.lianli_finish(current_battle_max_speed, settle_index)
	if not finish_result.get("success", false):
		var err_msg = _get_lianli_result_message(finish_result, "历练结算失败")
		var reason_code = str(finish_result.get("reason_code", ""))
		var should_show_msg = true
		if reason_code == "LIANLI_FINISH_TIME_INVALID":
			should_show_msg = not _finish_time_invalid_prompted
			_finish_time_invalid_prompted = true
		if should_show_msg and not err_msg.is_empty():
			log_message.emit(err_msg + "，已退出历练")
		_on_force_exit_lianli()
		return

	if game_ui and game_ui.has_method("refresh_all_player_data"):
		await game_ui.refresh_all_player_data()
	elif game_ui and game_ui.has_method("update_ui"):
		game_ui.update_ui()

	if full_settle:
		var settle_loot: Array = finish_result.get("loot_gained", _simulate_loot)
		var battle_victory = _simulate_victory

		# 战斗结果日志
		if battle_victory:
			if log_manager:
				log_manager.add_battle_log("战斗胜利！")
		else:
			if log_manager:
				log_manager.add_battle_log("气血不足，停止战斗")

		# 掉落奖励日志
		if battle_victory and not settle_loot.is_empty():
			for loot_item in settle_loot:
				var item_id = loot_item.get("item_id", "")
				var amount = loot_item.get("amount", 0)
				# 确保数量是整数
				var amount_int = int(amount)
				if not item_id.is_empty() and amount_int > 0:
					var item_name = item_id
					if item_data_ref and item_data_ref.has_method("get_item_name"):
						item_name = item_data_ref.get_item_name(item_id)
					if log_manager:
						log_manager.add_battle_log("获得奖励: " + item_name + " x" + UI_UTILS.format_display_number(float(amount_int)))

		# 特殊区域通关日志
		if battle_victory and lianli_area_data:
			if lianli_area_data.is_single_boss_area(current_lianli_area_id):
				if log_manager:
					log_manager.add_battle_log("通关成功！")
			elif lianli_area_data.is_tower_area(current_lianli_area_id):
				# 无尽塔层数从 lianli_system 获取
				if lianli_system:
					var current_floor = lianli_system.get_current_tower_floor()
					if log_manager:
						log_manager.add_battle_log("挑战第" + str(current_floor) + "层成功")

		on_battle_ended(battle_victory, settle_loot if battle_victory else [], str(_current_enemy_data.get("name", "敌人")))
		if battle_victory and is_continuous_checked():
			_prepare_preview_for_next_battle()
			# 设置等待状态
			_is_waiting = true
			_wait_timer = 0.0
			_wait_interval = randf_range(BASE_WAIT_INTERVAL_MIN, BASE_WAIT_INTERVAL_MAX)
			_set_local_lianli_state(true, false, true, current_lianli_area_id)
			return
		if not battle_victory:
			_on_force_exit_lianli()
			return

	_on_force_exit_lianli()

func _prepare_preview_for_next_battle():
	if not lianli_system:
		return
	_current_enemy_data = {}
	if lianli_system.is_in_endless_tower() and lianli_area_data:
		var next_floor = max(1, int(lianli_system.tower_highest_floor) + 1)
		var max_floor = lianli_area_data.get_tower_max_floor()
		lianli_system.current_tower_floor = min(next_floor, max_floor)
	_update_battle_info()

func _simulate_next_battle():
	if not api or current_lianli_area_id.is_empty():
		_on_force_exit_lianli()
		return
	if not _begin_action_lock("lianli_simulate_continue"):
		return

	var sim_result = await api.lianli_simulate(current_lianli_area_id)
	if not sim_result.get("success", false):
		var err_msg = _get_lianli_result_message(sim_result, "连续历练启动失败")
		if not err_msg.is_empty():
			log_message.emit(err_msg)
		_on_force_exit_lianli()
		_end_action_lock("lianli_simulate_continue")
		return
	_start_timeline_from_simulation(sim_result, current_lianli_area_id)
	_end_action_lock("lianli_simulate_continue")

func _on_force_exit_lianli():
	_is_timeline_running = false
	_timeline_cursor = 0
	_timeline_elapsed = 0.0
	_battle_timeline = []
	_simulate_victory = false
	_simulate_loot = []
	_is_waiting = false
	_wait_timer = 0.0
	_finish_time_invalid_prompted = false
	_set_local_lianli_state(false, false, false, "")
	if game_ui and game_ui.has_method("clear_active_mode"):
		game_ui.clear_active_mode("lianli")
	show_lianli_select_panel()

# 显示历练场景面板（战斗中）
func show_lianli_scene_panel():
	if lianli_scene_panel:
		lianli_scene_panel.visible = true
	if lianli_select_panel:
		lianli_select_panel.visible = false

# 显示历练选择面板
func show_lianli_select_panel():
	if lianli_scene_panel:
		lianli_scene_panel.visible = false
	if lianli_select_panel:
		lianli_select_panel.visible = true
	# 不需要调用update_lianli_area_buttons_display，因为show_lianli_tab已经调用了它

# ==================== 历练区域功能 ====================

# 历练区域按钮点击
func on_lianli_area_pressed(area_id: String):
	current_lianli_area_id = area_id
	start_lianli_in_area(current_lianli_area_id)

# 开始历练
func start_lianli_in_area(area_id: String):
	if not api:
		log_message.emit("网络接口未初始化")
		return
	if not player:
		log_message.emit("错误: player 未初始化")
		return
	if _is_timeline_running or _is_waiting:
		return
	if not _begin_action_lock("lianli_simulate_start"):
		return

	if player.health <= 0:
		log_message.emit("气血值不足，无法进入历练区域！请先修炼恢复气血值。")
		_end_action_lock("lianli_simulate_start")
		return

	if game_ui and game_ui.has_method("can_enter_mode"):
		var enter_check = game_ui.can_enter_mode("lianli")
		if not enter_check.get("ok", false):
			log_message.emit(enter_check.get("message", "请先结束当前行为"))
			_end_action_lock("lianli_simulate_start")
			return

	# 开始历练前同步修炼增量
	var settle_ok = true
	if game_ui and game_ui.get("cultivation_module") and game_ui.get("cultivation_module").has_method("flush_pending_and_then"):
		settle_ok = await game_ui.get("cultivation_module").flush_pending_and_then(func(): pass)
	if not settle_ok:
		log_message.emit("历练前修炼同步失败，请稍后重试")
		_end_action_lock("lianli_simulate_start")
		return

	# 重置等待状态
	_is_waiting = false
	_wait_timer = 0.0

	var sim_result = await api.lianli_simulate(area_id)
	if not sim_result.get("success", false):
		var err_msg = _get_lianli_result_message(sim_result, "历练开始失败")
		if not err_msg.is_empty():
			log_message.emit(err_msg)
		_end_action_lock("lianli_simulate_start")
		return

	_start_timeline_from_simulation(sim_result, area_id)
	_end_action_lock("lianli_simulate_start")

# ==================== 无尽塔功能 ====================

func on_endless_tower_pressed():
	if not lianli_area_data:
		log_message.emit("历练区域数据未初始化")
		return
	var tower_id = lianli_area_data.get_tower_id()
	if tower_id.is_empty():
		log_message.emit("无尽塔区域配置缺失")
		return
	await start_lianli_in_area(tower_id)

func update_endless_tower_button_text(button: Button):
	if not button:
		return
	
	var tower_name = "无尽塔"
	var current_floor = 1
	var max_floor = 51
	
	if lianli_area_data:
		tower_name = lianli_area_data.get_tower_name()
		max_floor = lianli_area_data.get_tower_max_floor()
	
	if lianli_system:
		current_floor = min(lianli_system.tower_highest_floor + 1, max_floor)
	
	button.text = tower_name + " (第" + str(current_floor) + "层)"

# ==================== 战斗控制功能 ====================

# 继续战斗按钮点击
func on_continue_pressed():
	if _is_timeline_running or _finish_in_flight or _is_waiting:
		return
	
	# 设置等待状态
	_is_waiting = true
	_wait_timer = 0.0
	_wait_interval = randf_range(BASE_WAIT_INTERVAL_MIN, BASE_WAIT_INTERVAL_MAX)
	_set_local_lianli_state(true, false, true, current_lianli_area_id)

# 连续战斗复选框切换
func on_continuous_toggled(_enabled: bool):
	pass

# 检查是否勾选了连续战斗
func is_continuous_checked() -> bool:
	if continuous_checkbox and continuous_checkbox.visible:
		return continuous_checkbox.button_pressed
	return false

# 历练速度按钮点击
func on_lianli_speed_pressed():
	if not api:
		log_message.emit("网络接口未初始化")
		return
	if not _begin_action_lock("lianli_speed_switch"):
		return

	var options_ok = await _refresh_speed_options_from_server()
	if not options_ok:
		_action_lock.end("lianli_speed_switch", 0.0)
		return

	if available_lianli_speeds.size() <= 1:
		log_message.emit(LIANLI_SPEED_BLOCKED_MESSAGE)
		_action_lock.end("lianli_speed_switch", 0.0)
		return

	current_lianli_speed = _get_next_lianli_speed()
	_update_lianli_speed_button_text()
	_action_lock.end("lianli_speed_switch", 0.0)

func on_tab_entered():
	_update_lianli_speed_button_text()
	call_deferred("_refresh_speed_options_on_tab_enter")

# 退出历练按钮点击
func on_exit_lianli_pressed():
	if _finish_in_flight:
		return
	if _is_timeline_running:
		_finish_in_flight = true
		await _finish_current_battle(false)
		_finish_in_flight = false
	else:
		_on_force_exit_lianli()

# 启用继续战斗按钮
func enable_continue_button():
	if continue_button and continue_button.visible:
		continue_button.disabled = false

# ==================== UI更新功能 ====================

func _update_battle_info():
	if not lianli_system:
		return
	
	# 更新区域名称
	if area_name_label:
		if lianli_system.is_in_endless_tower():
			area_name_label.text = "无尽塔 - 第 " + str(lianli_system.get_current_tower_floor()) + " 层"
		elif current_lianli_area_id != "":
			area_name_label.text = lianli_area_data.get_area_name(current_lianli_area_id) if lianli_area_data else ""
		else:
			area_name_label.text = ""
	
	# 更新奖励信息
	if reward_info_label:
		if lianli_system.is_in_endless_tower():
			_update_tower_reward_info()
		else:
			reward_info_label.text = _get_area_reward_text()

func _refresh_speed_options_on_tab_enter():
	await _refresh_speed_options_from_server(true)

func _refresh_speed_options_from_server(silent: bool = false) -> bool:
	if not api:
		return false
	var result = await api.lianli_speed_options()
	if not result.get("success", false):
		if not silent:
			var err_msg = api.network_manager.get_api_error_text_for_ui(result, "历练倍速信息获取失败")
			if not err_msg.is_empty():
				log_message.emit(err_msg)
		return false
	_apply_available_lianli_speeds(result.get("available_speeds", [DEFAULT_LIANLI_SPEED]))
	return true

func _apply_available_lianli_speeds(raw_speeds: Array):
	var sanitized: Array = []
	for candidate in LIANLI_SPEEDS:
		for raw_speed in raw_speeds:
			if is_equal_approx(float(raw_speed), float(candidate)):
				sanitized.append(float(candidate))
				break
	if sanitized.is_empty():
		sanitized = [DEFAULT_LIANLI_SPEED]
	available_lianli_speeds = sanitized
	if not _has_lianli_speed(current_lianli_speed):
		current_lianli_speed = DEFAULT_LIANLI_SPEED if _has_lianli_speed(DEFAULT_LIANLI_SPEED) else float(available_lianli_speeds[0])
	_update_lianli_speed_button_text()

func _has_lianli_speed(target_speed: float) -> bool:
	for speed in available_lianli_speeds:
		if is_equal_approx(float(speed), target_speed):
			return true
	return false

func _get_next_lianli_speed() -> float:
	if available_lianli_speeds.is_empty():
		return DEFAULT_LIANLI_SPEED
	for i in range(available_lianli_speeds.size()):
		if is_equal_approx(float(available_lianli_speeds[i]), current_lianli_speed):
			return float(available_lianli_speeds[(i + 1) % available_lianli_speeds.size()])
	return float(available_lianli_speeds[0])

func _update_lianli_speed_button_text():
	if not lianli_speed_button:
		return
	lianli_speed_button.text = "历练速度: " + _format_speed_text(current_lianli_speed) + "x"

func _format_speed_text(speed: float) -> String:
	if is_equal_approx(speed, floor(speed)):
		return str(int(speed))
	return str(snapped(speed, 0.1))

func on_player_data_refreshed(lianli_data: Dictionary):
	if lianli_system and lianli_system.has_method("apply_save_data"):
		lianli_system.apply_save_data(lianli_data)
	if not _is_timeline_running:
		_update_battle_info()

func _update_tower_reward_info():
	if not lianli_area_data:
		return
	
	var current_floor = lianli_system.get_current_tower_floor()
	if lianli_area_data.is_tower_reward_floor(current_floor):
		var current_reward_desc = lianli_area_data.get_tower_reward_description(current_floor)
		reward_info_label.text = "距离奖励层还需挑战 0 层（第" + str(current_floor) + "层）\n奖励：" + current_reward_desc
		return

	var next_reward_floor = lianli_area_data.get_tower_next_reward_floor(current_floor)
	if next_reward_floor > 0:
		var floors_to_reward = next_reward_floor - current_floor
		var reward_desc = lianli_area_data.get_tower_reward_description(next_reward_floor)
		reward_info_label.text = "距离奖励层还需挑战 " + str(floors_to_reward) + " 层（第" + str(next_reward_floor) + "层）\n奖励：" + reward_desc
	else:
		reward_info_label.text = "已达到最高奖励层"

# 获取区域奖励文本
func _get_area_reward_text() -> String:
	if not lianli_area_data or current_lianli_area_id == "":
		return ""
	
	# 检查是否是特殊区域
	if lianli_area_data.is_special_area(current_lianli_area_id):
		return _get_special_area_reward_text()
	else:
		return _get_normal_area_reward_text()

# 特殊区域奖励文本
func _get_special_area_reward_text() -> String:
	var special_drops = lianli_area_data.get_special_drops(current_lianli_area_id)
	var lines: Array[String] = []

	if not special_drops.is_empty():
		lines.append("通关奖励：" + _format_special_drop_list(special_drops))

	var enemy_drops := _get_current_drop_table()
	if not enemy_drops.is_empty():
		lines.append("战斗概率掉落：" + _format_drop_table(enemy_drops))

	return "\n".join(lines)

# 普通区域奖励文本
func _get_normal_area_reward_text() -> String:
	var drops := _get_current_drop_table()
	if drops.is_empty():
		return ""
	return "战斗概率掉落：" + _format_drop_table(drops)

func _format_special_drop_list(special_drops: Dictionary) -> String:
	var drops_text: Array[String] = []
	for item_id in special_drops.keys():
		var amount = int(special_drops[item_id])
		if amount <= 0:
			continue
		drops_text.append(_get_item_name(item_id) + " x" + UI_UTILS.format_display_number(float(amount)))
	return "、".join(drops_text)

func _format_drop_table(drops: Dictionary) -> String:
	var parts: Array[String] = []
	for item_id in drops.keys():
		var drop_info = drops[item_id]
		if not (drop_info is Dictionary):
			continue
		var min_amount = int(drop_info.get("min", 0))
		var max_amount = int(drop_info.get("max", 0))
		var chance = float(drop_info.get("chance", 1.0))
		var amount_text = UI_UTILS.format_display_number(float(min_amount)) if min_amount == max_amount else (UI_UTILS.format_display_number(float(min_amount)) + "-" + UI_UTILS.format_display_number(float(max_amount)))
		var chance_text = ""
		if chance < 0.9999:
			chance_text = "（" + str(int(round(chance * 100.0))) + "%）"
		parts.append(_get_item_name(item_id) + " x" + amount_text + chance_text)
	return "、".join(parts)

func _get_current_drop_table() -> Dictionary:
	if _is_timeline_running and _current_enemy_data.has("drops"):
		var current_drops = _current_enemy_data.get("drops", {})
		if current_drops is Dictionary and not current_drops.is_empty():
			return current_drops
	if _is_timeline_running and lianli_system:
		var system_drops = lianli_system.get_current_enemy_drops()
		if system_drops is Dictionary and not system_drops.is_empty():
			return system_drops
	return _get_area_fallback_drops()

func _get_area_fallback_drops() -> Dictionary:
	if not lianli_area_data or current_lianli_area_id.is_empty():
		return {}
	var area_data = lianli_area_data.get_area_data(current_lianli_area_id)
	var enemy_templates = area_data.get("enemies_template", [])
	for group in enemy_templates:
		if not (group is Dictionary):
			continue
		var group_drops = group.get("drops", {})
		if group_drops is Dictionary and not group_drops.is_empty():
			return group_drops
	return {}

func _get_item_name(item_id: String) -> String:
	if item_id == "spirit_stone":
		return "灵石"
	if item_data_ref and item_data_ref.has_method("get_item_name"):
		return str(item_data_ref.get_item_name(item_id))
	return item_id

func _update_button_container():
	if continuous_checkbox:
		continuous_checkbox.visible = true
	if continue_button:
		continue_button.visible = true
		continue_button.disabled = _is_timeline_running

# 设置连续战斗默认值
func _set_continuous_default():
	if not continuous_checkbox:
		return
	if not lianli_area_data:
		continuous_checkbox.button_pressed = false
		return
	var area_id = current_lianli_area_id if not current_lianli_area_id.is_empty() else "area_1"
	continuous_checkbox.button_pressed = lianli_area_data.get_default_continuous(area_id)

# 战斗结束
func on_battle_ended(victory: bool, loot: Array, enemy_name: String):
	if victory:
		if lianli_status_label:
			lianli_status_label.text = "战斗胜利"
			lianli_status_label.modulate = Color.GREEN
		if is_continuous_checked():
			if continue_button:
				continue_button.disabled = true
		else:
			enable_continue_button()
	else:
		if lianli_status_label:
			lianli_status_label.text = "战斗失败..."
			lianli_status_label.modulate = Color.RED

	battle_ended.emit(victory, loot, enemy_name)

# 等待中
func on_lianli_waiting(time_remaining: float):
	if lianli_status_label:
		lianli_status_label.text = "等待下一场历练... (" + str(int(ceil(time_remaining))) + "秒)"
		lianli_status_label.modulate = Color.GRAY
	
	lianli_waiting.emit(time_remaining)

# 清理
func cleanup():
	pass
