#!/bin/bash

# GUT 测试运行脚本

echo "========================================"
echo "运行 GUT 测试"
echo "========================================"

cd "$(dirname "$0")/.."

godot --headless --script res://addons/gut/gut_cmdln.gd -gdir=res://tests_gut -ginclude_subdirs -gexit

echo ""
echo "测试完成"
