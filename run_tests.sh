#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}"

if [[ -n "${GODOT_BIN:-}" ]]; then
  GODOT_EXEC="${GODOT_BIN}"
elif command -v godot4 >/dev/null 2>&1; then
  GODOT_EXEC="$(command -v godot4)"
elif command -v godot >/dev/null 2>&1; then
  GODOT_EXEC="$(command -v godot)"
elif [[ -x "/Applications/Godot.app/Contents/MacOS/godot" ]]; then
  GODOT_EXEC="/Applications/Godot.app/Contents/MacOS/godot"
else
  echo "未找到 Godot 可执行文件，请设置 GODOT_BIN，或把 godot/godot4 加入 PATH。"
  exit 1
fi

TEST_HOME="${GODOT_TEST_HOME:-${PROJECT_DIR}/.godot_test_home}"
mkdir -p "${TEST_HOME}"

echo "========================================"
echo "运行客户端测试"
echo "项目目录: ${PROJECT_DIR}"
echo "Godot: ${GODOT_EXEC}"
echo "HOME: ${TEST_HOME}"
echo "========================================"

HOME="${TEST_HOME}" "${GODOT_EXEC}" \
  --headless \
  --path "${PROJECT_DIR}" \
  --script res://addons/gut/gut_cmdln.gd \
  -gdir=res://tests_gut \
  -gprefix=Test \
  -ginclude_subdirs \
  -gexit \
  "$@"
