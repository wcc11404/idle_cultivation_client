# 客户端 GUT API 测试说明

## 测试定位

`tests_gut/` 现在默认采用“真实客户端模块 + 固定测试账号 + 服务端 `/api/test/*` 状态构造”的模式。

- 业务真值来自服务端 API，不再直接拿本地 `scripts/core/*` 旧逻辑当断言依据
- `/api/test/*` 只允许出现在 `tests_gut/support/*`
- 模块测试重点校验客户端状态同步、按钮行为、富文本日志和文案翻译

## 前置条件

运行客户端 GUT 之前，需要先启动本地服务端，并保证：

- API 地址默认是 `http://localhost:8444/api`
- 固定测试账号可用：`test / test123`
- 服务端已经包含 `/api/test/*` 测试支持接口

如果服务端地址不是默认值，可以在运行脚本前覆盖：

```bash
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/godot
export GODOT_TEST_HOME="$(pwd)/.godot_test_home"
```

客户端测试会在每条用例开始前：

1. 清理本地 token 和服务器地址缓存
2. 登录测试账号
3. 调用 `/api/test/reset_account`
4. 视需要调用 `/api/test/apply_preset`
5. 同步真实 `game/data`

## 目录结构

```text
tests_gut/
├── fixtures/
│   └── FixtureHelper.gd        # 通用断言/日志/背包辅助
├── support/
│   ├── ModuleHarness.gd        # 主界面与模块测试基座
│   ├── ServerStateAdapter.gd  # 服务端状态同步辅助
│   ├── ServerClient.gd             # 测试账号与 /api/test/* 调用封装
│   └── SessionHelper.gd            # 本地 token / server_config 清理
├── integration/
│   └── TestModuleApiSmoke.gd # 跨模块 smoke
└── unit/
    └── ui/                      # 模块级 API 集成测试
```

## 运行命令

在客户端项目根目录执行统一入口：

```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/godot ./run_tests.sh
```

这个脚本同时兼容 macOS 和 WSL/Linux：

- macOS：可直接使用 `/Applications/Godot.app/Contents/MacOS/godot`
- WSL/Linux：优先使用 `godot4`，其次使用 `godot`

或直接调用 GUT：

```bash
HOME="$(pwd)/.godot_test_home" \
"/Applications/Godot.app/Contents/MacOS/godot" \
  --headless \
  --path . \
  --script res://addons/gut/gut_cmdln.gd \
  -gdir=res://tests_gut \
  -ginclude_subdirs \
  -gexit
```

兼容入口 `tests_gut/run_gut_tests.sh` 仍保留，但只是转发到统一脚本：

```bash
./tests_gut/run_gut_tests.sh
```

## 当前覆盖范围

- 修炼与突破
- 储纳与物品使用、重复使用、数量不足
- 术法装备互斥、升级/充灵失败、战斗锁定
- 炼丹开炉、红字缺料、停火文案
- 历练进入、返回页定位、结算失败收敛、本地气血拦截
- 设置中的改昵称、排行榜静默加载、登出清理 token
- 跨模块 smoke

## 保留的本地测试

纯工具类和静态数据类测试仍保留，例如：

- `unit/core/TestLogManager.gd`
- `unit/core/TestAttributeCalculator.gd`
- `unit/data/*`

这些测试只用于验证客户端内部工具或静态配置，不承担业务真值判定。
