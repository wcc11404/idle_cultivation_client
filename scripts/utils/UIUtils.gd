class_name UIUtils

# UI 工具函数类
# 统一处理数值格式化、单位转换等操作

# ==================== 数值单位转换 ====================

static func format_number_precise(num: float, decimal_places: int = 1) -> String:
	if abs(num) >= 1000000000.0:
		return _format_with_decimal(num / 1000000000.0, decimal_places) + "B"
	elif abs(num) >= 1000000.0:
		return _format_with_decimal(num / 1000000.0, decimal_places) + "M"
	elif abs(num) >= 1000.0:
		return _format_with_decimal(num / 1000.0, decimal_places) + "K"
	return format_decimal(num, 2)

static func format_display_number(num: float) -> String:
	if abs(num) >= 1000.0:
		return format_number_precise(num, 1)
	return format_decimal(num, 2)

static func format_display_number_integer(num: float) -> String:
	if abs(num) >= 1000.0:
		return format_number_precise(num, 0)
	return str(int(round(num)))

# 辅助函数：格式化小数
static func _format_with_decimal(value: float, decimal_places: int) -> String:
	var multiplier = pow(10, decimal_places)
	var rounded = round(value * multiplier) / multiplier
	var int_part = int(rounded)
	var decimal_part = int((rounded - int_part) * multiplier)
	
	if decimal_part == 0:
		return str(int_part)
	else:
		# 去除末尾0
		var decimal_str = str(decimal_part)
		while decimal_str.ends_with("0"):
			decimal_str = decimal_str.substr(0, decimal_str.length() - 1)
		return str(int_part) + "." + decimal_str

# ==================== 小数格式化 ====================

# 去除小数末尾的0
# 如: 1.500 -> "1.5", 2.0 -> "2"
static func trim_trailing_zeros(num: float) -> String:
	var str_num = str(num)
	if str_num.find(".") == -1:
		return str_num
	
	while str_num.ends_with("0"):
		str_num = str_num.substr(0, str_num.length() - 1)
	
	if str_num.ends_with("."):
		str_num = str_num.substr(0, str_num.length() - 1)
	
	return str_num

# 格式化小数（保留指定位数，去除末尾0）
static func format_decimal(value: float, max_decimal_places: int = 2) -> String:
	var multiplier = pow(10, max_decimal_places)
	var rounded = round(value * multiplier) / multiplier
	return trim_trailing_zeros(rounded)
