#!/bin/bash

# 运行GUT测试的脚本

# Godot可执行文件路径
GODOT_EXEC="../../Godot_v4.6-stable_linux.x86_64"

# 项目路径
PROJECT_PATH="."

# GUT脚本路径
GUT_SCRIPT="addons/gut/gut_cmdln.gd"

# 测试目录
TEST_DIR="res://tests_gut/integration"

echo "========================================"
echo "运行 GUT 集成测试"
echo "========================================"

# 运行测试
"$GODOT_EXEC" --headless --path "$PROJECT_PATH" --script "$GUT_SCRIPT" -gdir="$TEST_DIR" -gexit

echo ""
echo "测试完成"
