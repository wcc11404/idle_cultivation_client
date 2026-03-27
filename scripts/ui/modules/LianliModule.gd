class_name LianliModule extends Node

## 历练模块 - 管理历练和无尽塔功能
## 包括战斗UI更新、战斗控制、战斗日志等

# 信号
signal log_message(message: String)
signal battle_log_message(message: String)
signal lianli_started(area_id: String)
signal battle_started(enemy_name: String, is_elite: bool, enemy_max_health: float, enemy_level: int, player_max_health: float)
signal lianli_round(damage_to_enemy: float, damage_to_player: float, enemy_health: float, player_health: float)
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
var endless_tower_data: Node = null
var item_data_ref: Node = null
var inventory: Node = null
var chuna_module: Node = null
var log_manager: Node = null
var alchemy_module: Node = null
var api: Node = null
var save_manager: Node = null

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

func _ready():
	pass

func initialize(ui: Node, player_node: Node, lianli_sys: Node, 
					area_data: Node = null, tower_data: Node = null, 
					item_data: Node = null, inv: Node = null, 
					chuna: Node = null, log_mgr: Node = null, alchemy_mod: Node = null, 
					game_api: Node = null):
	game_ui = ui
	player = player_node
	lianli_system = lianli_sys
	lianli_area_data = area_data
	endless_tower_data = tower_data
	item_data_ref = item_data
	inventory = inv
	chuna_module = chuna
	log_manager = log_mgr
	alchemy_module = alchemy_mod
	api = game_api
	
	# 获取save_manager
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		save_manager = game_manager.get_save_manager()

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
	if not lianli_system:
		log_message.emit("错误: lianli_system 未初始化")
		return
	if not player:
		log_message.emit("错误: player 未初始化")
		return
	
	# 检测气血值
	if player.health <= 0:
		log_message.emit("气血值不足，无法进入历练区域！请先修炼恢复气血值。")
		return
	
	# 检查特殊区域每日次数限制（本地检查，次数扣减在通关后通过API调用）
	if lianli_area_data and lianli_area_data.is_special_area(area_id):
		# 无API实例时，使用本地检查
		if not api:
			var remaining = lianli_system.get_daily_dungeon_count(area_id)
			if remaining <= 0:
				log_message.emit("今日进入次数已用完，请明天凌晨4点后再来")
				return
	
	# 如果正在修炼，先停止修炼
	if player.get_is_cultivating():
		_stop_cultivation()
	
	# 如果正在炼丹，先停止炼丹
	if alchemy_module and alchemy_module.is_crafting_active():
		alchemy_module.stop_crafting()
		log_message.emit("已停止炼丹")
	
	# 如果正在无尽塔中，先退出
	if lianli_system.is_in_endless_tower():
		lianli_system.exit_tower()
	
	lianli_system.set_current_area(area_id)
	var result = lianli_system.start_lianli_in_area(area_id)
	if result:
		show_lianli_scene_panel()
		_set_continuous_default()
	else:
		log_message.emit("历练开始失败")

# 停止修炼（辅助函数）
# 注意：日志由CultivationSystem.stop_cultivation()输出
func _stop_cultivation():
	if not player:
		return
	
	if player.get_is_cultivating():
		var game_manager = get_node_or_null("/root/GameManager")
		var cult_system = game_manager.get_cultivation_system() if game_manager else null
		if cult_system:
			cult_system.stop_cultivation()

# ==================== 无尽塔功能 ====================

# 无尽塔按钮点击
func on_endless_tower_pressed():
	if not lianli_system:
		log_message.emit("错误: lianli_system 未初始化")
		return
	if not player:
		log_message.emit("错误: player 未初始化")
		return
	
	# 检测气血值
	if player.health <= 0:
		log_message.emit("气血值不足，无法进入无尽塔！请先修炼恢复气血值。")
		return
	
	# 如果正在修炼，先停止修炼
	if player.get_is_cultivating():
		_stop_cultivation()
	
	# 开始无尽塔
	var result = lianli_system.start_endless_tower()
	if result:
		show_lianli_scene_panel()
		_update_battle_info()
		_update_button_container()
		_set_continuous_default()
	else:
		log_message.emit("无尽塔挑战开始失败")

# 更新无尽塔按钮文本
func update_endless_tower_button_text(button: Button):
	if not button:
		return
	
	var tower_name = "无尽塔"
	var current_floor = 1
	var max_floor = 51
	
	if endless_tower_data:
		tower_name = endless_tower_data.get_tower_name()
		max_floor = endless_tower_data.get_max_floor()
	
	if lianli_system:
		current_floor = min(lianli_system.tower_highest_floor + 1, max_floor)
	
	button.text = tower_name + " (第" + str(current_floor) + "层)"

# ==================== 战斗控制功能 ====================

# 继续战斗按钮点击
func on_continue_pressed():
	if not lianli_system:
		return
	
	# 如果正在战斗中或准备中，不响应
	if lianli_system.is_in_battle:
		return
	
	# 如果正在等待中，不响应（等待会自动开始下一场）
	if lianli_system.is_waiting:
		return
	
	# 开始等待下一场战斗
	if lianli_system.start_wait_for_next_battle():
		if continue_button:
			continue_button.disabled = true
		_update_battle_info()

# 连续战斗复选框切换
func on_continuous_toggled(enabled: bool):
	if lianli_system:
		lianli_system.set_continuous_lianli(enabled)

# 检查是否勾选了连续战斗
func is_continuous_checked() -> bool:
	if continuous_checkbox and continuous_checkbox.visible:
		return continuous_checkbox.button_pressed
	return false

# 历练速度按钮点击
func on_lianli_speed_pressed():
	current_lianli_speed_index = (current_lianli_speed_index + 1) % LIANLI_SPEEDS.size()
	var new_speed = LIANLI_SPEEDS[current_lianli_speed_index]
	if lianli_system:
		lianli_system.set_lianli_speed(new_speed)
	if lianli_speed_button:
		lianli_speed_button.text = "历练速度: " + str(new_speed) + "x"

# 退出历练按钮点击
func on_exit_lianli_pressed():
	if lianli_system:
		lianli_system.end_lianli()
	show_lianli_select_panel()

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

# 更新无尽塔奖励信息
func _update_tower_reward_info():
	if not endless_tower_data:
		return
	
	var current_floor = lianli_system.get_current_tower_floor()
	var next_reward_floor = endless_tower_data.get_next_reward_floor(current_floor)
	if next_reward_floor > 0:
		var floors_to_reward = next_reward_floor - current_floor
		var reward_desc = endless_tower_data.get_reward_description(next_reward_floor)
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
	if not lianli_system:
		return
	
	var is_tower = lianli_system.is_in_endless_tower()
	
	# 连续战斗复选框
	if continuous_checkbox:
		continuous_checkbox.visible = true
	
	# 继续战斗按钮
	if continue_button:
		continue_button.visible = true
		continue_button.disabled = true

# 设置连续战斗默认值
func _set_continuous_default():
	if not lianli_system or not lianli_area_data:
		return
	
	if continuous_checkbox:
		var is_tower = lianli_system.is_in_endless_tower()
		if is_tower:
			continuous_checkbox.button_pressed = lianli_area_data.get_default_continuous("endless_tower")
		else:
			var area_id = lianli_system.current_area_id
			continuous_checkbox.button_pressed = lianli_area_data.get_default_continuous(area_id)
		# 同步到LianliSystem
		lianli_system.set_continuous_lianli(continuous_checkbox.button_pressed)

# ==================== 信号处理函数 ====================

# 历练开始
func on_lianli_started(area_id: String):
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

# 历练回合更新
func on_lianli_round(damage_to_enemy: float, damage_to_player: float, enemy_health: float, player_health: float):
	if lianli_status_label and lianli_status_label.text == "准备历练...":
		lianli_status_label.text = "历练中..."
	
	# 更新敌人血条
	if enemy_health_bar:
		enemy_health_bar.value = max(0.0, enemy_health)
	if enemy_health_value:
		enemy_health_value.text = AttributeCalculator.format_integer(max(0.0, enemy_health)) + "/" + AttributeCalculator.format_integer(enemy_health_bar.max_value)
	
	# 更新玩家血条
	if player:
		var combat_max_health = player.get_combat_max_health()
		if player_health_bar_lianli:
			player_health_bar_lianli.max_value = combat_max_health
			player_health_bar_lianli.value = max(0.0, player_health)
		if player_health_value_lianli:
			player_health_value_lianli.text = AttributeCalculator.format_integer(max(0.0, player_health)) + "/" + AttributeCalculator.format_integer(combat_max_health)
	
	lianli_round.emit(damage_to_enemy, damage_to_player, enemy_health, player_health)

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
		# 检查是否勾选了连续战斗
		if is_continuous_checked():
			# 勾选了连续战斗，自动开始等待下一场
			if lianli_system and lianli_system.start_wait_for_next_battle():
				pass  # 连续战斗开始，按钮保持禁用
		else:
			# 没有勾选连续战斗，启用继续战斗按钮
			enable_continue_button()
		
		# 检查是否是特殊区域（需要扣减次数）
		if lianli_area_data and lianli_area_data.is_special_area(current_lianli_area_id):
			# 使用API扣减次数
			if api:
				# 使用call_deferred来处理异步操作
				call_deferred("_finish_dungeon_async", current_lianli_area_id)
			else:
				# 无API实例，使用本地扣减
				lianli_system.use_daily_dungeon_count(current_lianli_area_id)
		
		# 破境草洞穴或无尽塔战斗胜利后保存
		_save_after_battle_victory()
	else:
		# 战斗失败
		if lianli_status_label:
			lianli_status_label.text = "战斗失败..."
			lianli_status_label.modulate = Color.RED

	battle_ended.emit(victory, loot, enemy_name)

func _save_after_battle_victory():
	var should_save = false
	
	if lianli_system and lianli_system.is_in_endless_tower():
		should_save = true
	elif lianli_area_data and current_lianli_area_id == "foundation_herb_cave":
		should_save = true
	
	if should_save:
		if not save_manager:
			var game_manager = get_node_or_null("/root/GameManager")
			if game_manager:
				save_manager = game_manager.get_save_manager()
		
		if save_manager and save_manager.has_method("save_partial"):
			await save_manager.save_partial(["inventory", "lianli_system", "player"])

# 异步处理副本完成
func _finish_dungeon_async(dungeon_id: String):
	# 使用Timer来模拟异步操作
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 0.1
	timer.one_shot = true
	timer.start()
	await timer.timeout
	timer.queue_free()
	var finish_result = await api.finish_dungeon(dungeon_id)
	if finish_result.success:
		# 扣减次数成功
		var remaining_count = int(finish_result.get("remaining_count", 0))
		log_message.emit(finish_result.get("message", "副本完成成功") + "，剩余次数: " + str(remaining_count))
		# 更新按钮显示
		if game_ui:
			game_ui.update_lianli_area_buttons_display()
	else:
		# 扣减次数失败
		log_message.emit(finish_result.get("message", "副本完成失败"))

# 战斗行动执行
func on_battle_action_executed(is_player: bool, damage: float, is_spell: bool, spell_name: String):
	pass  # 可用于显示战斗动画等

# 历练胜利（兼容旧信号）
func on_lianli_win(loot: Array, enemy_name: String):
	var area_name = ""
	if lianli_area_data and current_lianli_area_id:
		area_name = lianli_area_data.get_area_name(current_lianli_area_id)
	
	if area_name.is_empty():
		area_name = "历练区域"
	
	# 只有特殊历练场才显示通关提示
	var is_common_area = (current_lianli_area_id == "qi_refining_outer" or 
						  current_lianli_area_id == "qi_refining_inner" or 
						  current_lianli_area_id == "foundation_outer" or 
						  current_lianli_area_id == "foundation_inner")
	
	if not is_common_area:
		if lianli_status_label:
			lianli_status_label.text = "通关" + area_name + "！"
			lianli_status_label.modulate = Color.GREEN
		if log_manager:
			log_manager.add_battle_log("通关" + area_name + "！")

# 历练奖励
func on_lianli_reward(item_id: String, amount: int, source: String):
	if inventory:
		inventory.add_item(item_id, amount)
		if chuna_module:
			chuna_module.update_inventory_ui()

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
