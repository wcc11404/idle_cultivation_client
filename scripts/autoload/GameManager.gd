extends Node

signal offline_reward_received(rewards: Dictionary)
signal account_logged_in(account_info: Dictionary)

# 静态变量，防止重复初始化
static var _systems_initialized: bool = false

var player: Node = null
var cultivation_system: Node = null
var lianli_system: Node = null
var realm_system: Node = null
var save_manager: Node = null
var offline_reward: Node = null
var inventory: Node = null
var item_data: Node = null
var lianli_area_data: Node = null
var enemy_data: Node = null
var spell_data: Node = null
var account_system: Node = null
var spell_system: Node = null
var endless_tower_data: Node = null
var alchemy_system: Node = null
var recipe_data: Node = null


var current_user_save_path: String = ""

func _ready():
	# 防止重复初始化（在编辑器中脚本重新加载时）
	if _systems_initialized:
		return
	
	init_systems()
	_systems_initialized = true
	# 先初始化账号系统
	login_default_account()
	create_player()
	give_starter_pack_item()
	give_test_pack_item()
	print("游戏初始化完成")
	print("=== GameManager._ready() 结束 ===")

func init_systems():
	
	# 初始化账号系统
	account_system = load("res://scripts/core/AccountSystem.gd").new()
	account_system.name = "AccountSystem"
	add_child(account_system)
	account_system.login_success.connect(_on_account_login_success)
	print("账号系统初始化完成")
	
	item_data = load("res://scripts/core/inventory/ItemData.gd").new()
	item_data.name = "ItemData"
	add_child(item_data)
	print("物品数据初始化完成")
	
	lianli_area_data = load("res://scripts/core/lianli/LianliAreaData.gd").new()
	lianli_area_data.name = "LianliAreaData"
	add_child(lianli_area_data)
	print("历练区域数据初始化完成")
	
	enemy_data = load("res://scripts/core/lianli/EnemyData.gd").new()
	enemy_data.name = "EnemyData"
	add_child(enemy_data)
	print("敌人数据初始化完成")
	
	realm_system = load("res://scripts/core/realm/RealmSystem.gd").new()
	realm_system.name = "RealmSystem"
	add_child(realm_system)
	print("境界系统初始化完成")
	
	inventory = load("res://scripts/core/inventory/Inventory.gd").new()
	inventory.name = "Inventory"
	add_child(inventory)
	print("储纳系统初始化完成")
	
	cultivation_system = load("res://scripts/core/realm/CultivationSystem.gd").new()
	cultivation_system.name = "CultivationSystem"
	add_child(cultivation_system)
	print("修炼系统初始化完成")
	
	endless_tower_data = load("res://scripts/core/lianli/EndlessTowerData.gd").new()
	endless_tower_data.name = "EndlessTowerData"
	add_child(endless_tower_data)
	print("无尽塔数据初始化完成")
	
	lianli_system = load("res://scripts/core/lianli/LianliSystem.gd").new()
	lianli_system.name = "LianliSystem"
	add_child(lianli_system)
	lianli_system.set_lianli_area_data(lianli_area_data)
	lianli_system.set_enemy_data(enemy_data)
	lianli_system.set_endless_tower_data(endless_tower_data)
	print("历练系统初始化完成")
	
	save_manager = load("res://scripts/core/SaveManager.gd").new()
	save_manager.name = "SaveManager"
	add_child(save_manager)
	print("存档系统初始化完成")
	
	offline_reward = load("res://scripts/core/OfflineReward.gd").new()
	offline_reward.name = "OfflineReward"
	add_child(offline_reward)
	print("离线收益系统初始化完成")
	
	spell_data = load("res://scripts/core/SpellData.gd").new()
	spell_data.name = "SpellData"
	add_child(spell_data)
	print("术法数据初始化完成")
	
	spell_system = load("res://scripts/core/SpellSystem.gd").new()
	spell_system.name = "SpellSystem"
	add_child(spell_system)
	spell_system.set_spell_data(spell_data)
	spell_system.set_lianli_system(lianli_system)
	print("术法系统初始化完成")
	
	# 初始化炼丹系统
	recipe_data = load("res://scripts/core/AlchemyRecipeData.gd").new()
	recipe_data.name = "AlchemyRecipeData"
	add_child(recipe_data)
	print("丹方数据初始化完成")
	
	alchemy_system = load("res://scripts/core/AlchemySystem.gd").new()
	alchemy_system.name = "AlchemySystem"
	add_child(alchemy_system)
	alchemy_system.set_recipe_data(recipe_data)
	alchemy_system.set_inventory(inventory)
	alchemy_system.set_spell_system(spell_system)
	print("炼丹系统初始化完成")

func login_default_account():
	# 使用默认账号登录
	if account_system:
		account_system.login(account_system.DEFAULT_USERNAME, account_system.DEFAULT_PASSWORD)

func _on_account_login_success(username: String):
	# 更新存档路径
	update_save_path(username)
	account_logged_in.emit(account_system.get_current_account())
	print("账号登录成功: ", username)

func update_save_path(username: String):
	# 每个用户有独立的存档文件
	current_user_save_path = "user://save_" + username + ".json"
	if save_manager:
		save_manager.set_save_path(current_user_save_path)

func give_starter_pack_item():
	inventory.add_item("starter_pack", 1)
	print("新手礼包已发放到储纳")

func give_test_pack_item():
	inventory.add_item("test_pack", 1)
	print("测试礼包已发放到储纳")

func create_player():
	player = load("res://scripts/core/PlayerData.gd").new()
	player.name = "Player"
	add_child(player)
	
	cultivation_system.set_player(player)
	lianli_system.set_player(player)
	spell_system.set_player(player)
	alchemy_system.set_player(player)
	
	print("玩家创建完成，境界：", player.realm)

func get_player():
	return player

func get_cultivation_system():
	return cultivation_system

func get_lianli_system():
	return lianli_system

func get_realm_system():
	return realm_system

func get_save_manager():
	return save_manager

func get_offline_reward():
	return offline_reward

func get_inventory():
	return inventory

func get_item_data():
	return item_data

func get_spell_data():
	return spell_data

func get_spell_system():
	return spell_system

func get_lianli_area_data():
	return lianli_area_data

func get_enemy_data():
	return enemy_data

func get_endless_tower_data():
	return endless_tower_data

func get_alchemy_system():
	return alchemy_system

func get_recipe_data():
	return recipe_data

func get_account_system():
	return account_system

func get_current_account_info() -> Dictionary:
	if account_system:
		return account_system.get_current_account()
	return {}

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# 关闭游戏时不自动保存
		pass

func save_game():
	if save_manager:
		save_manager.save_game()
		print("游戏已保存")
	else:
		push_error("save_game: save_manager 为 null!")

func load_game():
	if save_manager:
		var success = save_manager.load_game()
		if success:
			apply_loaded_data()
			print("游戏已加载")
		return success
	return false

func apply_loaded_data():
	if player and save_manager.current_save_data.has("player"):
		var player_data = save_manager.current_save_data["player"]
		player.apply_save_data(player_data)
	
	# 计算并显示离线奖励
	if player and offline_reward:
		# 从存档的 timestamp 获取上次保存时间
		var last_save_time = save_manager.current_save_data.get("timestamp", 0)
		var rewards = offline_reward.calculate_offline_reward(player, last_save_time)
		
		if rewards:
			var offline_hours = rewards.get("offline_hours", 0)
			
			if offline_hours > 0:
				# 发送信号通知UI
				offline_reward_received.emit(rewards)
				
				# 应用奖励
				offline_reward.apply_offline_reward(player, rewards)
