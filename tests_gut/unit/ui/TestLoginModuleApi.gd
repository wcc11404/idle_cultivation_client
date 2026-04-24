extends GutTest

const LOGIN_SCENE = preload("res://scenes/app/Login.tscn")
const TEST_SESSION_HELPER_SCRIPT = preload("res://tests_gut/support/SessionHelper.gd")
const SERVER_CONFIG_SCRIPT = preload("res://scripts/network/ServerConfig.gd")

var login_ui: Control = null

func before_each():
	TEST_SESSION_HELPER_SCRIPT.reset_local_session("http://localhost:8444/api")
	login_ui = LOGIN_SCENE.instantiate()
	add_child(login_ui)
	await get_tree().process_frame
	await get_tree().process_frame

func after_each():
	if login_ui and is_instance_valid(login_ui):
		if login_ui.get_parent() == self:
			remove_child(login_ui)
		login_ui.free()
		login_ui = null
	TEST_SESSION_HELPER_SCRIPT.reset_local_session("http://localhost:8444/api")
	await get_tree().process_frame

func _random_username(prefix: String = "gut_user_") -> String:
	return prefix + str(Time.get_ticks_usec())

func test_login_unregistered_username_uses_reason_code_copy():
	login_ui.username_input.text = _random_username("not_found_")
	login_ui.password_input.text = "abc123!@#"

	await login_ui._on_login_pressed()

	assert_eq(login_ui.message_label.text, "用户名未注册", "未注册账号应映射为固定客户端文案")

func test_login_wrong_password_uses_reason_code_copy():
	login_ui.username_input.text = "test"
	login_ui.password_input.text = "wrong_password_123"

	await login_ui._on_login_pressed()

	assert_eq(login_ui.message_label.text, "密码错误", "密码错误应映射为固定客户端文案")

func test_register_existing_username_uses_reason_code_copy():
	login_ui.username_input.text = "test"
	login_ui.password_input.text = "abc123!@#"

	await login_ui._on_register_pressed()

	assert_eq(login_ui.message_label.text, "用户名已存在", "已存在用户名应映射为固定客户端文案")

func test_refresh_invalid_token_prompts_relogin_and_clears_token():
	var file = FileAccess.open(SERVER_CONFIG_SCRIPT.TOKEN_FILE, FileAccess.WRITE)
	assert_not_null(file, "应能写入测试 token 文件")
	file.store_string("invalid_token_for_refresh")
	file.close()
	assert_true(login_ui.api.network_manager.load_token(), "应能加载伪造 token")

	await login_ui.check_auto_login()

	assert_eq(login_ui.message_label.text, "请重新登录", "refresh 失败应提示重新登录")
	assert_false(FileAccess.file_exists(SERVER_CONFIG_SCRIPT.TOKEN_FILE), "refresh 失败后应清理本地 token")

func test_apply_game_data_keeps_current_health_when_spell_bonus_increases_max_health():
	var game_manager = get_node_or_null("/root/GameManager")
	assert_not_null(game_manager, "测试环境应存在 GameManager")

	var player = game_manager.get_player()
	var spell_system = game_manager.get_spell_system()
	assert_not_null(player, "GameManager 应提供玩家对象")
	assert_not_null(spell_system, "GameManager 应提供术法系统")

	spell_system.apply_save_data({
		"player_spells": {},
		"equipped_spells": {}
	})
	player.apply_save_data({
		"realm": "炼气期",
		"realm_level": 1,
		"health": 50.0,
		"spirit_energy": 0.0,
		"is_cultivating": false
	})

	login_ui._apply_game_data({
		"player": {
			"realm": "炼气期",
			"realm_level": 1,
			"health": 51.0,
			"spirit_energy": 0.0,
			"is_cultivating": false
		},
		"spell_system": {
			"player_spells": {
				"basic_health": {
					"obtained": true,
					"level": 1,
					"use_count": 0,
					"charged_spirit": 0
				}
			},
			"equipped_spells": {
				"active": [],
				"opening": [],
				"breathing": []
			}
		}
	})

	assert_eq(player.get_final_max_health(), 51.0, "基础气血加成后静态气血上限应为 51")
	assert_eq(player.health, 51.0, "登录应用数据后当前气血不应被旧上限错误夹回 50")
