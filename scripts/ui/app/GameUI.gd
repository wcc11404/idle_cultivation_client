extends Control

# 预加载模块
const AlchemyModule = preload("res://scripts/ui/modules/AlchemyModule.gd")
const SettingsModule = preload("res://scripts/ui/modules/SettingsModule.gd")
const DongfuModule = preload("res://scripts/ui/modules/DongfuModule.gd")
const ChunaModule = preload("res://scripts/ui/modules/ChunaModule.gd")
const SpellModule = preload("res://scripts/ui/modules/SpellModule.gd")
const NeishiModule = preload("res://scripts/ui/modules/NeishiModule.gd")
const CultivationModule = preload("res://scripts/ui/modules/CultivationModule.gd")
const LianliModule = preload("res://scripts/ui/modules/LianliModule.gd")
const GameServerAPI = preload("res://scripts/network/GameServerAPI.gd")

var player: Node = null
var inventory: Node = null
var spell_system: Node = null
var api: Node = null
var _silent_item_added_log_depth: int = 0

# 炼丹系统引用
var alchemy_system: Node = null
var recipe_data: Node = null
var alchemy_module = null

# 设置模块
var settings_module = null

# 洞府模块
var dongfu_module = null

# 储纳模块
var chuna_module = null

# 术法模块
var spell_module = null

# 内视模块（新增）
var neishi_module = null

# 修炼突破模块（新增）
var cultivation_module = null
var cultivation_system = null

# 历练模块（新增）
var lianli_module = null
var lianli_system = null

# 境界背景素材配置
const REALM_FRAME_TEXTURES = {
	"炼气期": "res://assets/realm_frames/realm_frame_qi_refining.png",
	"筑基期": "res://assets/realm_frames/realm_frame_foundation.png",
	"金丹期": "res://assets/realm_frames/realm_frame_golden_core.png",
	"元婴期": "res://assets/realm_frames/realm_frame_nascent_soul.png",
	"化神期": "res://assets/realm_frames/realm_frame_spirit_separation.png",
	"炼虚期": "res://assets/realm_frames/realm_frame_void_refining.png",
	"合体期": "res://assets/realm_frames/realm_frame_body_integration.png",
	"大乘期": "res://assets/realm_frames/realm_frame_mahayana.png",
	"渡劫期": "res://assets/realm_frames/realm_frame_tribulation.png"
}

@onready var player_name_label_top: Label = $VBoxContainer/TopBar/TopBarContent/PlayerInfo/PlayerNameLabel
@onready var avatar_texture: TextureRect = $VBoxContainer/TopBar/TopBarContent/PlayerInfo/AvatarContainer/AvatarTexture
@onready var top_bar_background: TextureRect = $VBoxContainer/TopBar/TopBarBackground
@onready var realm_label: Label = $VBoxContainer/TopBar/TopBarContent/RealmContainer/RealmLabel
@onready var spirit_stone_label: Label = $VBoxContainer/TopBar/TopBarContent/SpiritStoneContainer/SpiritStoneLabel

@onready var status_label: Label = $VBoxContainer/ContentPanel/NeishiPanel/CultivationContainer/CultivationVisual/CultivationStatusLabel
@onready var health_bar: ProgressBar = $VBoxContainer/ContentPanel/NeishiPanel/CultivationContainer/StatusArea/PlayerDataContainer/VBoxContainer/HealthRow/HealthBar
@onready var health_value: Label = $VBoxContainer/ContentPanel/NeishiPanel/CultivationContainer/StatusArea/PlayerDataContainer/VBoxContainer/HealthRow/HealthValue

# 灵气条
@onready var spirit_bar: ProgressBar = $VBoxContainer/ContentPanel/NeishiPanel/CultivationContainer/StatusArea/PlayerDataContainer/VBoxContainer/SpiritRow/SpiritBar
@onready var spirit_value: Label = $VBoxContainer/ContentPanel/NeishiPanel/CultivationContainer/StatusArea/PlayerDataContainer/VBoxContainer/SpiritRow/SpiritValue

# 属性标签
@onready var attack_label: Label = $VBoxContainer/ContentPanel/NeishiPanel/CultivationContainer/StatusArea/PlayerDataContainer/VBoxContainer/StatsRow/AttackLabel
@onready var defense_label: Label = $VBoxContainer/ContentPanel/NeishiPanel/CultivationContainer/StatusArea/PlayerDataContainer/VBoxContainer/StatsRow/DefenseLabel
@onready var speed_label: Label = $VBoxContainer/ContentPanel/NeishiPanel/CultivationContainer/StatusArea/PlayerDataContainer/VBoxContainer/StatsRow/SpeedLabel
@onready var spirit_gain_label: Label = $VBoxContainer/ContentPanel/NeishiPanel/CultivationContainer/StatusArea/PlayerDataContainer/VBoxContainer/SpiritGainLabel

# 灵气进度条现在在 CultivationContainer 中
#@onready var spirit_progress_bar: Control = $VBoxContainer/ContentPanel/NeishiPanel/CultivationContainer/SpiritProgressBar

# 修炼小人素材
@onready var cultivation_figure: TextureRect = $VBoxContainer/ContentPanel/NeishiPanel/CultivationContainer/CultivationVisual/CultivationFigure
@onready var cultivation_figure_particles: TextureRect = $VBoxContainer/ContentPanel/NeishiPanel/CultivationContainer/CultivationVisual/CultivationFigureParticles
@onready var cultivation_visual: Control = $VBoxContainer/ContentPanel/NeishiPanel/CultivationContainer/CultivationVisual

@onready var log_text: RichTextLabel = $VBoxContainer/LogArea/LogText
@onready var cultivate_button: Button = $VBoxContainer/ContentPanel/NeishiPanel/CultivationContainer/CultivationBottomBar/CultivateButton
@onready var breakthrough_button: Button = $VBoxContainer/ContentPanel/NeishiPanel/CultivationContainer/CultivationBottomBar/BreakthroughButton
@onready var bottom_bar: HBoxContainer = $VBoxContainer/ContentPanel/NeishiPanel/CultivationContainer/CultivationBottomBar

@onready var tab_neishi: Button = $VBoxContainer/TabBar/NeishiButton
@onready var tab_chuna: Button = $VBoxContainer/TabBar/ChunaButton
@onready var tab_dongfu: Button = get_node_or_null("VBoxContainer/TabBar/DongfuButton")
@onready var tab_lianli: Button = $VBoxContainer/TabBar/BattleButton
@onready var tab_settings: Button = $VBoxContainer/TabBar/SettingsButton

@onready var neishi_panel: Control = $VBoxContainer/ContentPanel/NeishiPanel
@onready var chuna_panel: Control = $VBoxContainer/ContentPanel/ChunaPanel
@onready var dongfu_panel: Control = get_node_or_null("VBoxContainer/ContentPanel/DongfuPanel")
@onready var lianli_panel: Control = $VBoxContainer/ContentPanel/LianliPanel
@onready var settings_panel: Control = $VBoxContainer/ContentPanel/SettingsPanel

# 内室子Tab
@onready var cultivation_tab: Button = $VBoxContainer/ContentPanel/NeishiPanel/NeishiTabBar/CultivationTab
@onready var spell_tab: Button = $VBoxContainer/ContentPanel/NeishiPanel/NeishiTabBar/SpellTab

@onready var cultivation_panel: Control = $VBoxContainer/ContentPanel/NeishiPanel/CultivationContainer
@onready var spell_panel: Control = $VBoxContainer/ContentPanel/NeishiPanel/SpellPanel
@onready var save_button: Button = $VBoxContainer/ContentPanel/SettingsPanel/VBoxContainer/SaveButton
@onready var logout_button: Button = $VBoxContainer/ContentPanel/SettingsPanel/VBoxContainer/LogoutButton
@onready var nickname_input: LineEdit = $VBoxContainer/ContentPanel/SettingsPanel/VBoxContainer/NicknameSection/NicknameHBox/NicknameInput
@onready var confirm_nickname_button: Button = $VBoxContainer/ContentPanel/SettingsPanel/VBoxContainer/NicknameSection/NicknameHBox/ConfirmNicknameButton
@onready var rank_button: Button = $VBoxContainer/ContentPanel/SettingsPanel/VBoxContainer/RankButton
@onready var rank_panel: Control = $VBoxContainer/ContentPanel/SettingsPanel/RankPanel
@onready var rank_list: VBoxContainer = $VBoxContainer/ContentPanel/SettingsPanel/RankPanel/VBoxContainer/RankList
@onready var back_button: Button = $VBoxContainer/ContentPanel/SettingsPanel/RankPanel/VBoxContainer/TitleBar/BackButton

@onready var lianli_select_panel: Control = $VBoxContainer/ContentPanel/LianliPanel/LianliSelectPanel
@onready var lianli_scene_panel: Control = $VBoxContainer/ContentPanel/LianliPanel/LianliScenePanel

@onready var inventory_grid: GridContainer = $VBoxContainer/ContentPanel/ChunaPanel/ScrollContainer/InventoryGrid
@onready var capacity_label: Label = $VBoxContainer/ContentPanel/ChunaPanel/TopBar/CapacityLabel
@onready var expand_button: Button = $VBoxContainer/ContentPanel/ChunaPanel/TopBar/ExpandButton
@onready var sort_button: Button = $VBoxContainer/ContentPanel/ChunaPanel/TopBar/SortButton
@onready var item_detail_panel: Panel = $VBoxContainer/ContentPanel/ChunaPanel/ItemDetailPanel
# 查看按钮（可选）
var view_button: Button = null
@onready var use_button: Button = $VBoxContainer/ContentPanel/ChunaPanel/ItemDetailPanel/VBoxContainer/ButtonContainer/UseButton
@onready var discard_button: Button = $VBoxContainer/ContentPanel/ChunaPanel/ItemDetailPanel/VBoxContainer/ButtonContainer/DiscardButton

@onready var lianli_area_1_button: Button = get_node_or_null("VBoxContainer/ContentPanel/LianliPanel/LianliSelectPanel/VBoxContainer/Area1Button")
@onready var lianli_area_2_button: Button = get_node_or_null("VBoxContainer/ContentPanel/LianliPanel/LianliSelectPanel/VBoxContainer/Area2Button")
@onready var lianli_area_3_button: Button = get_node_or_null("VBoxContainer/ContentPanel/LianliPanel/LianliSelectPanel/VBoxContainer/Area3Button")
@onready var lianli_area_4_button: Button = get_node_or_null("VBoxContainer/ContentPanel/LianliPanel/LianliSelectPanel/VBoxContainer/Area4Button")
@onready var lianli_area_5_button: Button = get_node_or_null("VBoxContainer/ContentPanel/LianliPanel/LianliSelectPanel/VBoxContainer/Area5Button")
@onready var lianli_area_6_button: Button = get_node_or_null("VBoxContainer/ContentPanel/LianliPanel/LianliSelectPanel/VBoxContainer/EndlessTowerButton")
@onready var endless_tower_button: Button = get_node_or_null("VBoxContainer/ContentPanel/LianliPanel/LianliSelectPanel/VBoxContainer/EndlessTowerButton")

# 炼丹房UI节点
@onready var alchemy_room_button: Button = get_node_or_null("VBoxContainer/ContentPanel/DongfuPanel/VBoxContainer/AlchemyRoomButton")
@onready var alchemy_room_panel: Control = get_node_or_null("VBoxContainer/ContentPanel/AlchemyRoomPanel")
@onready var recipe_list_container: VBoxContainer = get_node_or_null("VBoxContainer/ContentPanel/AlchemyRoomPanel/VBoxContainer/MainHBox/RecipeListPanel/RecipeListVBox/RecipeScroll/RecipeListContainer")
@onready var recipe_name_label: Label = get_node_or_null("VBoxContainer/ContentPanel/AlchemyRoomPanel/VBoxContainer/MainHBox/CraftPanel/CraftVBox/RecipeNameLabel")
@onready var success_rate_label: Label = get_node_or_null("VBoxContainer/ContentPanel/AlchemyRoomPanel/VBoxContainer/MainHBox/CraftPanel/CraftVBox/SuccessRateLabel")
@onready var craft_time_label: Label = get_node_or_null("VBoxContainer/ContentPanel/AlchemyRoomPanel/VBoxContainer/MainHBox/CraftPanel/CraftVBox/CraftTimeLabel")
@onready var materials_container: VBoxContainer = get_node_or_null("VBoxContainer/ContentPanel/AlchemyRoomPanel/VBoxContainer/MainHBox/CraftPanel/CraftVBox/MaterialsContainer")
@onready var craft_button: Button = get_node_or_null("VBoxContainer/ContentPanel/AlchemyRoomPanel/VBoxContainer/MainHBox/CraftPanel/CraftVBox/ButtonHBox/CraftButton")
@onready var stop_button: Button = get_node_or_null("VBoxContainer/ContentPanel/AlchemyRoomPanel/VBoxContainer/MainHBox/CraftPanel/CraftVBox/ButtonHBox/StopButton")
@onready var craft_progress_bar: ProgressBar = get_node_or_null("VBoxContainer/ContentPanel/AlchemyRoomPanel/VBoxContainer/MainHBox/CraftPanel/CraftVBox/CraftProgressBar")
@onready var craft_count_label: Label = get_node_or_null("VBoxContainer/ContentPanel/AlchemyRoomPanel/VBoxContainer/MainHBox/CraftPanel/CraftVBox/CraftCountLabel")
@onready var count_1_button: Button = get_node_or_null("VBoxContainer/ContentPanel/AlchemyRoomPanel/VBoxContainer/MainHBox/CraftPanel/CraftVBox/CountHBox/Count1Button")
@onready var count_10_button: Button = get_node_or_null("VBoxContainer/ContentPanel/AlchemyRoomPanel/VBoxContainer/MainHBox/CraftPanel/CraftVBox/CountHBox/Count10Button")
@onready var count_100_button: Button = get_node_or_null("VBoxContainer/ContentPanel/AlchemyRoomPanel/VBoxContainer/MainHBox/CraftPanel/CraftVBox/CountHBox/Count100Button")
@onready var count_max_button: Button = get_node_or_null("VBoxContainer/ContentPanel/AlchemyRoomPanel/VBoxContainer/MainHBox/CraftPanel/CraftVBox/CountHBox/CountMaxButton")
@onready var alchemy_info_label: Label = get_node_or_null("VBoxContainer/ContentPanel/AlchemyRoomPanel/VBoxContainer/BottomPanel/BottomVBox/BottomHBox/AlchemyInfoLabel")
@onready var furnace_info_label: Label = get_node_or_null("VBoxContainer/ContentPanel/AlchemyRoomPanel/VBoxContainer/BottomPanel/BottomVBox/BottomHBox/FurnaceInfoLabel")
@onready var alchemy_back_button: Button = get_node_or_null("VBoxContainer/ContentPanel/AlchemyRoomPanel/VBoxContainer/TitleBar/BackButton")

# 区域按钮列表
var lianli_area_buttons: Array = []
var lianli_area_ids: Array = []

@onready var player_name_label: Label = $VBoxContainer/ContentPanel/LianliPanel/LianliScenePanel/VBoxContainer/PlayerInfo/PlayerNameLabel
@onready var player_health_bar_lianli: ProgressBar = $VBoxContainer/ContentPanel/LianliPanel/LianliScenePanel/VBoxContainer/PlayerInfo/PlayerHealthBar
@onready var player_health_value_lianli: Label = $VBoxContainer/ContentPanel/LianliPanel/LianliScenePanel/VBoxContainer/PlayerInfo/PlayerHealthValue
@onready var enemy_name_label: Label = $VBoxContainer/ContentPanel/LianliPanel/LianliScenePanel/VBoxContainer/EnemyInfo/EnemyNameLabel
@onready var enemy_health_bar: ProgressBar = $VBoxContainer/ContentPanel/LianliPanel/LianliScenePanel/VBoxContainer/EnemyInfo/EnemyHealthBar
@onready var enemy_health_value: Label = $VBoxContainer/ContentPanel/LianliPanel/LianliScenePanel/VBoxContainer/EnemyInfo/EnemyHealthValue
@onready var lianli_status_label: Label = $VBoxContainer/ContentPanel/LianliPanel/LianliScenePanel/VBoxContainer/LianliStatusLabel

# BattleInfo UI控件
@onready var area_name_label: Label = get_node_or_null("VBoxContainer/ContentPanel/LianliPanel/LianliScenePanel/VBoxContainer/BattleInfo/AreaNameLabel")
@onready var reward_info_label: Label = get_node_or_null("VBoxContainer/ContentPanel/LianliPanel/LianliScenePanel/VBoxContainer/BattleInfo/RewardInfoLabel")

# BattleButtonContainer UI控件
@onready var continuous_checkbox: CheckBox = get_node_or_null("VBoxContainer/ContentPanel/LianliPanel/LianliScenePanel/VBoxContainer/BattleButtonContainer/ContinuousCheckBox")
@onready var continue_button: Button = get_node_or_null("VBoxContainer/ContentPanel/LianliPanel/LianliScenePanel/VBoxContainer/BattleButtonContainer/ContinueButton")
@onready var lianli_speed_button: Button = $VBoxContainer/ContentPanel/LianliPanel/LianliScenePanel/VBoxContainer/BattleButtonContainer/SpeedExitContainer/LianliSpeedButton
@onready var exit_lianli_button: Button = $VBoxContainer/ContentPanel/LianliPanel/LianliScenePanel/VBoxContainer/BattleButtonContainer/SpeedExitContainer/ExitLianliButton

var log_manager: LogManager = null

const GRID_COLS = 5

var item_data_ref: Node = null
var spell_data_ref: Node = null
var lianli_area_data: Node = null
var enemy_data: Node = null

var current_lianli_area_id: String = ""
var current_lianli_speed_index: int = 0
const LIANLI_SPEEDS = [1.0, 1.5, 2.0]
var active_mode: String = "none"
var allow_background_server_refresh: bool = true
var _test_shutdown_requested: bool = false
var _pending_refresh_all_player_data_count: int = 0
var _network_ui_last_log_at: float = 0.0
const NETWORK_UI_LOG_THROTTLE_SECONDS := 2.0

func _ready():
	# 安全获取可选节点
	_setup_optional_nodes()
	
	# 初始化GameServerAPI
	api = GameServerAPI.new()
	add_child(api)
	
	await get_tree().process_frame
	_bind_network_error_bridge()
	
	# 先初始化所有模块
	setup_log_manager()
	setup_alchemy_module()
	setup_settings_module()
	setup_dongfu_module()
	setup_chuna_module()
	setup_spell_module()
	setup_neishi_module()
	setup_lianli_module()
	
	# 再连接按钮信号（模块已创建）
	setup_button_connections()
	
	# 显示默认内视页面（模块初始化完成后）
	show_neishi_tab()
	
	# 在log_manager初始化后添加欢迎消息
	if log_manager:
		log_manager.add_system_log("欢迎来到修仙世界！")
		log_manager.add_system_log("点击下方按钮开始修炼")
	
	# 加载游戏数据（模块初始化完成后）
	load_game_data()
	
	# 游戏加载完成后获取离线奖励
	await claim_offline_reward()

func _setup_optional_nodes():
	view_button = get_node_or_null("VBoxContainer/ContentPanel/ChunaPanel/ItemDetailPanel/VBoxContainer/ButtonContainer/ViewButton")

	# 监听屏幕大小变化
	get_viewport().size_changed.connect(_on_viewport_size_changed)

func _on_viewport_size_changed():
	update_font_sizes()

func update_font_sizes():
	var screen_width = get_viewport().get_visible_rect().size.x
	var scale_factor = screen_width / 720.0
	
	# 更新主要标签字体大小
	var base_font_sizes = {
		"player_name": 26,
		"realm": 24,
		"spirit_stone": 20,
		"status": 20,
		"health_value": 16,
		"log": 14,
		"button": 18
	}
	
	if player_name_label_top:
		player_name_label_top.add_theme_font_size_override("font_size", int(base_font_sizes["player_name"] * scale_factor))
	if realm_label:
		realm_label.add_theme_font_size_override("font_size", int(base_font_sizes["realm"] * scale_factor))
	if spirit_stone_label:
		spirit_stone_label.add_theme_font_size_override("font_size", int(base_font_sizes["spirit_stone"] * scale_factor))
	if status_label:
		status_label.add_theme_font_size_override("font_size", int(base_font_sizes["status"] * scale_factor))
	if health_value:
		health_value.add_theme_font_size_override("font_size", int(base_font_sizes["health_value"] * scale_factor))
	if log_text:
		log_text.add_theme_font_size_override("normal_font_size", int(base_font_sizes["log"] * scale_factor))
	
	# 更新按钮字体
	var buttons = [cultivate_button, breakthrough_button, tab_neishi, tab_chuna, tab_lianli, tab_settings]
	for button in buttons:
		if button:
			button.add_theme_font_size_override("font_size", int(base_font_sizes["button"] * scale_factor))

func _process(delta: float):
	# 更新UI
	if player:
		update_ui()

func setup_log_manager():
	log_manager = LogManager.new()
	log_manager.name = "LogManager"
	add_child(log_manager)
	log_manager.set_rich_text_label(log_text)

func setup_button_connections():
	# 修炼和突破按钮（CultivationModule）
	if cultivate_button and cultivation_module:
		cultivate_button.pressed.connect(cultivation_module.on_cultivate_button_pressed)
	if breakthrough_button and cultivation_module:
		breakthrough_button.pressed.connect(cultivation_module.on_breakthrough_button_pressed)
	
	if tab_neishi:
		tab_neishi.pressed.connect(_on_tab_neishi_pressed)
	if tab_chuna:
		tab_chuna.pressed.connect(_on_tab_chuna_pressed)
	if tab_dongfu:
		tab_dongfu.pressed.connect(_on_tab_dongfu_pressed)
	if tab_lianli:
		tab_lianli.pressed.connect(_on_tab_lianli_pressed)
	if tab_settings:
		tab_settings.pressed.connect(_on_tab_settings_pressed)
	
	# 内室子Tab连接（NeishiModule）
	if cultivation_tab and neishi_module:
		cultivation_tab.pressed.connect(neishi_module.on_cultivation_tab_pressed)
	if spell_tab and neishi_module:
		spell_tab.pressed.connect(neishi_module.on_spell_tab_pressed)
	
	# 初始化无尽塔按钮（不需要lianli_area_data）
	_init_endless_tower_button()
	
	# 注意：历练区域按钮在load_game_data()之后初始化
	
	# 历练按钮连接（LianliModule）
	if continuous_checkbox and lianli_module:
		continuous_checkbox.toggled.connect(lianli_module.on_continuous_toggled)
	if continue_button and lianli_module:
		continue_button.pressed.connect(lianli_module.on_continue_pressed)
	if lianli_speed_button and lianli_module:
		lianli_speed_button.pressed.connect(lianli_module.on_lianli_speed_pressed)
	if exit_lianli_button and lianli_module:
		exit_lianli_button.pressed.connect(lianli_module.on_exit_lianli_pressed)

func setup_alchemy_module():
	# 创建炼丹模块
	alchemy_module = AlchemyModule.new()
	alchemy_module.name = "AlchemyModule"
	add_child(alchemy_module)
	
	# 设置UI节点引用
	alchemy_module.alchemy_room_panel = alchemy_room_panel
	alchemy_module.recipe_list_container = recipe_list_container
	alchemy_module.recipe_name_label = recipe_name_label
	alchemy_module.success_rate_label = success_rate_label
	alchemy_module.craft_time_label = craft_time_label
	alchemy_module.materials_container = materials_container
	alchemy_module.craft_button = craft_button
	alchemy_module.stop_button = stop_button
	alchemy_module.craft_progress_bar = craft_progress_bar
	alchemy_module.craft_count_label = craft_count_label
	alchemy_module.alchemy_info_label = alchemy_info_label
	alchemy_module.furnace_info_label = furnace_info_label
	alchemy_module.count_1_button = count_1_button
	alchemy_module.count_10_button = count_10_button
	alchemy_module.count_100_button = count_100_button
	alchemy_module.count_max_button = count_max_button
	alchemy_module.alchemy_back_button = alchemy_back_button
	
	# 初始化炼丹模块（在设置UI节点引用之后）
	alchemy_module.initialize(self, player, alchemy_system, recipe_data, item_data_ref, api)
	
	# 设置样式（必须在所有引用设置完成后）
	alchemy_module.setup_styles()

	# 连接数量选择按钮
	if count_1_button:
		count_1_button.pressed.connect(func(): _on_craft_count_changed(1))
	if count_10_button:
		count_10_button.pressed.connect(func(): _on_craft_count_changed(10))
	if count_100_button:
		count_100_button.pressed.connect(func(): _on_craft_count_changed(100))
	if count_max_button:
		count_max_button.pressed.connect(_on_craft_count_max)
	
	# 连接信号
	alchemy_module.log_message.connect(_on_alchemy_log)
	alchemy_module.back_to_dongfu_requested.connect(_on_back_to_dongfu_requested)
	
	# 连接返回按钮
	if alchemy_back_button:
		alchemy_back_button.pressed.connect(_on_back_to_dongfu_requested)

func _on_back_to_dongfu_requested():
	"""处理返回洞府请求"""
	show_dongfu_tab()

func setup_settings_module():
	# 创建设置模块
	settings_module = SettingsModule.new()
	settings_module.name = "SettingsModule"
	add_child(settings_module)
	
	# 设置UI节点引用
	settings_module.settings_panel = settings_panel
	settings_module.save_button = save_button
	settings_module.logout_button = logout_button
	settings_module.nickname_input = nickname_input
	settings_module.confirm_nickname_button = confirm_nickname_button
	settings_module.rank_button = rank_button
	settings_module.rank_panel = rank_panel
	settings_module.rank_list = rank_list
	settings_module.back_button = back_button
	
	# 初始化模块
	settings_module.initialize(self, player, api)
	
	# 连接信号
	settings_module.log_message.connect(_on_module_log)

func setup_dongfu_module():
	# 创建洞府模块
	dongfu_module = DongfuModule.new()
	dongfu_module.name = "DongfuModule"
	add_child(dongfu_module)
	
	# 设置UI节点引用
	dongfu_module.dongfu_panel = dongfu_panel
	dongfu_module.alchemy_room_button = alchemy_room_button
	
	# 初始化模块
	dongfu_module.initialize(self, player, alchemy_module)

func setup_chuna_module():
	# 创建储纳模块
	chuna_module = ChunaModule.new()
	chuna_module.name = "ChunaModule"
	add_child(chuna_module)
	
	# 设置UI节点引用
	chuna_module.chuna_panel = chuna_panel
	chuna_module.inventory_grid = inventory_grid
	chuna_module.capacity_label = capacity_label
	chuna_module.item_detail_panel = item_detail_panel
	chuna_module.view_button = view_button
	chuna_module.use_button = use_button
	chuna_module.discard_button = discard_button
	chuna_module.expand_button = expand_button
	chuna_module.sort_button = sort_button
	
	# 初始化模块
	chuna_module.initialize(self, player, inventory, item_data_ref, spell_system, spell_data_ref, alchemy_system, api, recipe_data)
	
	# 连接信号
	chuna_module.log_message.connect(_on_module_log)

func setup_spell_module():
	spell_module = SpellModule.new()
	spell_module.name = "SpellModule"
	add_child(spell_module)
	
	# 设置UI节点引用
	spell_module.spell_panel = spell_panel
	spell_module.spell_tab = spell_tab
	
	# 初始化模块
	spell_module.initialize(self, player, spell_system, spell_data_ref, api)
	
	# 连接信号
	spell_module.log_message.connect(_on_module_log)

func setup_neishi_module():
	# 创建修炼突破模块
	cultivation_module = CultivationModule.new()
	cultivation_module.name = "CultivationModule"
	add_child(cultivation_module)
	
	# 设置UI节点引用
	cultivation_module.cultivation_panel = cultivation_panel
	cultivation_module.cultivate_button = cultivate_button
	cultivation_module.breakthrough_button = breakthrough_button
	
	# 设置气血/灵气条
	cultivation_module.health_bar = health_bar
	cultivation_module.health_value = health_value
	cultivation_module.spirit_bar = spirit_bar
	cultivation_module.spirit_value = spirit_value
	
	# 设置属性标签
	cultivation_module.attack_label = attack_label
	cultivation_module.defense_label = defense_label
	cultivation_module.speed_label = speed_label
	cultivation_module.spirit_gain_label = spirit_gain_label
	
	# 设置修炼状态标签和小人素材
	cultivation_module.status_label = status_label
	cultivation_module.cultivation_figure = cultivation_figure
	cultivation_module.cultivation_figure_particles = cultivation_figure_particles
	
	# 初始化模块
	var game_manager = get_node("/root/GameManager")
	cultivation_system = game_manager.get_cultivation_system() if game_manager else null
	lianli_system = game_manager.get_lianli_system() if game_manager else null
	var realm_system = game_manager.get_realm_system() if game_manager else null
	cultivation_module.initialize(self, player, cultivation_system, lianli_system, item_data_ref, alchemy_module, api, spell_system, realm_system)
	
	# 连接信号
	cultivation_module.log_message.connect(_on_module_log)
	
	# 创建内视模块
	neishi_module = NeishiModule.new()
	neishi_module.name = "NeishiModule"
	add_child(neishi_module)
	
	# 设置UI节点引用
	neishi_module.neishi_panel = neishi_panel
	neishi_module.cultivation_panel = cultivation_panel
	neishi_module.spell_panel = spell_panel
	neishi_module.cultivation_tab = cultivation_tab
	neishi_module.spell_tab = spell_tab
	
	# 初始化模块
	neishi_module.initialize(self, player)
	
	# 设置子模块
	neishi_module.set_cultivation_module(cultivation_module)
	neishi_module.set_spell_module(spell_module)
	
	# 连接信号
	neishi_module.log_message.connect(_on_module_log)

func _on_module_log(message: String):
	"""统一处理各模块的日志消息"""
	if log_manager:
		log_manager.add_system_log(message)

func _bind_network_error_bridge():
	var net = get_node_or_null("/root/GlobalNetworkManager")
	if net and net.has_signal("technical_error_for_ui"):
		if not net.technical_error_for_ui.is_connected(_on_network_technical_error_for_ui):
			net.technical_error_for_ui.connect(_on_network_technical_error_for_ui)

func _on_network_technical_error_for_ui(_message: String):
	# 统一口子：当前写入富文本日志，后续可在这里切换为弹窗。
	var now_sec = Time.get_unix_time_from_system()
	if now_sec - _network_ui_last_log_at < NETWORK_UI_LOG_THROTTLE_SECONDS:
		return
	_network_ui_last_log_at = now_sec
	if log_manager:
		log_manager.add_system_log("网络错误，请稍后再重试")

func _on_alchemy_log(message: String):
	"""处理炼丹模块的日志消息"""
	if log_manager:
		log_manager.add_alchemy_log(message)

func setup_lianli_module():
	# 创建历练模块
	lianli_module = LianliModule.new()
	lianli_module.name = "LianliModule"
	add_child(lianli_module)
	
	# 设置UI节点引用
	lianli_module.lianli_panel = lianli_panel
	lianli_module.lianli_scene_panel = lianli_scene_panel
	lianli_module.lianli_select_panel = lianli_select_panel
	lianli_module.lianli_status_label = lianli_status_label
	lianli_module.area_name_label = area_name_label
	lianli_module.reward_info_label = reward_info_label
	
	# 战斗UI
	lianli_module.enemy_name_label = enemy_name_label
	lianli_module.enemy_health_bar = enemy_health_bar
	lianli_module.enemy_health_value = enemy_health_value
	lianli_module.player_health_bar_lianli = player_health_bar_lianli
	lianli_module.player_health_value_lianli = player_health_value_lianli
	
	lianli_module.continuous_checkbox = continuous_checkbox
	lianli_module.continue_button = continue_button
	lianli_module.lianli_speed_button = lianli_speed_button
	lianli_module.exit_lianli_button = exit_lianli_button
	
	lianli_module.initialize(self, player, lianli_system, lianli_area_data, item_data_ref, inventory, chuna_module, log_manager, alchemy_module, api, spell_data_ref, spell_system)
	
	lianli_module.log_message.connect(_on_module_log)

func load_game_data():
	var game_manager = get_node("/root/GameManager")
	if game_manager:
		item_data_ref = game_manager.get_item_data()
		spell_data_ref = game_manager.get_spell_data()
		lianli_system = game_manager.get_lianli_system()
		lianli_area_data = game_manager.get_lianli_area_data()
		enemy_data = game_manager.get_enemy_data()
		set_spell_system(game_manager.get_spell_system())
		
		set_alchemy_system(game_manager.get_alchemy_system())
		set_recipe_data(game_manager.get_recipe_data())
		set_item_data(game_manager.get_item_data())
		
		if game_manager.get_player():
			set_player(game_manager.get_player())
		if game_manager.get_inventory():
			set_inventory(game_manager.get_inventory())
		
		lianli_system = game_manager.get_lianli_system()
		lianli_area_data = game_manager.get_lianli_area_data()
		
		if lianli_module:
			lianli_module.lianli_system = lianli_system
			lianli_module.lianli_area_data = lianli_area_data
			lianli_module.item_data_ref = item_data_ref
			lianli_module.spell_data = spell_data_ref
			lianli_module.spell_system = spell_system
		
		if spell_module:
			spell_module.spell_system = spell_system
			spell_module.spell_data = spell_data_ref
			spell_module.player = player
			spell_module.api = api
			spell_module.update_spell_ui()
		
		_init_lianli_area_buttons()
		
		if lianli_module and endless_tower_button:
			lianli_module.update_endless_tower_button_text(endless_tower_button)
		
		game_manager.account_logged_in.connect(_on_account_logged_in)
		
		update_account_ui()

func set_player(player_node: Node):
	player = player_node
	# 初始化炼丹模块的玩家引用
	if alchemy_module:
		alchemy_module.player = player
	# 初始化储纳模块的玩家引用
	if chuna_module:
		chuna_module.player = player
	# 初始化修炼突破模块的玩家引用
	if cultivation_module:
		cultivation_module.player = player
	# 初始化术法模块的玩家引用
	if spell_module:
		spell_module.player = player
	# 初始化历练模块的玩家引用
	if lianli_module:
		lianli_module.player = player
	# 初始化设置模块的玩家引用
	if settings_module:
		settings_module.player = player

func set_spell_system(spell_system_node: Node):
	spell_system = spell_system_node
	# 连接术法使用信号，实现使用次数实时更新
	if spell_system:
		spell_system.spell_used.connect(_on_spell_used)
	# 初始化术法模块的术法系统引用
	if spell_module:
		spell_module.spell_system = spell_system
		spell_module.spell_data = spell_data_ref
	# 初始化储纳模块的术法系统引用
	if chuna_module:
		chuna_module.spell_system = spell_system
		chuna_module.spell_data = spell_data_ref

func set_alchemy_system(alchemy_system_node: Node):
	alchemy_system = alchemy_system_node
	# 初始化炼丹模块的炼丹系统引用
	if alchemy_module:
		alchemy_module.alchemy_system = alchemy_system
	# 初始化储纳模块的炼丹系统引用
	if chuna_module:
		chuna_module.alchemy_system = alchemy_system

func set_recipe_data(recipe_data_node: Node):
	recipe_data = recipe_data_node
	# 初始化炼丹模块的丹方数据引用
	if alchemy_module:
		alchemy_module.recipe_data = recipe_data

func set_item_data(item_data_node: Node):
	item_data_ref = item_data_node
	if alchemy_module:
		alchemy_module.item_data = item_data_node
	if chuna_module:
		chuna_module.item_data = item_data_node
	if cultivation_module:
		cultivation_module.item_data = item_data_node

func _on_spell_used(spell_id: String):
	# 通知术法模块更新使用次数
	if spell_module:
		spell_module.on_spell_used(spell_id)

func set_inventory(inventory_node: Node):
	inventory = inventory_node
	if chuna_module:
		chuna_module.inventory = inventory
		chuna_module.update_inventory_ui()
	if cultivation_module:
		cultivation_module.inventory = inventory
	if lianli_module:
		lianli_module.inventory = inventory
	if alchemy_module:
		alchemy_module.inventory = inventory

func refresh_all_player_data():
	"""
	统一刷新所有玩家数据。
	在进行全量数据同步前，会尝试先上报各模块的本地缓存数据。
	"""
	_pending_refresh_all_player_data_count += 1
	# 1. 先上报修炼进度（乐观更新的数据）
	if cultivation_module:
		await cultivation_module._flush_pending_report()
	
	# 2. 从服务器加载全量数据
	if _test_shutdown_requested or not api:
		_pending_refresh_all_player_data_count = maxi(0, _pending_refresh_all_player_data_count - 1)
		return
		
	var result = await api.load_game()
	if not result.get("success", false):
		_on_module_log("玩家数据同步失败，请检查网络连接")
		_pending_refresh_all_player_data_count = maxi(0, _pending_refresh_all_player_data_count - 1)
		return

	var data = result.get("data", {})
	
	# 3. 分发并应用数据到各个核心系统
	if data.has("player") and player:
		player.apply_save_data(data["player"])
		
	if data.has("inventory") and inventory:
		inventory.apply_save_data(data["inventory"])
		# 强制触发储纳模块 UI 刷新
		if chuna_module:
			chuna_module.inventory = inventory # 确保引用最新
			chuna_module.item_data = item_data_ref # 确保引用最新
			chuna_module.setup_inventory_grid()
			chuna_module.update_inventory_ui()
			
	if data.has("spell_system") and spell_system:
		spell_system.apply_save_data(data["spell_system"])
		if spell_module:
			spell_module.spell_system = spell_system # 确保引用最新
			spell_module.spell_data = spell_data_ref # 确保引用最新
			spell_module.update_spell_ui()
			
	if data.has("alchemy_system") and alchemy_system:
		alchemy_system.apply_save_data(data["alchemy_system"])
		if alchemy_module:
			alchemy_module.alchemy_system = alchemy_system # 确保引用最新
			alchemy_module.item_data = item_data_ref # 确保引用最新
			alchemy_module.refresh_ui()
			
	# 4. 更新主界面 UI（属性条、境界等）
	update_ui()
	
	# 历练模块可能也需要更新
	if lianli_module:
		lianli_module.inventory = inventory # 确保引用最新
		lianli_module.item_data_ref = item_data_ref # 确保引用最新
		if data.has("lianli_system"):
			lianli_module.on_player_data_refreshed(data["lianli_system"])
		# 刷新历练区域按钮（可能涉及次数刷新）
		update_lianli_area_buttons_display()
		# 从服务器刷新副本信息缓存
		if allow_background_server_refresh:
			call_deferred("_refresh_lianli_info_from_server")

	if inventory and not inventory.item_added.is_connected(_on_item_added):
		inventory.item_added.connect(_on_item_added)
	_pending_refresh_all_player_data_count = maxi(0, _pending_refresh_all_player_data_count - 1)

func _on_item_added(item_id: String, count: int):
	if chuna_module:
		chuna_module.update_inventory_ui()
	update_ui()  # 更新灵石数量显示
	if _silent_item_added_log_depth > 0:
		return
	if log_manager:
		log_manager.add_system_log("获得物品: " + item_data_ref.get_item_name(item_id) + " x" + str(count))

func begin_silent_item_added_logs():
	_silent_item_added_log_depth += 1

func end_silent_item_added_logs():
	_silent_item_added_log_depth = max(0, _silent_item_added_log_depth - 1)

func show_neishi_tab():
	neishi_panel.visible = true
	chuna_panel.visible = false
	if dongfu_panel:
		dongfu_panel.visible = false
	lianli_panel.visible = false
	settings_panel.visible = false
	# 隐藏炼丹房
	if alchemy_module:
		alchemy_module.hide_alchemy_room()
	# 隐藏储纳Tab
	if chuna_module:
		chuna_module.hide_tab()
	tab_neishi.disabled = true
	tab_chuna.disabled = false
	if tab_dongfu:
		tab_dongfu.disabled = false
	tab_lianli.disabled = false
	tab_settings.disabled = false

	# 初始化内室子Tab（NeishiModule）
	if neishi_module:
		neishi_module.show_tab()

func show_chuna_tab():
	neishi_panel.visible = false
	chuna_panel.visible = true
	if dongfu_panel:
		dongfu_panel.visible = false
	lianli_panel.visible = false
	settings_panel.visible = false
	# 隐藏炼丹房
	if alchemy_module:
		alchemy_module.hide_alchemy_room()
	# 显示储纳Tab
	if chuna_module:
		chuna_module.show_tab()
	tab_neishi.disabled = false
	tab_chuna.disabled = true
	if tab_dongfu:
		tab_dongfu.disabled = false
	tab_lianli.disabled = false
	tab_settings.disabled = false
	# 确保面板可见
	if item_detail_panel:
		item_detail_panel.visible = true

func show_dongfu_tab():
	neishi_panel.visible = false
	chuna_panel.visible = false
	if dongfu_panel:
		dongfu_panel.visible = true
	lianli_panel.visible = false
	settings_panel.visible = false
	# 隐藏炼丹房
	if alchemy_module:
		alchemy_module.hide_alchemy_room()
	# 显示洞府Tab
	if dongfu_module:
		dongfu_module.show_tab()
	tab_neishi.disabled = false
	tab_chuna.disabled = false
	if tab_dongfu:
		tab_dongfu.disabled = true
	tab_lianli.disabled = false
	tab_settings.disabled = false

func show_lianli_tab():
	neishi_panel.visible = false
	chuna_panel.visible = false
	if dongfu_panel:
		dongfu_panel.visible = false
	lianli_panel.visible = true
	settings_panel.visible = false
	# 隐藏炼丹房
	if alchemy_module:
		alchemy_module.hide_alchemy_room()
	tab_neishi.disabled = false
	tab_chuna.disabled = false
	if tab_dongfu:
		tab_dongfu.disabled = false
	tab_lianli.disabled = true
	tab_settings.disabled = false

	# 先用本地快照更新，再异步从服务端刷新每日次数/塔层
	update_lianli_area_buttons_display()
	if endless_tower_button and lianli_module:
		lianli_module.update_endless_tower_button_text(endless_tower_button)
	if allow_background_server_refresh:
		call_deferred("_refresh_lianli_info_from_server")

	# 检查是否处于历练中
	if lianli_module:
		if lianli_system and lianli_system.is_in_lianli:
			# 还在历练中，显示战斗场景
			lianli_module.show_lianli_scene_panel()
		else:
			# 历练已结束或未开始，显示选择面板
			lianli_module.show_lianli_select_panel()

func show_settings_tab():
	neishi_panel.visible = false
	chuna_panel.visible = false
	if dongfu_panel:
		dongfu_panel.visible = false
	lianli_panel.visible = false
	settings_panel.visible = true
	# 隐藏炼丹房
	if alchemy_module:
		alchemy_module.hide_alchemy_room()
	# 显示设置Tab
	if settings_module:
		settings_module.show_tab()
	tab_neishi.disabled = false
	tab_chuna.disabled = false
	if tab_dongfu:
		tab_dongfu.disabled = false
	tab_lianli.disabled = false
	tab_settings.disabled = true

func _on_tab_neishi_pressed():
	show_neishi_tab()

func _on_tab_chuna_pressed():
	show_chuna_tab()

func _on_tab_dongfu_pressed():
	show_dongfu_tab()

func _on_tab_lianli_pressed():
	show_lianli_tab()

func _on_tab_settings_pressed():
	show_settings_tab()

func set_active_mode(mode: String):
	active_mode = mode

func clear_active_mode(mode: String):
	if active_mode == mode:
		active_mode = "none"

func can_enter_mode(target_mode: String) -> Dictionary:
	if active_mode == "none" or active_mode == target_mode:
		return {"ok": true, "message": ""}

	match active_mode:
		"cultivation":
			return {"ok": false, "message": "请先停止修炼"}
		"alchemy":
			return {"ok": false, "message": "请先停止炼丹"}
		"lianli":
			return {"ok": false, "message": "请先结束历练"}
		_:
			return {"ok": false, "message": "当前有进行中的操作"}

# 初始化历练区域按钮
func _init_lianli_area_buttons():
	lianli_area_buttons = []
	lianli_area_ids = []
	
	if lianli_area_1_button:
		lianli_area_buttons.append(lianli_area_1_button)
	if lianli_area_2_button:
		lianli_area_buttons.append(lianli_area_2_button)
	if lianli_area_3_button:
		lianli_area_buttons.append(lianli_area_3_button)
	if lianli_area_4_button:
		lianli_area_buttons.append(lianli_area_4_button)
	if lianli_area_6_button:
		lianli_area_buttons.append(lianli_area_6_button)
	if lianli_area_5_button:
		lianli_area_buttons.append(lianli_area_5_button)
	
	var normal_area_ids = []
	var daily_area_ids = []
	
	if lianli_area_data:
		normal_area_ids = lianli_area_data.get_normal_area_ids()
		daily_area_ids = lianli_area_data.get_daily_area_ids()
	else:
		normal_area_ids = ["qi_refining_outer", "qi_refining_inner", "foundation_outer", "foundation_inner"]
		daily_area_ids = ["foundation_herb_cave"]
	
	var tower_area_ids = ["endless_tower"]

	lianli_area_ids = normal_area_ids + daily_area_ids + tower_area_ids
	
	# 更新按钮文本和连接信号
	var current_index = 0
	
	# 获取lianli_system以获取tower_highest_floor
	var lianli_sys = get_node_or_null("/root/GameManager").get_lianli_system() if get_node_or_null("/root/GameManager") else null
	var tower_floor = 1
	if lianli_sys:
		tower_floor = lianli_sys.tower_highest_floor + 1
	
	# 显示普通区域
	for area_id in normal_area_ids:
		if current_index < lianli_area_buttons.size():
			var button = lianli_area_buttons[current_index]
			var area_name = lianli_area_data.get_area_name(area_id) if lianli_area_data else area_id
			button.text = area_name
			button.visible = true
			button.disabled = false
			# 断开之前的连接（避免重复连接）
			var connections = button.get_signal_connection_list("pressed")
			for conn in connections:
				button.pressed.disconnect(conn.callable)
			# 使用LianliModule处理
			if lianli_module:
				button.pressed.connect(lianli_module.on_lianli_area_pressed.bind(area_id))
			current_index += 1

	# 显示无尽塔
	for area_id in tower_area_ids:
		if current_index < lianli_area_buttons.size():
			var button = lianli_area_buttons[current_index]
			var area_name = ""
			if area_id == "endless_tower":
				area_name = "无尽塔 (第%d层)" % tower_floor
			else:
				area_name = lianli_area_data.get_area_name(area_id) if lianli_area_data else area_id
			
			button.text = area_name
			button.visible = true
			button.disabled = false
			var connections = button.get_signal_connection_list("pressed")
			for conn in connections:
				button.pressed.disconnect(conn.callable)
			if lianli_module:
				if area_id == "endless_tower":
					button.pressed.connect(lianli_module.on_endless_tower_pressed)
				else:
					button.pressed.connect(lianli_module.on_lianli_area_pressed.bind(area_id))
			current_index += 1

	# 显示每日副本
	for area_id in daily_area_ids:
		if current_index < lianli_area_buttons.size():
			var button = lianli_area_buttons[current_index]
			var area_name = lianli_area_data.get_area_name(area_id) if lianli_area_data else area_id
			# 使用缓存数据，不立即调用API
			_update_dungeon_button_text(button, area_id, area_name)
			button.visible = true
			button.disabled = false
			# 断开之前的连接（避免重复连接）
			var connections = button.get_signal_connection_list("pressed")
			for conn in connections:
				button.pressed.disconnect(conn.callable)
			# 使用LianliModule处理
			if lianli_module:
				button.pressed.connect(lianli_module.on_lianli_area_pressed.bind(area_id))
			current_index += 1
	
	# 隐藏剩余的按钮
	for i in range(current_index, lianli_area_buttons.size()):
		lianli_area_buttons[i].visible = false

# 副本信息缓存
var dungeon_info_cache: Dictionary = {}

# 更新副本按钮文本（只使用缓存数据）
func _update_dungeon_button_text(button: Button, dungeon_id: String, area_name: String):
	# 只显示缓存的信息或默认值
	var cached_info = dungeon_info_cache.get(dungeon_id, {"remaining_count": 3, "max_count": 3})
	var remaining = int(cached_info.get("remaining_count", 3))
	var max_count = int(cached_info.get("max_count", 3))
	button.text = area_name + " (剩余: " + str(remaining) + "/" + str(max_count) + ")"

func _refresh_lianli_info_from_server():
	if not api:
		return

	var cave_result = await api.lianli_foundation_herb_cave()
	if cave_result.get("success", false):
		dungeon_info_cache["foundation_herb_cave"] = {
			"remaining_count": int(cave_result.get("remaining_count", 0)),
			"max_count": int(cave_result.get("max_count", 3))
		}

	var tower_result = await api.lianli_tower()
	if tower_result.get("success", false):
		if lianli_system:
			lianli_system.tower_highest_floor = int(tower_result.get("highest_floor", lianli_system.tower_highest_floor))
		if lianli_module and lianli_module.lianli_system:
			lianli_module.lianli_system.tower_highest_floor = int(tower_result.get("highest_floor", lianli_module.lianli_system.tower_highest_floor))

	update_lianli_area_buttons_display()
	if endless_tower_button and lianli_module:
		lianli_module.update_endless_tower_button_text(endless_tower_button)

func set_background_server_refresh_enabled(enabled: bool) -> void:
	allow_background_server_refresh = enabled

func begin_test_shutdown() -> void:
	_test_shutdown_requested = true
	allow_background_server_refresh = false

func has_pending_test_tasks() -> bool:
	var alchemy_pending := false
	if alchemy_module and is_instance_valid(alchemy_module):
		alchemy_pending = bool(alchemy_module.has_pending_test_tasks())
	return _pending_refresh_all_player_data_count > 0 or alchemy_pending

func await_pending_test_tasks(max_frames: int = 120) -> void:
	var remaining_frames = max_frames
	while remaining_frames > 0 and has_pending_test_tasks():
		remaining_frames -= 1
		await get_tree().process_frame

# 更新历练区域按钮显示（用于刷新每日次数等）
func update_lianli_area_buttons_display():
	if not lianli_area_data or not player:
		return

	var normal_area_ids = lianli_area_data.get_normal_area_ids()
	var daily_area_ids = lianli_area_data.get_daily_area_ids()
	var tower_area_ids = ["endless_tower"]

	var current_index = 0

	for area_id in normal_area_ids:
		if current_index < lianli_area_buttons.size():
			var button = lianli_area_buttons[current_index]
			var area_name = lianli_area_data.get_area_name(area_id)
			button.text = area_name
			button.disabled = false
			current_index += 1

	var lianli_system = get_node_or_null("/root/GameManager").get_lianli_system() if get_node_or_null("/root/GameManager") else null
	var tower_floor = 1
	if lianli_system:
		tower_floor = lianli_system.tower_highest_floor + 1
	for area_id in tower_area_ids:
		if current_index < lianli_area_buttons.size():
			var button = lianli_area_buttons[current_index]
			var area_name = "无尽塔 (第" + str(tower_floor) + "层)"
			button.text = area_name
			button.disabled = false
			current_index += 1

	for area_id in daily_area_ids:
		if current_index < lianli_area_buttons.size():
			var button = lianli_area_buttons[current_index]
			var area_name = lianli_area_data.get_area_name(area_id)
			_update_dungeon_button_text(button, area_id, area_name)
			button.disabled = false
			current_index += 1

# ==================== 无尽塔功能 ====================

# 初始化无尽塔按钮
func _init_endless_tower_button():
	if endless_tower_button and lianli_module:
		endless_tower_button.pressed.connect(lianli_module.on_endless_tower_pressed)
		lianli_module.update_endless_tower_button_text(endless_tower_button)

func _on_craft_count_changed(count: int):
	if alchemy_module:
		alchemy_module.set_craft_count(count)

# 炼制数量Max
func _on_craft_count_max():
	if alchemy_module:
		var max_count = alchemy_module.get_max_craft_count()
		max_count = maxi(max_count, 1)  # 至少设置1个
		alchemy_module.set_craft_count(max_count)

func update_ui():
	if not player:
		return
	
	var status = player.get_status_dict()
	
	# 根据境界和层数显示不同的文本（使用RealmSystem查表）
	var game_manager = get_node_or_null("/root/GameManager")
	var realm_system = game_manager.get_realm_system() if game_manager else null
	var level_name = ""
	if realm_system:
		level_name = realm_system.get_level_name(status.realm, status.realm_level)
	else:
		# 备用逻辑：如果无法获取realm_system，使用默认格式
		if status.realm_level == 10:
			level_name = "大圆满"
		else:
			level_name = "第" + str(status.realm_level) + "层"
	realm_label.text = status.realm + " " + level_name
	
	# 更新境界背景图片
	update_realm_background(status.realm)
	
	var stone_count = 0
	if inventory:
		stone_count = inventory.get_item_count("spirit_stone")
	spirit_stone_label.text = "灵石: " + UIUtils.format_number(stone_count)
	
	# 更新修炼面板显示（通过CultivationModule）
	if cultivation_module:
		cultivation_module.update_display(status)

func update_realm_background(realm_name: String):
	if not top_bar_background:
		return

	var texture_path = REALM_FRAME_TEXTURES.get(realm_name, REALM_FRAME_TEXTURES["筑基期"])
	var texture = load(texture_path)
	if texture:
		top_bar_background.texture = texture

# 修炼按钮处理已迁移到 CultivationModule

## 刷新储纳UI
func refresh_inventory_ui():
	if chuna_module:
		chuna_module.update_inventory_ui()

# 突破按钮处理已迁移到 CultivationModule

func _on_account_logged_in(account_info: Dictionary):
	update_account_ui()

func update_account_ui():
	var game_manager = get_node("/root/GameManager")
	if not game_manager:
		return
	
	# 从GameManager中获取账号信息
	var account_info = game_manager.get_account_info()
	
	# 更新昵称显示
	var nickname = account_info.get("nickname", "hsams")
	if player_name_label_top:
		player_name_label_top.text = nickname
	
	# 更新头像显示
	var avatar_id = account_info.get("avatar_id", "abstract")
	if avatar_texture:
		const AccountConfig = preload("res://scripts/core/account/AccountConfig.gd")
		var avatar_path = AccountConfig.get_avatar_path(avatar_id)
		var texture = load(avatar_path)
		if texture:
			avatar_texture.texture = texture
		# 头像加载失败不提示

func claim_offline_reward():
	# 主动获取离线奖励
	# 服务端自动计算离线时间
	var game_manager = get_node("/root/GameManager")
	if not game_manager:
		return
	
	if api:
		var result = await api.claim_offline_reward()
		if result.get("success", false):
			var reward = result.get("offline_reward", null)
			if reward != null and reward is Dictionary:
				# 成功且有奖励
				var rewarded_offline_seconds = int(result.get("offline_seconds", 0))
				
				# 计算小时和分钟
				var total_minutes = int(rewarded_offline_seconds / 60)
				var hours = int(total_minutes / 60)
				var minutes = total_minutes % 60
				
				# 应用奖励
				if player:
					# 应用灵气奖励（不超过上限）
					if reward.has("spirit_energy"):
						# 使用add_spirit方法，它会自动处理上限
						player.add_spirit(reward.spirit_energy)
					
					# 应用灵石奖励
					if reward.has("spirit_stones") and inventory:
						inventory.add_item("spirit_stone", reward.spirit_stones)
				
				# 显示离线奖励信息
				if log_manager:
					log_manager.add_system_log("===================================")
					log_manager.add_system_log("离线时长: " + str(hours) + "小时" + str(minutes) + "分钟")
					log_manager.add_system_log("获得离线奖励：")
					if reward.has("spirit_energy"):
						log_manager.add_system_log("  - 灵气: +" + str(int(reward.spirit_energy)))
					if reward.has("spirit_stones"):
						log_manager.add_system_log("  - 灵石: +" + str(int(reward.spirit_stones)))
					log_manager.add_system_log("===================================")
				# 刷新UI
				update_ui()
				refresh_inventory_ui()
			else:
				# 成功但无奖励，不提示
				pass
		else:
			# 获取离线奖励失败
			if log_manager:
				var err_msg = _get_offline_reward_result_message(result, "获取离线奖励失败")
				if err_msg.is_empty():
					log_manager.add_system_log("获取离线奖励失败")
				else:
					log_manager.add_system_log(err_msg)

func _get_offline_reward_result_message(result: Dictionary, fallback: String = "") -> String:
	var reason_code = str(result.get("reason_code", ""))
	match reason_code:
		"GAME_OFFLINE_REWARD_GRANTED":
			return ""
		"GAME_OFFLINE_REWARD_SKIPPED_SHORT_OFFLINE":
			return ""
		_:
			return api.network_manager.get_api_error_text_for_ui(result, fallback)

# 内视子Tab处理已迁移到 NeishiModule
