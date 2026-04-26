class_name DongfuModule extends Node

# 地区模块 - 处理地区入口（炼丹坊、百草山）等

# 信号
signal alchemy_room_requested
signal herb_gather_requested
signal task_panel_requested
signal log_message(message: String)

# 引用
var game_ui: Node = null
var player: Node = null
var alchemy_module = null

# UI节点引用
var region_panel: Control = null
var alchemy_workshop_button: Button = null
var herb_mountain_button: Button = null
var xianwu_office_button: Button = null

func initialize(ui: Node, player_node: Node, alchemy_mod = null):
	game_ui = ui
	player = player_node
	alchemy_module = alchemy_mod
	_setup_signals()

func _setup_signals():
	# 连接炼丹坊按钮
	if alchemy_workshop_button:
		alchemy_workshop_button.pressed.connect(_on_alchemy_workshop_pressed)
	# 百草山功能后续开放（本轮仅入口）
	if herb_mountain_button:
		herb_mountain_button.pressed.connect(_on_herb_mountain_pressed)
	if xianwu_office_button:
		xianwu_office_button.pressed.connect(_on_xianwu_office_pressed)

# 显示地区Tab
func show_tab():
	if region_panel:
		region_panel.visible = true

# 隐藏地区Tab
func hide_tab():
	if region_panel:
		region_panel.visible = false

func _get_spell_system() -> Node:
	if game_ui and is_instance_valid(game_ui):
		var spell_sys = game_ui.get("spell_system")
		if spell_sys:
			return spell_sys
	return null

func _is_spell_obtained(spell_id: String) -> bool:
	var spell_sys = _get_spell_system()
	if not spell_sys or not spell_sys.has_method("get_spell_info"):
		return false
	var spell_info = spell_sys.get_spell_info(spell_id)
	if spell_info.is_empty():
		return false
	return bool(spell_info.get("obtained", false)) or int(spell_info.get("level", 0)) > 0

func _on_alchemy_workshop_pressed():
	if not _is_spell_obtained("alchemy"):
		log_message.emit("需先学会炼丹术，才可进入炼丹坊")
		return
	# 隐藏地区面板
	if region_panel:
		region_panel.visible = false
	# 显示炼丹房
	if alchemy_module:
		alchemy_module.show_alchemy_room()
	# 发送信号
	alchemy_room_requested.emit()

func _on_herb_mountain_pressed():
	if not _is_spell_obtained("herb_gathering"):
		log_message.emit("需先学会草药采集术，才可进入百草山")
		return
	if region_panel:
		region_panel.visible = false
	herb_gather_requested.emit()


func _on_xianwu_office_pressed():
	if region_panel:
		region_panel.visible = false
	task_panel_requested.emit()
