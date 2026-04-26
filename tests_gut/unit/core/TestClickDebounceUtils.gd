extends GutTest

const CLICK_DEBOUNCE_UTILS := preload("res://scripts/utils/ClickDebounceUtils.gd")


func before_each():
	CLICK_DEBOUNCE_UTILS.reset_all()


func test_should_accept_first_click():
	var accepted := CLICK_DEBOUNCE_UTILS.should_accept("k1", 200, 1000)
	assert_true(accepted, "首次点击应放行")


func test_should_reject_within_cooldown():
	assert_true(CLICK_DEBOUNCE_UTILS.should_accept("k1", 200, 1000), "首次点击应放行")
	var accepted := CLICK_DEBOUNCE_UTILS.should_accept("k1", 200, 1150)
	assert_false(accepted, "0.2秒内连点应拦截")


func test_should_accept_after_cooldown():
	assert_true(CLICK_DEBOUNCE_UTILS.should_accept("k1", 200, 1000), "首次点击应放行")
	var accepted := CLICK_DEBOUNCE_UTILS.should_accept("k1", 200, 1200)
	assert_true(accepted, "超过0.2秒应放行")


func test_should_isolate_by_action_key():
	assert_true(CLICK_DEBOUNCE_UTILS.should_accept("k1", 200, 1000), "k1首次放行")
	var accepted := CLICK_DEBOUNCE_UTILS.should_accept("k2", 200, 1010)
	assert_true(accepted, "不同key不应互相影响")


func test_reset_action():
	assert_true(CLICK_DEBOUNCE_UTILS.should_accept("k1", 200, 1000), "首次点击应放行")
	assert_false(CLICK_DEBOUNCE_UTILS.should_accept("k1", 200, 1150), "0.2秒内连点应拦截")
	CLICK_DEBOUNCE_UTILS.reset_action("k1")
	assert_true(CLICK_DEBOUNCE_UTILS.should_accept("k1", 200, 1151), "reset后应立即放行")
