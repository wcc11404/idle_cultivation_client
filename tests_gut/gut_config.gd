extends Resource

## GUT 配置文件

# 测试目录
var directories = ["res://tests_gut"]
var include_subdirectories = true

# 测试文件后缀
var suffix = ".gd"
var prefix = "test_"

# 输出设置
var log_level = 1  # 0=error, 1=warning, 2=info, 3=debug
var should_print_summary = true
var should_print_orphans = true

# 运行设置
var should_maximize = false
var compact_mode = false
var gut_on_top = true

# 颜色设置
var background_color = Color(0.1, 0.1, 0.1, 1.0)
var font_color = Color(0.9, 0.9, 0.9, 1.0)

# 内部设置
var inner_class_prefix = "Test"
var disable_strict_datatype_checks = false
var export_path = ""
var include_colored_output = true
var double_strategy = 1  # 1=SCRIPT_ONLY, 2=INCLUDE_NATIVE
var pre_run_script = ""
var post_run_script = ""
var print_gut_version = true
