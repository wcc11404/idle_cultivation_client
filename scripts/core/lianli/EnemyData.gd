class_name EnemyData extends Node

var ENEMY_TEMPLATES: Dictionary = {}

func _ready():
	_load_config()

func _load_config():
	var file = FileAccess.open("res://scripts/core/lianli/enemies.json", FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		var data = JSON.parse_string(json_text)
		if data:
			ENEMY_TEMPLATES = data.get("templates", {})

func generate_enemy(template_id: String, level: int) -> Dictionary:
	var template = ENEMY_TEMPLATES.get(template_id, {})
	if template.is_empty():
		return {}
	
	var growth = template.get("growth", {})
	
	var health = int(growth.get("health_base", 20) * pow(growth.get("health_growth", 1.08), level - 1))
	var attack = int(growth.get("attack_base", 4) * pow(growth.get("attack_growth", 1.06), level - 1))
	var defense = int(growth.get("defense_base", 2) * pow(growth.get("defense_growth", 1.04), level - 1))
	var speed = growth.get("speed_base", 5) * (1 + growth.get("speed_growth", 0.01) * (level - 1))
	
	var name_variants = template.get("name_variants", [template.get("name", "敌人")])
	var enemy_name = template.get("name", "敌人")
	if name_variants.size() > 0:
		enemy_name = name_variants[randi() % name_variants.size()]
	
	return {
		"template_id": template_id,
		"name": enemy_name,
		"level": level,
		"is_elite": template.get("is_elite", false),
		"stats": {
			"health": health,
			"attack": attack,
			"defense": defense,
			"speed": speed
		}
	}

func get_template_name(template_id: String) -> String:
	var template = ENEMY_TEMPLATES.get(template_id, {})
	return template.get("name", "未知敌人")

func is_elite_template(template_id: String) -> bool:
	var template = ENEMY_TEMPLATES.get(template_id, {})
	return template.get("is_elite", false)

func get_all_template_ids() -> Array:
	return ENEMY_TEMPLATES.keys()
