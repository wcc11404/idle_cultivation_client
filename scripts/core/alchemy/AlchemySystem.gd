class_name AlchemySystem extends Node

# 炼丹系统核心

# 信号
signal recipe_learned(recipe_id: String)
signal crafting_started(recipe_id: String, count: int)
signal crafting_progress(current: int, total: int, progress: float)
signal single_craft_completed(success: bool, recipe_name: String)
signal crafting_finished(recipe_id: String, success_count: int, fail_count: int)
signal crafting_stopped(completed_count: int, remaining_count: int)
signal log_message(message: String)

# 丹炉配置（硬编码，支持多丹炉扩展）
const FURNACE_CONFIGS = {
	"alchemy_furnace": {
		"name": "初级丹炉",
		"success_bonus": 10,
		"speed_rate": 0.1
	}
}

# 引用
var player: Node = null
var recipe_data: Node = null
var spell_system: Node = null
var inventory: Node = null

# 炼丹状态
var is_crafting: bool = false
var current_craft_recipe: String = ""
var current_craft_count: int = 0
var current_craft_index: int = 0
var craft_timer: float = 0.0
var craft_success_count: int = 0
var craft_fail_count: int = 0
var craft_time_per_pill: float = 0.0
var current_material_consumed: bool = false

# 装备的丹炉ID（空字符串表示无丹炉）
var equipped_furnace_id: String = ""

# 已学会的丹方ID列表
var learned_recipes: Array = []

# 特殊速度加成（测试用，默认0）
var special_bonus_speed_rate: float = 0.0

func _ready():
	pass

func _process(delta):
	if not is_crafting:
		return
	
	craft_timer += delta
	
	var progress = (craft_timer / craft_time_per_pill) * 100.0
	progress = min(progress, 100.0)
	crafting_progress.emit(current_craft_index + 1, current_craft_count, progress)
	
	if craft_timer >= craft_time_per_pill:
		craft_timer = 0.0
		_complete_single_pill()

func set_player(player_node: Node):
	player = player_node

func set_recipe_data(recipe_data_node: Node):
	recipe_data = recipe_data_node

func set_spell_system(spell_sys: Node):
	spell_system = spell_sys

func set_inventory(inv: Node):
	inventory = inv

# 学习丹方（使用丹方道具时调用）
func learn_recipe(recipe_id: String) -> bool:
	if not recipe_data or recipe_data.get_recipe_data(recipe_id).is_empty():
		return false
	
	if recipe_id in learned_recipes:
		return false
	
	learned_recipes.append(recipe_id)
	recipe_learned.emit(recipe_id)
	return true

# 检查是否学会丹方
func has_learned_recipe(recipe_id: String) -> bool:
	return recipe_id in learned_recipes

# 获取已学会的丹方列表
func get_learned_recipes() -> Array:
	return learned_recipes.duplicate()

# 检查是否拥有丹炉
func has_furnace() -> bool:
	return equipped_furnace_id != "" and FURNACE_CONFIGS.has(equipped_furnace_id)

# 装备丹炉
func equip_furnace(furnace_id: String) -> bool:
	if not FURNACE_CONFIGS.has(furnace_id):
		return false
	equipped_furnace_id = furnace_id
	return true

# 获取当前装备的丹炉ID
func get_equipped_furnace_id() -> String:
	return equipped_furnace_id

# 获取丹炉配置
func get_furnace_config(furnace_id: String) -> Dictionary:
	return FURNACE_CONFIGS.get(furnace_id, {})

# 获取炼丹术加成
func get_alchemy_bonus() -> Dictionary:
	var bonus = {
		"success_bonus": 0,
		"speed_rate": 0.0,
		"level": 0,
		"obtained": false
	}
	
	if not spell_system:
		return bonus
	
	var spell_info = spell_system.get_spell_info("alchemy")
	if spell_info.is_empty() or not spell_info.obtained:
		return bonus
	
	bonus.obtained = true
	var level = spell_info.level
	bonus.level = level
	
	if level > 0:
		var level_data = spell_system.spell_data.get_spell_level_data("alchemy", level)
		var effect = level_data.get("effect", {})
		bonus.success_bonus = effect.get("success_bonus", 0)
		bonus.speed_rate = effect.get("speed_rate", 0.0)
	
	return bonus

# 获取丹炉加成
func get_furnace_bonus() -> Dictionary:
	var bonus = {
		"success_bonus": 0,
		"speed_rate": 0.0,
		"has_furnace": false,
		"furnace_name": ""
	}
	
	if not has_furnace():
		return bonus
	
	var config = FURNACE_CONFIGS.get(equipped_furnace_id, {})
	bonus.has_furnace = true
	bonus.success_bonus = config.get("success_bonus", 0)
	bonus.speed_rate = config.get("speed_rate", 0.0)
	bonus.furnace_name = config.get("name", "未知丹炉")
	
	return bonus

# 计算成功率（百分比）
func calculate_success_rate(recipe_id: String) -> int:
	if not recipe_data:
		return 0
	
	var base_value = recipe_data.get_recipe_success_value(recipe_id)
	var alchemy_bonus = get_alchemy_bonus()
	var furnace_bonus = get_furnace_bonus()
	
	var final_value = base_value + alchemy_bonus.success_bonus + furnace_bonus.success_bonus
	
	return clamp(final_value, 1, 100)

# 计算炼制耗时（秒/颗）
func calculate_craft_time(recipe_id: String) -> float:
	if not recipe_data:
		return 0.0
	
	var base_time = recipe_data.get_recipe_base_time(recipe_id)
	var alchemy_bonus = get_alchemy_bonus()
	var furnace_bonus = get_furnace_bonus()
	
	var final_speed = 1.0 + alchemy_bonus.speed_rate + furnace_bonus.speed_rate + special_bonus_speed_rate
	
	return base_time / final_speed

# 检查材料是否足够
func check_materials(recipe_id: String, count: int) -> Dictionary:
	var result = {
		"enough": false,
		"materials": {},
		"missing": []
	}
	
	if not recipe_data or not inventory:
		return result
	
	var materials = recipe_data.get_recipe_materials(recipe_id)
	
	for material_id in materials.keys():
		var material_count = materials[material_id]
		var required = material_count * count
		var has = inventory.get_item_count(material_id)
		result.materials[material_id] = {
			"required": required,
			"has": has,
			"enough": has >= required
		}
		
		if has < required:
			result.missing.append(material_id)
	
	result.enough = result.missing.is_empty()
	return result

# 检查灵气是否足够
func check_spirit_energy(recipe_id: String, count: int) -> Dictionary:
	var result = {
		"enough": true,
		"required": 0,
		"has": 0
	}
	
	if not player or not recipe_data:
		return result
	
	var spirit_per_pill = recipe_data.get_recipe_spirit_energy(recipe_id)
	result.required = spirit_per_pill * count
	result.has = int(player.spirit_energy)
	result.enough = result.has >= result.required
	
	return result

# 检查单颗材料是否足够
func _check_single_craft_materials() -> bool:
	if not recipe_data or not inventory:
		return false
	
	var materials = recipe_data.get_recipe_materials(current_craft_recipe)
	for material_id in materials.keys():
		var required = materials[material_id]
		var has = inventory.get_item_count(material_id)
		if has < required:
			return false
	
	var spirit_required = recipe_data.get_recipe_spirit_energy(current_craft_recipe)
	if spirit_required > 0 and player:
		if player.spirit_energy < spirit_required:
			return false
	
	return true

# 扣除单颗材料
func _consume_single_craft_materials():
	if not recipe_data or not inventory:
		return
	
	var materials = recipe_data.get_recipe_materials(current_craft_recipe)
	for material_id in materials.keys():
		var required = materials[material_id]
		inventory.remove_item(material_id, required)
	
	var spirit_required = recipe_data.get_recipe_spirit_energy(current_craft_recipe)
	if spirit_required > 0 and player:
		player.consume_spirit(spirit_required)

# 开始批量炼制
func start_crafting_batch(recipe_id: String, count: int) -> Dictionary:
	var result = {
		"success": false,
		"reason": "",
		"recipe_id": recipe_id,
		"count": count
	}
	
	if not has_learned_recipe(recipe_id):
		result.reason = "未学会该丹方"
		return result
	
	if is_crafting:
		result.reason = "正在炼制中"
		return result
	
	var material_check = check_materials(recipe_id, count)
	if not material_check.enough:
		result.reason = "材料不足"
		return result
	
	var spirit_check = check_spirit_energy(recipe_id, count)
	if not spirit_check.enough:
		result.reason = "灵气不足"
		return result
	
	is_crafting = true
	current_craft_recipe = recipe_id
	current_craft_count = count
	current_craft_index = 0
	craft_timer = 0.0
	craft_success_count = 0
	craft_fail_count = 0
	craft_time_per_pill = calculate_craft_time(recipe_id)
	current_material_consumed = false
	
	if not _check_single_craft_materials():
		log_message.emit("材料不足，无法开始炼制")
		_reset_crafting_state()
		result.reason = "材料不足"
		return result
	
	_consume_single_craft_materials()
	current_material_consumed = true
	
	crafting_started.emit(recipe_id, count)
	log_message.emit("开炉炼丹，开始炼制 [" + recipe_data.get_recipe_name(recipe_id) + "]")
	
	result.success = true
	return result

# 完成单颗炼制
func _complete_single_pill():
	if not is_crafting:
		return
	
	current_craft_index += 1
	current_material_consumed = false
	
	var success_rate = calculate_success_rate(current_craft_recipe)
	var roll = randf() * 100.0
	var recipe_name = recipe_data.get_recipe_name(current_craft_recipe)
	
	if spell_system:
		spell_system.add_spell_use_count("alchemy")
	
	if roll <= success_rate:
		craft_success_count += 1
		var product = recipe_data.get_recipe_product(current_craft_recipe)
		var product_count = recipe_data.get_recipe_product_count(current_craft_recipe)
		inventory.add_item(product, product_count)
		log_message.emit("丹香四溢，[" + recipe_name + "]炼制成功")
		single_craft_completed.emit(true, recipe_name)
	else:
		craft_fail_count += 1
		_return_half_materials(1)
		log_message.emit("火候失控，[" + recipe_name + "]炼制失败，药渣可回收部分材料")
		single_craft_completed.emit(false, recipe_name)
	
	if current_craft_index >= current_craft_count:
		_finish_crafting()
		return
	
	if not _check_single_craft_materials():
		log_message.emit("灵材耗尽，炼丹中断")
		_finish_crafting()
		return
	
	_consume_single_craft_materials()
	current_material_consumed = true

# 返还一半材料（失败时）
func _return_half_materials(fail_count: int):
	if not recipe_data or not inventory:
		return
	
	var materials = recipe_data.get_recipe_materials(current_craft_recipe)
	for material_id in materials.keys():
		var return_amount = int(materials[material_id] * fail_count / 2.0)
		if return_amount > 0:
			inventory.add_item(material_id, return_amount)

# 停止炼制
func stop_crafting() -> Dictionary:
	var result = {
		"success": false,
		"reason": "",
		"completed_count": 0,
		"remaining_count": 0
	}
	
	if not is_crafting:
		result.reason = "未在炼制中"
		return result
	
	var remaining_count = max(current_craft_count - current_craft_index, 0)
	var completed_count = current_craft_index
	
	if current_material_consumed and recipe_data and inventory:
		var materials = recipe_data.get_recipe_materials(current_craft_recipe)
		for material_id in materials.keys():
			var return_amount = materials[material_id]
			if return_amount > 0:
				inventory.add_item(material_id, return_amount)
		
		var spirit_required = recipe_data.get_recipe_spirit_energy(current_craft_recipe)
		if spirit_required > 0 and player:
			player.add_spirit(spirit_required)
	
	log_message.emit("收丹停火，返还材料，成功%d枚，废丹%d枚" % [craft_success_count, craft_fail_count])
	
	_reset_crafting_state()
	
	result.success = true
	result.completed_count = completed_count
	result.remaining_count = remaining_count
	crafting_stopped.emit(completed_count, remaining_count)
	
	return result

# 完成炼制
func _finish_crafting():
	var recipe_id = current_craft_recipe
	var success_count = craft_success_count
	var fail_count = craft_fail_count
	
	_reset_crafting_state()
	
	crafting_finished.emit(recipe_id, success_count, fail_count)
	
	var recipe_name = recipe_data.get_recipe_name(recipe_id) if recipe_data else "丹药"
	if success_count > 0 or fail_count > 0:
		log_message.emit("此次炼丹结束，成丹%d枚，废丹%d枚" % [success_count, fail_count])

# 重置炼制状态
func _reset_crafting_state():
	is_crafting = false
	current_craft_recipe = ""
	current_craft_count = 0
	current_craft_index = 0
	craft_timer = 0.0
	craft_success_count = 0
	craft_fail_count = 0
	craft_time_per_pill = 0.0
	current_material_consumed = false

# 获取炼制预览信息
func get_craft_preview(recipe_id: String, count: int) -> Dictionary:
	var preview = {
		"recipe_id": recipe_id,
		"recipe_name": "",
		"count": count,
		"success_rate": 0,
		"craft_time": 0.0,
		"total_time": 0.0,
		"materials": {},
		"spirit_energy": {},
		"alchemy_bonus": {},
		"furnace_bonus": {},
		"can_craft": false,
		"reason": ""
	}
	
	if not recipe_data:
		preview.reason = "丹方数据未初始化"
		return preview
	
	if not has_learned_recipe(recipe_id):
		preview.reason = "未学会该丹方"
		return preview
	
	preview.recipe_name = recipe_data.get_recipe_name(recipe_id)
	preview.success_rate = calculate_success_rate(recipe_id)
	preview.craft_time = calculate_craft_time(recipe_id)
	preview.total_time = preview.craft_time * count
	var materials_check = check_materials(recipe_id, count)
	preview.materials = materials_check.materials
	preview.spirit_energy = check_spirit_energy(recipe_id, count)
	preview.alchemy_bonus = get_alchemy_bonus()
	preview.furnace_bonus = get_furnace_bonus()
	preview.can_craft = materials_check.enough and preview.spirit_energy.enough
	
	if not preview.can_craft:
		if not materials_check.enough:
			preview.reason = "材料不足"
		else:
			preview.reason = "灵气不足"
	
	return preview

# 获取所有可炼制的丹方（已学会且材料足够）
func get_craftable_recipes() -> Array:
	var craftable = []
	
	if not player or not recipe_data:
		return craftable
	
	for recipe_id in learned_recipes:
		var preview = get_craft_preview(recipe_id, 1)
		if preview.can_craft:
			craftable.append(recipe_id)
	
	return craftable

# 获取当前炼制状态
func get_crafting_state() -> Dictionary:
	return {
		"is_crafting": is_crafting,
		"recipe_id": current_craft_recipe,
		"current_index": current_craft_index,
		"total_count": current_craft_count,
		"success_count": craft_success_count,
		"fail_count": craft_fail_count,
		"progress": (craft_timer / craft_time_per_pill) * 100.0 if craft_time_per_pill > 0 else 0.0
	}

# 存档数据
func get_save_data() -> Dictionary:
	return {
		"equipped_furnace_id": equipped_furnace_id,
		"learned_recipes": learned_recipes.duplicate()
	}

# 加载存档数据
func apply_save_data(data: Dictionary):
	equipped_furnace_id = data.get("equipped_furnace_id", "")
	learned_recipes = data.get("learned_recipes", [])
