class_name LianliModule extends Node

## 历练模块 - 管理历练和无尽塔功能
## 包括战斗UI更新、战斗控制、战斗日志等
const ActionLockManager = preload("res://scripts/managers/ActionLockManager.gd")

# 信号
signal log_message(message: String)
signal battle_log_message(message: String)
signal lianli_started(area_id: String)
signal battle_started(enemy_name: String, is_elite: bool, enemy_max_health: float, enemy_level: int, player_max_health: float)
signal battle_updated(player_atb: float, enemy_atb: float, player_health: float, enemy_health: float, player_max_health: float, enemy_max_health: float)
signal lianli_ended(victory: bool)
signal battle_ended(victory: bool, loot: Array, enemy_name: String)
signal lianli_waiting(time_remaining: float)
signal lianli_action_log(message: String)
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
var current_lianli_speed_index: int = 0

# 历练速度选项
const LIANLI_SPEEDS = [1.0, 1.5, 2.0]

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
var _enemy_hp_tween: Tween = null
var _player_hp_tween: Tween = null

const ACTION_COOLDOWN_SECONDS := 0.1
var _action_lock := ActionLockManager.new()

func _begin_action_lock(action_key: String) -> bool:
	return _action_lock.try_begin(action_key)

func _end_action_lock(action_key: String):
	_action_lock.end(action_key, ACTION_COOLDOWN_SECONDS)

func _ready():
	set_process(true)

func initialize(ui: Node, player_node: Node, lianli_sys: Node, 
					area_data: Node = null, 
					item_data: Node = null, inv: Node = null, 
					chuna: Node = null, log_mgr: Node = null, alchemy_mod: Node = null, 
					game_api: Node = null):
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
	
	_update_battle_info()
	
func _process(delta: float):
	if not _is_timeline_running or _finish_in_flight:
		return

	var speed = LIANLI_SPEEDS[current_lianli_speed_index]
	_timeline_elapsed += delta * speed

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

func _apply_timeline_event(event: Dictionary, duration: float = 0.12):
	var event_type = str(event.get("type", ""))
	var info = event.get("info", {})
	if not (info is Dictionary):
		return

	if event_type == "player_action":
		var enemy_health_after = float(info.get("target_health_after", enemy_health_bar.value if enemy_health_bar else 0.0))
		_animate_health_bar(enemy_health_bar, enemy_health_value, max(0.0, enemy_health_after), duration, true)

		var spell_id = str(info.get("spell_id", "norm_attack"))
		if spell_id == "norm_attack":
			log_message.emit("你对敌人造成了" + AttributeCalculator.format_integer(float(info.get("damage", 0.0))) + "点伤害")
		else:
			log_message.emit("你施放术法，造成了" + AttributeCalculator.format_integer(float(info.get("damage", 0.0))) + "点伤害")
	else:
		var player_health_after = float(info.get("target_health_after", _simulated_player_health_after))
		_simulated_player_health_after = player_health_after
		_animate_health_bar(player_health_bar_lianli, player_health_value_lianli, max(0.0, player_health_after), duration, false)
		log_message.emit("敌人对你造成了" + AttributeCalculator.format_integer(float(info.get("damage", 0.0))) + "点伤害")

func _animate_health_bar(bar: ProgressBar, value_label: Label, target_health: float, duration: float, is_enemy: bool):
	if not bar:
		return

	var clamped_target = clamp(target_health, 0.0, bar.max_value)
	if value_label:
		value_label.text = AttributeCalculator.format_integer(clamped_target) + "/" + AttributeCalculator.format_integer(bar.max_value)

	if is_enemy:
		if _enemy_hp_tween:
			_enemy_hp_tween.kill()
		_enemy_hp_tween = create_tween()
		_enemy_hp_tween.tween_property(bar, "value", clamped_target, max(0.03, duration))
	else:
		if _player_hp_tween:
			_player_hp_tween.kill()
		_player_hp_tween = create_tween()
		_player_hp_tween.tween_property(bar, "value", clamped_target, max(0.03, duration))

func _start_timeline_from_simulation(sim_result: Dictionary, area_id: String):
	_battle_timeline = sim_result.get("battle_timeline", [])
	_timeline_cursor = 0
	_timeline_elapsed = 0.0
	_timeline_total = float(sim_result.get("total_time", 0.0))
	_simulate_victory = bool(sim_result.get("victory", false))
	_simulate_loot = sim_result.get("loot", [])
	_current_enemy_data = sim_result.get("enemy_data", {})
	_simulated_player_health_after = float(sim_result.get("player_health_after", player.health if player else 0.0))
	current_lianli_area_id = area_id

	if game_ui and game_ui.has_method("set_active_mode"):
		game_ui.set_active_mode("lianli")
	show_lianli_scene_panel()

	if enemy_name_label:
		enemy_name_label.text = str(_current_enemy_data.get("name", "敌人")) + " Lv." + str(_current_enemy_data.get("level", 1))
	if enemy_health_bar:
		var enemy_max_hp = float(_current_enemy_data.get("health", 1.0))
		enemy_health_bar.max_value = enemy_max_hp
		enemy_health_bar.value = enemy_max_hp
	if enemy_health_value and enemy_health_bar:
		enemy_health_value.text = AttributeCalculator.format_integer(enemy_health_bar.value) + "/" + AttributeCalculator.format_integer(enemy_health_bar.max_value)

	if player and player_health_bar_lianli:
		var player_max_hp = player.get_combat_max_health()
		player_health_bar_lianli.max_value = player_max_hp
		player_health_bar_lianli.value = player.health
	if player_health_value_lianli and player_health_bar_lianli:
		player_health_value_lianli.text = AttributeCalculator.format_integer(player_health_bar_lianli.value) + "/" + AttributeCalculator.format_integer(player_health_bar_lianli.max_value)

	if lianli_status_label:
		lianli_status_label.text = "战斗中..."
		lianli_status_label.modulate = Color.YELLOW

	_set_continuous_default()
	_update_button_container()
	_is_timeline_running = true

func _finish_current_battle(full_settle: bool):
	if not api:
		log_message.emit("网络接口未初始化")
		return

	var settle_index = -1
	if not full_settle:
		settle_index = max(0, _timeline_cursor - 1)
	var finish_result = await api.lianli_finish(LIANLI_SPEEDS[current_lianli_speed_index], settle_index)
	if not finish_result.get("success", false):
		var err_msg = api.network_manager.get_api_error_text_for_ui(finish_result, "历练结算失败")
		if not err_msg.is_empty():
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

		on_battle_ended(battle_victory, settle_loot if battle_victory else [], str(_current_enemy_data.get("name", "敌人")))
		if battle_victory and is_continuous_checked():
			await _simulate_next_battle()
			return
		if not battle_victory:
			_on_force_exit_lianli()
			return

	_on_force_exit_lianli()

func _simulate_next_battle():
	if not api or current_lianli_area_id.is_empty():
		_on_force_exit_lianli()
		return
	if not _begin_action_lock("lianli_simulate_continue"):
		return

	var sim_result = await api.lianli_simulate(current_lianli_area_id)
	if not sim_result.get("success", false):
		var err_msg = api.network_manager.get_api_error_text_for_ui(sim_result, "连续历练启动失败")
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
	if game_ui and game_ui.has_method("clear_active_mode"):
		game_ui.clear_active_mode("lianli")
	show_lianli_select_panel()

# 显示历练面板
func show_lianli_panel():
	if lianli_panel:
		lianli_panel.visible = true

func hide_lianli_panel():
	if lianli_panel:
		lianli_panel.visible = false

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
	if _is_timeline_running:
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

	var sim_result = await api.lianli_simulate(area_id)
	if not sim_result.get("success", false):
		var err_msg = api.network_manager.get_api_error_text_for_ui(sim_result, "历练开始失败")
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
	if _is_timeline_running or _finish_in_flight:
		return
	await _simulate_next_battle()

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
	current_lianli_speed_index = (current_lianli_speed_index + 1) % LIANLI_SPEEDS.size()
	var new_speed = LIANLI_SPEEDS[current_lianli_speed_index]
	if lianli_speed_button:
		lianli_speed_button.text = "历练速度: " + str(new_speed) + "x"

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

# 更新战斗信息UI
func update_battle_info():
	_update_battle_info()

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

func on_player_data_refreshed(lianli_data: Dictionary):
	if lianli_system and lianli_system.has_method("apply_save_data"):
		lianli_system.apply_save_data(lianli_data)
	if not _is_timeline_running:
		_update_battle_info()

func _update_tower_reward_info():
	if not lianli_area_data:
		return
	
	var current_floor = lianli_system.get_current_tower_floor()
	var next_reward_floor = lianli_area_data.get_tower_next_reward_floor(current_floor)
	if next_reward_floor > 0:
		var floors_to_reward = next_reward_floor - current_floor
		var reward_desc = lianli_area_data.get_tower_reward_description(next_reward_floor)
		reward_info_label.text = "再挑战 " + str(floors_to_reward) + " 层获得 " + reward_desc
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
	if special_drops.is_empty():
		return ""
	
	var drops_text = []
	for item_id in special_drops.keys():
		var amount = int(special_drops[item_id])
		if item_id == "spirit_stone":
			drops_text.append(str(amount) + " 灵石")
		else:
			var item_name = item_id
			if item_data_ref:
				item_name = item_data_ref.get_item_name(item_id)
			drops_text.append(str(amount) + "x " + item_name)
	return "通关奖励: " + ", ".join(drops_text) if drops_text.size() > 0 else ""

# 普通区域奖励文本
func _get_normal_area_reward_text() -> String:
	if not lianli_system:
		return ""
	
	var drops = lianli_system.get_current_enemy_drops()
	if drops.has("spirit_stone"):
		var stone_drop = drops["spirit_stone"]
		var min_amount = int(stone_drop.get("min", 0))
		var max_amount = int(stone_drop.get("max", 0))
		return "掉落: " + str(min_amount) + "-" + str(max_amount) + " 灵石"
	return ""

# 更新按钮容器显示
func update_button_container():
	_update_button_container()

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
	var area_id = current_lianli_area_id if not current_lianli_area_id.is_empty() else "qi_refining_outer"
	continuous_checkbox.button_pressed = lianli_area_data.get_default_continuous(area_id)

# ==================== 信号处理函数 ====================

# 历练开始
func on_lianli_started(area_id: String):
	if game_ui and game_ui.has_method("set_active_mode"):
		game_ui.set_active_mode("lianli")
	var area_name = ""
	if lianli_area_data:
		area_name = lianli_area_data.get_area_name(area_id)
	if area_name.is_empty():
		area_name = "历练区域"
	
	if lianli_status_label:
		lianli_status_label.text = "进入" + area_name + "..."
		lianli_status_label.modulate = Color.YELLOW
	
	lianli_started.emit(area_id)

# 战斗开始
func on_battle_started(enemy_name: String, is_elite: bool, enemy_max_health: float, enemy_level: int, player_max_health: float = 0):
	var elite_tag = " [精英]" if is_elite else ""
	
	if enemy_name_label:
		enemy_name_label.text = enemy_name + " Lv." + str(enemy_level) + elite_tag
		enemy_name_label.modulate = Color.RED if is_elite else Color.WHITE
	
	if lianli_status_label:
		lianli_status_label.text = "战斗中..."
		lianli_status_label.modulate = Color.YELLOW
	
	# 初始化敌人血条
	if enemy_health_bar:
		enemy_health_bar.max_value = enemy_max_health
		enemy_health_bar.value = enemy_max_health
	if enemy_health_value:
		enemy_health_value.text = AttributeCalculator.format_integer(enemy_max_health) + "/" + AttributeCalculator.format_integer(enemy_max_health)
	
	# 初始化玩家血条
	if player:
		var combat_max_health = player_max_health if player_max_health > 0 else player.get_combat_max_health()
		if player_health_bar_lianli:
			player_health_bar_lianli.max_value = combat_max_health
			player_health_bar_lianli.value = player.health
		if player_health_value_lianli:
			player_health_value_lianli.text = AttributeCalculator.format_integer(player.health) + "/" + AttributeCalculator.format_integer(combat_max_health)
	
	# 更新UI
	_update_battle_info()
	_update_button_container()
	
	# 日志
	var log_msg = "遭遇敌人: " + enemy_name + elite_tag
	if log_manager:
		log_manager.add_battle_log(log_msg)
	else:
		log_message.emit(log_msg)
	
	battle_started.emit(enemy_name, is_elite, enemy_max_health, enemy_level, player_max_health)

# 战斗更新（ATB）
func on_battle_updated(player_atb: float, enemy_atb: float, player_health: float, enemy_health: float, player_max_health: float, enemy_max_health: float):
	# 更新敌人血条
	if enemy_health_bar:
		enemy_health_bar.max_value = enemy_max_health
		enemy_health_bar.value = max(0.0, enemy_health)
	if enemy_health_value:
		enemy_health_value.text = AttributeCalculator.format_integer(max(0.0, enemy_health)) + "/" + AttributeCalculator.format_integer(enemy_max_health)
	
	# 更新玩家血条
	if player_health_bar_lianli:
		player_health_bar_lianli.max_value = player_max_health
		player_health_bar_lianli.value = max(0.0, player_health)
	if player_health_value_lianli:
		player_health_value_lianli.text = AttributeCalculator.format_integer(max(0.0, player_health)) + "/" + AttributeCalculator.format_integer(player_max_health)
	
	battle_updated.emit(player_atb, enemy_atb, player_health, enemy_health, player_max_health, enemy_max_health)

# 历练结束
func on_lianli_ended(victory: bool):
	if lianli_status_label:
		if victory:
			lianli_status_label.text = "历练完成"
			lianli_status_label.modulate = Color.GREEN
		else:
			lianli_status_label.text = "历练结束"
			lianli_status_label.modulate = Color.YELLOW
	
	lianli_ended.emit(victory)

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

# 历练奖励
func on_lianli_reward(item_id: String, amount: int, source: String):
	var item_name = item_id
	if item_data_ref and item_data_ref.has_method("get_item_name"):
		item_name = item_data_ref.get_item_name(item_id)
	var source_tag = source if not source.is_empty() else "lianli"

	# 在线模式由服务端结算并在后续刷新中落地，避免本地写背包
	if api:
		log_message.emit("获得奖励(待结算)[" + source_tag + "]: " + item_name + " x" + str(amount))
		return

	# 离线容错：保留本地发奖路径
	if inventory:
		inventory.add_item(item_id, amount)
		if chuna_module:
			chuna_module.update_inventory_ui()
		if game_ui and game_ui.has_method("update_ui"):
			game_ui.update_ui()
		log_message.emit("获得奖励[" + source_tag + "]: " + item_name + " x" + str(amount))

# 等待中
func on_lianli_waiting(time_remaining: float):
	if lianli_status_label:
		lianli_status_label.text = "等待下一场历练... (" + str(int(ceil(time_remaining))) + "秒)"
		lianli_status_label.modulate = Color.GRAY
	
	lianli_waiting.emit(time_remaining)

# 战斗日志（根据内容判断类型）
func on_lianli_action_log(message: String):
	# 系统消息关键词
	var system_keywords = ["气血不足", "无法进入"]
	var is_system = false
	for keyword in system_keywords:
		if keyword in message:
			is_system = true
			break
	
	if log_manager:
		if is_system:
			log_manager.add_system_log(message)
		else:
			log_manager.add_battle_log(message)
	else:
		log_message.emit(message)
	
	lianli_action_log.emit(message)


# 清理
func cleanup():
	pass
