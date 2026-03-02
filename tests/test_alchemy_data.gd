extends TestBase

const ItemData = preload("res://scripts/core/inventory/ItemData.gd")

# 测试炼丹系统数据配置

func get_test_name() -> String:
	return "AlchemyData"

func run_tests() -> Dictionary:
	var results = {
		"total": 0,
		"passed": 0,
		"failed": 0,
		"tests": []
	}
	
	# 测试1: 丹方道具配置
	results.tests.append_array(_test_recipe_items())
	
	# 测试2: 丹炉道具配置
	results.tests.append(_test_alchemy_furnace())
	
	# 测试3: 炼丹术法配置
	results.tests.append_array(_test_alchemy_spell())
	
	# 测试4: 丹方数据配置
	results.tests.append_array(_test_recipe_data())
	
	# 统计结果
	for test in results.tests:
		results.total += 1
		if test.passed:
			results.passed += 1
		else:
			results.failed += 1
	
	return results

# 测试丹方道具配置
func _test_recipe_items() -> Array:
	var tests = []
	var item_data = ItemData.new()
	
	# 测试补血丹丹方
	var health_recipe = item_data.get_item_data("recipe_health_pill")
	tests.append({
		"name": "补血丹丹方配置",
		"passed": health_recipe.get("id") == "recipe_health_pill" and health_recipe.get("effect", {}).get("type") == "learn_recipe",
		"message": "补血丹丹方配置正确" if health_recipe.get("id") == "recipe_health_pill" else "补血丹丹方配置错误"
	})
	
	# 测试补气丹丹方
	var spirit_recipe = item_data.get_item_data("recipe_spirit_pill")
	tests.append({
		"name": "补气丹丹方配置",
		"passed": spirit_recipe.get("id") == "recipe_spirit_pill",
		"message": "补气丹丹方配置正确" if spirit_recipe.get("id") == "recipe_spirit_pill" else "补气丹丹方配置错误"
	})
	
	# 测试筑基丹丹方
	var foundation_recipe = item_data.get_item_data("recipe_foundation_pill")
	tests.append({
		"name": "筑基丹丹方配置",
		"passed": foundation_recipe.get("id") == "recipe_foundation_pill",
		"message": "筑基丹丹方配置正确" if foundation_recipe.get("id") == "recipe_foundation_pill" else "筑基丹丹方配置错误"
	})
	
	# 测试金丹丹方
	var golden_recipe = item_data.get_item_data("recipe_golden_core_pill")
	tests.append({
		"name": "金丹丹方配置",
		"passed": golden_recipe.get("id") == "recipe_golden_core_pill",
		"message": "金丹丹方配置正确" if golden_recipe.get("id") == "recipe_golden_core_pill" else "金丹丹方配置错误"
	})
	
	return tests

# 测试丹炉道具配置
func _test_alchemy_furnace() -> Dictionary:
	var item_data = ItemData.new()
	var furnace = item_data.get_item_data("alchemy_furnace")
	
	return {
		"name": "丹炉道具配置",
		"passed": furnace.get("id") == "alchemy_furnace" and furnace.get("max_stack") == 1,
		"message": "丹炉道具配置正确" if furnace.get("id") == "alchemy_furnace" else "丹炉道具配置错误"
	}

# 测试炼丹术法配置
func _test_alchemy_spell() -> Array:
	var tests = []
	var spell_data = SpellData.new()
	
	# 测试炼丹术存在
	var alchemy_spell = spell_data.get_spell_data("alchemy")
	tests.append({
		"name": "炼丹术法存在",
		"passed": not alchemy_spell.is_empty(),
		"message": "炼丹术法存在" if not alchemy_spell.is_empty() else "炼丹术法不存在"
	})
	
	if not alchemy_spell.is_empty():
		# 测试类型为杂学术法
		tests.append({
			"name": "炼丹术法类型",
			"passed": alchemy_spell.get("type") == SpellData.SpellType.MISC,
			"message": "炼丹术法为杂学术法" if alchemy_spell.get("type") == SpellData.SpellType.MISC else "炼丹术法类型错误"
		})
		
		# 测试等级配置
		tests.append({
			"name": "炼丹术法等级数",
			"passed": alchemy_spell.get("max_level") == 3,
			"message": "炼丹术法有3个等级" if alchemy_spell.get("max_level") == 3 else "炼丹术法等级数错误"
		})
		
		# 测试1级效果
		var level1 = spell_data.get_spell_level_data("alchemy", 1)
		tests.append({
			"name": "炼丹术1级效果",
			"passed": level1.get("effect", {}).get("success_bonus") == 10,
			"message": "炼丹术1级成功值+10" if level1.get("effect", {}).get("success_bonus") == 10 else "炼丹术1级效果错误"
		})
		
		# 测试3级效果
		var level3 = spell_data.get_spell_level_data("alchemy", 3)
		tests.append({
			"name": "炼丹术3级效果",
			"passed": level3.get("effect", {}).get("success_bonus") == 30,
			"message": "炼丹术3级成功值+30" if level3.get("effect", {}).get("success_bonus") == 30 else "炼丹术3级效果错误"
		})
	
	return tests

# 测试丹方数据配置
func _test_recipe_data() -> Array:
	var tests = []
	var recipe_data = AlchemyRecipeData.new()
	
	# 测试丹方数量
	var recipe_ids = recipe_data.get_all_recipe_ids()
	tests.append({
		"name": "丹方数量",
		"passed": recipe_ids.size() == 4,
		"message": "有4个丹方" if recipe_ids.size() == 4 else "丹方数量错误: " + str(recipe_ids.size())
	})
	
	# 测试补血丹配置
	var health_recipe = recipe_data.get_recipe_data("health_pill")
	tests.append({
		"name": "补血丹配置",
		"passed": health_recipe.get("success_value") == 20 and health_recipe.get("base_time") == 5.0,
		"message": "补血丹配置正确" if health_recipe.get("success_value") == 20 else "补血丹配置错误"
	})
	
	# 测试筑基丹材料
	var foundation_recipe = recipe_data.get_recipe_data("foundation_pill")
	var materials = recipe_data.get_recipe_materials("foundation_pill")
	tests.append({
		"name": "筑基丹材料",
		"passed": materials.get("foundation_herb") == 3 and materials.get("mat_herb") == 10,
		"message": "筑基丹材料配置正确" if materials.get("foundation_herb") == 3 else "筑基丹材料配置错误"
	})
	
	# 测试金丹丹材料（包含筑基丹作为材料）
	var golden_materials = recipe_data.get_recipe_materials("golden_core_pill")
	tests.append({
		"name": "金丹丹材料",
		"passed": golden_materials.get("foundation_pill") == 3,
		"message": "金丹丹需要筑基丹作为材料" if golden_materials.get("foundation_pill") == 3 else "金丹丹材料配置错误"
	})
	
	return tests
