class_name CultivationModule extends Node

## 修炼突破模块 - 管理修炼和突破功能
## 对应内视页面的修炼子面板

# 信号
signal cultivation_started
signal cultivation_stopped
signal breakthrough_succeeded(result: Dictionary)
signal breakthrough_failed(result: Dictionary)
signal log_message(message: String)

# 引用
var game_ui: Node = null
var player: Node = null
var cultivation_system: Node = null
var lianli_system: Node = null
var item_data: Node = null

# UI节点引用（由GameUI设置）
var cultivation_panel: Control = null
var cultivate_button: Button = null
var breakthrough_button: Button = null

# 气血/灵气条
var health_bar: ProgressBar = null
var health_value: Label = null
var spirit_bar: ProgressBar = null
var spirit_value: Label = null

# 属性标签
var attack_label: Label = null
var defense_label: Label = null
var speed_label: Label = null
var spirit_gain_label: Label = null

# 修炼状态标签
var status_label: Label = null

# 修炼小人素材
var cultivation_figure: TextureRect = null
var cultivation_figure_particles: TextureRect = null

# 状态
var _is_initialized: bool = false

func _ready():
	pass

func initialize(ui: Node, player_node: Node, cult_sys: Node, lianli_sys: Node = null, item_data_ref: Node = null):
	game_ui = ui
	player = player_node
	cultivation_system = cult_sys
	lianli_system = lianli_sys
	item_data = item_data_ref
	_is_initialized = true
	
	# 连接修炼系统日志信号
	if cultivation_system:
		cultivation_system.log_message.connect(_on_module_log)

func _on_module_log(message: String):
	log_message.emit(message)

# 显示修炼面板
func show_panel():
	if cultivation_panel:
		cultivation_panel.visible = true
	_update_cultivate_button_state()

# 隐藏修炼面板
func hide_panel():
	if cultivation_panel:
		cultivation_panel.visible = false

# 更新修炼按钮状态
func update_cultivate_button_state():
	_update_cultivate_button_state()

func _update_cultivate_button_state():
	if not cultivate_button or not player:
		return
	
	if player.get_is_cultivating():
		cultivate_button.text = "停止修炼"
	else:
		cultivate_button.text = "修炼"

# 修炼按钮按下
func on_cultivate_button_pressed():
	if not player or not cultivation_system:
		return
	
	if player.get_is_cultivating():
		# 停止修炼（日志由CultivationSystem.stop_cultivation()输出）
		cultivation_system.stop_cultivation()
		cultivate_button.text = "修炼"
		cultivation_stopped.emit()
	else:
		# 如果正在历练或等待中，先停止历练
		if lianli_system and (lianli_system.is_in_lianli or lianli_system.is_waiting):
			lianli_system.end_lianli()
			log_message.emit("已退出历练区域")
			# 通知GameUI切换回内视页面
			if game_ui and game_ui.has_method("show_neishi_tab"):
				game_ui.show_neishi_tab()
		
		# 开始修炼
		cultivation_system.start_cultivation()
		cultivate_button.text = "停止修炼"
		log_message.emit("开始修炼，灵气积累中...")
		cultivation_started.emit()

# 突破按钮按下
func on_breakthrough_button_pressed():
	if not player:
		return
	
	var result = player.attempt_breakthrough()
	if result.get("success", false):
		_handle_breakthrough_success(result)
	else:
		_handle_breakthrough_failure(result)

# 处理突破成功
func _handle_breakthrough_success(result: Dictionary):
	# 突破成功后恢复生命值到满
	player.set_health(player.get_final_max_health())
	
	var stone_cost = result.get("stone_cost", 0)
	var energy_cost = result.get("energy_cost", 0)
	var materials = result.get("materials", {})
	var type = result.get("type", "level")
	
	if type == "level":
		var new_level = result.get("new_level", 1)
		var success_msg = _build_breakthrough_message(stone_cost, energy_cost, materials, "突破成功！")
		log_message.emit(success_msg)
		log_message.emit("升至第" + str(new_level) + "层！气血值已恢复满！")
	else:
		var new_realm = result.get("new_realm", "")
		var success_msg = _build_breakthrough_message(stone_cost, energy_cost, materials, "晋升成功！")
		log_message.emit(success_msg)
		log_message.emit("进入" + new_realm + "！气血值已恢复满！")
	
	breakthrough_succeeded.emit(result)

# 处理突破失败
func _handle_breakthrough_failure(result: Dictionary):
	var reason = result.get("reason", "突破失败")
	var stone_cost = result.get("stone_cost", 0)
	var energy_cost = result.get("energy_cost", 0)
	var stone_current = result.get("stone_current", 0)
	var energy_current = result.get("energy_current", 0)
	var materials = result.get("materials", {})
	
	if reason == "灵气不足":
		log_message.emit("突破失败：灵气不足 (" + str(energy_current) + "/" + str(energy_cost) + ")")
	elif reason == "灵石不足":
		log_message.emit("突破失败：灵石不足 (" + str(stone_current) + "/" + str(stone_cost) + ")")
	elif reason.ends_with("不足"):
		# 材料不足提示
		for material_id in materials.keys():
			var material_info = materials[material_id]
			if not material_info.get("enough", true):
				var material_name = item_data.get_item_name(material_id) if item_data else material_id
				var current = int(material_info.get("current", 0))
				var required = int(material_info.get("required", 0))
				log_message.emit("突破失败：" + material_name + "不足 (" + str(current) + "/" + str(required) + ")")
				break
	else:
		log_message.emit("突破失败：" + reason)
	
	breakthrough_failed.emit(result)

# 构建突破消息
func _build_breakthrough_message(stone_cost: int, energy_cost: int, materials: Dictionary, suffix: String) -> String:
	var msg = "消耗灵石" + str(stone_cost) + "、灵气" + str(energy_cost)
	
	for material_id in materials.keys():
		var material_info = materials[material_id]
		var required_count = int(material_info.get("required", 0))
		if required_count > 0:
			var material_name = item_data.get_item_name(material_id) if item_data else material_id
			msg += "、" + material_name + str(required_count)
	
	msg += "，" + suffix
	return msg

# ==================== UI更新功能 ====================

## 更新修炼面板显示（气血、灵气、属性、状态）
func update_display(status: Dictionary = {}):
	if not player:
		return
	
	# 如果没有传入status，从player获取
	if status.is_empty():
		status = player.get_status_dict()
	
	# 更新气血条
	if health_bar:
		var final_max_health = player.get_final_max_health()
		health_bar.max_value = final_max_health
		health_bar.value = status.health
	if health_value:
		var final_max_health = player.get_final_max_health()
		health_value.text = AttributeCalculator.format_health_spirit(status.health) + "/" + AttributeCalculator.format_health_spirit(final_max_health)
	
	# 更新灵气条
	if spirit_bar:
		spirit_bar.max_value = player.get_final_max_spirit_energy()
		spirit_bar.value = status.spirit_energy
	if spirit_value:
		spirit_value.text = AttributeCalculator.format_health_spirit(status.spirit_energy) + "/" + AttributeCalculator.format_health_spirit(player.get_final_max_spirit_energy())
	
	# 更新属性显示
	if attack_label:
		attack_label.text = "攻击: " + AttributeCalculator.format_attack_defense(player.get_final_attack())
	if defense_label:
		defense_label.text = "防御: " + AttributeCalculator.format_attack_defense(player.get_final_defense())
	if speed_label:
		speed_label.text = "速度: " + AttributeCalculator.format_speed(player.get_final_speed())
	if spirit_gain_label:
		spirit_gain_label.text = "灵气获取: " + AttributeCalculator.format_spirit_gain_speed(player.get_final_spirit_gain_speed()) + "/秒"
	
	# 更新修炼状态
	if status.is_cultivating:
		if status_label:
			status_label.text = "修炼中..."
			status_label.modulate = Color.GREEN
		# 修炼时：隐藏基础小人，显示特效小人
		if cultivation_figure:
			cultivation_figure.visible = false
		if cultivation_figure_particles:
			cultivation_figure_particles.visible = true
	else:
		if status_label:
			status_label.text = "未修炼"
			status_label.modulate = Color.GRAY
		# 停止修炼时：显示基础小人，隐藏特效小人
		if cultivation_figure:
			cultivation_figure.visible = true
		if cultivation_figure_particles:
			cultivation_figure_particles.visible = false
	
	# 更新突破按钮文本
	var breakthrough_info = status.get("can_breakthrough", {})
	if breakthrough_button:
		breakthrough_button.disabled = false
		if breakthrough_info.get("type") == "realm":
			breakthrough_button.text = "破境"
		else:
			breakthrough_button.text = "突破"

# 清理
func cleanup():
	_is_initialized = false
