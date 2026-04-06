class_name AlchemyRecipeData extends Node

var recipes: Dictionary = {}

func _ready():
	_load_config()

func _load_config():
	var file = FileAccess.open("res://scripts/core/alchemy/recipes.json", FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		var data = JSON.parse_string(json_text)
		if data:
			var raw_recipes = data.get("recipes", {})
			recipes = _normalize_recipes(raw_recipes)

func _normalize_recipes(raw_recipes: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	for recipe_id in raw_recipes.keys():
		if not (raw_recipes[recipe_id] is Dictionary):
			continue
		var recipe = raw_recipes[recipe_id].duplicate(true)
		recipe["success_value"] = int(recipe.get("success_value", 0))
		recipe["base_time"] = float(recipe.get("base_time", 0.0))
		recipe["spirit_energy"] = int(recipe.get("spirit_energy", 0))
		recipe["product_count"] = int(recipe.get("product_count", 1))
		if recipe.has("materials") and recipe["materials"] is Dictionary:
			var mats = recipe["materials"]
			for item_id in mats.keys():
				mats[item_id] = int(mats[item_id])
		normalized[str(recipe_id)] = recipe
	return normalized

func get_recipe_data(recipe_id: String) -> Dictionary:
	return recipes.get(recipe_id, {})

func get_all_recipe_ids() -> Array:
	return recipes.keys()

func get_recipe_name(recipe_id: String) -> String:
	var recipe = get_recipe_data(recipe_id)
	return recipe.get("name", "未知丹方")

func get_recipe_success_value(recipe_id: String) -> int:
	var recipe = get_recipe_data(recipe_id)
	return recipe.get("success_value", 0)

func get_recipe_base_time(recipe_id: String) -> float:
	var recipe = get_recipe_data(recipe_id)
	return recipe.get("base_time", 0.0)

func get_recipe_materials(recipe_id: String) -> Dictionary:
	var recipe = get_recipe_data(recipe_id)
	return recipe.get("materials", {}).duplicate(true)

func get_recipe_product(recipe_id: String) -> String:
	var recipe = get_recipe_data(recipe_id)
	return recipe.get("product", "")

func get_recipe_product_count(recipe_id: String) -> int:
	var recipe = get_recipe_data(recipe_id)
	return recipe.get("product_count", 1)

func get_recipe_spirit_energy(recipe_id: String) -> int:
	var recipe = get_recipe_data(recipe_id)
	return recipe.get("spirit_energy", 0)

func recipe_exists(recipe_id: String) -> bool:
	return recipes.has(recipe_id)
