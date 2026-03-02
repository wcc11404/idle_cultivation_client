# Godot Headless 模式日志文件权限问题解决方案

## 问题描述
在运行 Godot 引擎的 headless 模式时，遇到以下错误：

```
ERROR: Failed to open 'user://logs/godot2026-02-17T14.54.29.log'.
   at: copy (core/io/dir_access.cpp:423)

================================================================
handle_crash: Program crashed with signal 11
Engine version: Godot Engine v4.6.stable.official (89cea143987d564363e15d207438530651d943ac)
Dumping the backtrace. Please include this when reporting the bug on: https://github.com/godotengine/godot/issues
[1] 1   libsystem_platform.dylib            0x00000001816b3e24 _sigtramp + 56
[2] RotatedFileLogger::rotate_file() (in Godot) + 1160
[3] RotatedFileLogger::rotate_file() (in Godot) + 1160
[4] RotatedFileLogger::RotatedFileLogger(String const&, int) (in Godot) + 80
[5] Main::setup(char const*, int, char**, bool) (in Godot) + 18868
[6] OS_MacOS_Headless::run() (in Godot) + 68
[7] main (in Godot) + 924
[8] 8   dyld                                0x00000001812fc274 start + 2840
-- END OF C++ BACKTRACE --
================================================================
```

## 问题原因
Godot 引擎在启动时尝试在默认的用户数据目录中创建和写入日志文件，但在当前环境中没有足够的权限，导致崩溃。

## 解决方案
通过设置 `HOME` 环境变量到当前项目目录，改变 Godot 的用户数据目录位置，这样 Godot 会在当前目录中创建用户数据目录和日志文件，而不是在系统的用户数据目录中。

## 实现方法

### 1. 创建启动脚本
创建一个名为 `run_headless.sh` 的脚本文件：

```bash
#!/bin/bash

# 运行 Godot headless 模式的脚本
# 通过设置 HOME 目录到当前目录，解决日志文件权限问题

export HOME="$(pwd)"
echo "Setting HOME to: $HOME"

# 创建必要的目录
mkdir -p user_data/logs

# 运行 Godot headless 模式
godot --path "$(pwd)" --headless --quit
```

### 2. 赋予执行权限
```bash
chmod +x run_headless.sh
```

### 3. 运行脚本
```bash
bash run_headless.sh
```

## 验证结果
测试脚本成功运行，输出显示：

```
Setting HOME to: /Users/hsams/Documents/trae_projects/idle_cultivation
Godot Engine v4.6.stable.official.89cea1439 - https://godotengine.org

User data dir:/Users/hsams/Documents/trae_projects/idle_cultivation/Library/Application Support/Godot/app_userdata/idle_cultivation
Executable path:/Applications/Godot.app/Contents/MacOS/Godot
Test file created successfully
Script finished
物品数据初始化完成
战斗区域数据初始化完成
敌人数据初始化完成
境界系统初始化完成
储纳系统初始化完成
修炼系统初始化完成
战斗系统初始化完成
存档系统初始化完成
任务系统初始化完成
离线收益系统初始化完成
玩家创建完成，境界：炼气期
新手礼包已发放到储纳
游戏初始化完成
```

## 优势
- **不需要修改 Godot 引擎代码**：只需要通过环境变量设置即可解决问题
- **不需要修改项目代码**：适用于各种 Godot 项目
- **权限可控**：可以在任何有写入权限的目录中运行
- **简单易用**：只需要创建一个启动脚本即可

## 使用场景
- 运行 Godot 的 headless 模式进行服务器端处理
- 自动化测试
- CI/CD 流程中的构建和测试
- 任何需要在没有图形界面的环境中运行 Godot 的场景

## 注意事项
- 此解决方案适用于 macOS 系统，其他系统可能需要适当调整
- 运行脚本后，Godot 会在当前目录创建 `Library/Application Support/Godot/app_userdata/` 目录结构
- 日志文件会保存在 `Library/Application Support/Godot/app_userdata/idle_cultivation/logs/` 目录中
