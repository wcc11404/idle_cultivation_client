# 弱联网系统设计方案

## 1. 概述

本文档描述将单机修仙游戏改造为弱联网游戏的技术方案。

### 核心原则
- **纯云端存档**：本地不存储任何游戏进度
- **单设备登录**：同一时间只允许一个设备在线
- **弱网友好**：断网可继续非关键操作，关键操作需联网验证；定时保存连续失败3次自动登出
- **简化设计**：不引入不必要的复杂度（无Redis、无实时对战）

### 项目结构

采用**前后端分离**的架构，客户端和服务端分为两个独立项目：

```
idle_cultivation/                    # 客户端（Godot）
├── project.godot
├── scripts/
│   ├── network/               # 网络相关（新增）
│   │   ├── NetworkManager.gd
│   │   └── GameServerAPI.gd
│   └── ...
└── docs/OnlineSystem.md       # 本文件

idle_cultivation_server/             # 服务端（Python + FastAPI）
├── requirements.txt
├── main.py
├── app/
│   ├── __init__.py
│   ├── main.py
│   ├── api/
│   │   ├── __init__.py
│   │   ├── auth.py
│   │   └── game.py
│   ├── core/
│   │   ├── __init__.py
│   │   ├── config.py
│   │   └── security.py
│   ├── db/
│   │   ├── __init__.py
│   │   ├── database.py
│   │   └── models.py
│   └── schemas/
│       ├── __init__.py
│       └── player.py
├── sql/init.sql
└── README.md
```

**分离理由：**
- 技术栈分离，Godot 和 Python 互不干扰
- AI 开发时代码上下文更清晰
- 可以独立部署和扩展
- 符合行业惯例
- Python 语法简洁，开发效率高

---

## 2. 技术栈

| 组件 | 选择 | 理由 |
|------|------|------|
| 服务端 | Python + FastAPI | 语法简洁、开发效率高、异步性能优秀、AI生成代码质量好 |
| 数据库 | PostgreSQL | 关系型数据、免费稳定、支持JSONB、Mac支持良好 |
| ORM | Tortoise-ORM | 异步支持、类似Django ORM、类型友好 |
| 缓存 | 无 | 不需要Redis，简化架构 |
| 通信协议 | HTTP/REST | 简单可靠、弱网友好 |
| 认证方式 | JWT Token | 无状态、支持Token续期 |

### 性能说明

对于挂机游戏场景，Python + FastAPI 完全满足需求：
- 实际 QPS 需求：~33（1000在线用户，5分钟同步一次）
- FastAPI 处理能力：~6000 QPS（数据库查询）
- 性能差距（vs Node.js）：约25%，但对弱联网场景无感知

### 2.3 开发环境搭建

#### Mac 环境

```bash
# 安装Homebrew（如果还没有）
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 安装PostgreSQL
brew install postgresql
brew services start postgresql

# 安装Python（3.11+）
brew install python@3.11

# 创建虚拟环境
cd idle_cultivation_server
python3.11 -m venv venv
source venv/bin/activate

# 安装依赖
pip install -r requirements.txt

# 创建数据库
createdb idle_cultivation_game
```

#### Windows 环境

```powershell
# 1. 安装 Python 3.11+
# 下载地址: https://www.python.org/downloads/
# 安装时勾选 "Add Python to PATH"

# 2. 安装 PostgreSQL
# 下载地址: https://www.postgresql.org/download/windows/
# 安装时记住设置的密码（默认用户是 postgres）

# 3. 配置 PostgreSQL 环境变量（可选）
# 将 PostgreSQL 的 bin 目录添加到 PATH
# 例如: C:\Program Files\PostgreSQL\16\bin

# 4. 创建数据库
# 方式一：使用 pgAdmin 图形界面
# 方式二：使用命令行
psql -U postgres
# 输入密码后执行：
CREATE DATABASE idle_cultivation_game;

# 5. 创建服务端项目目录
mkdir idle_cultivation_server
cd idle_cultivation_server

# 6. 创建 Python 虚拟环境
python -m venv venv
venv\Scripts\activate

# 7. 安装依赖
pip install -r requirements.txt
```

---

## 3. 数据库设计

### 3.1 表结构

```sql
-- 账号表
CREATE TABLE accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 登录方式一：用户名+密码（初期实现）
    username VARCHAR(20) UNIQUE NOT NULL,     -- 必填
    password_hash VARCHAR(255) NOT NULL,      -- 必填
    
    -- 登录方式二：手机号+验证码（后续扩展）
    phone VARCHAR(11) UNIQUE,                 -- 可为空
    
    -- 登录方式三：第三方登录（后续扩展）
    auth_data JSONB,                          -- TapTap 等第三方登录信息
    
    -- 通用字段
    server_id VARCHAR(20) DEFAULT 'default',  -- 区服ID
    token_version INT DEFAULT 0,              -- 单设备登录控制，每次登录+1
    is_banned BOOLEAN DEFAULT FALSE,          -- 封号标记
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- 玩家数据表
CREATE TABLE player_data (
    account_id UUID PRIMARY KEY REFERENCES accounts(id),
    server_id VARCHAR(20) DEFAULT 'default',  -- 冗余存储，便于分区查询
    game_version VARCHAR(20) DEFAULT 'v1.0.0', -- 游戏版本号，记录玩家上次保存的版本
    data JSONB NOT NULL,                      -- 所有游戏数据（详见下文结构）
    last_online_at TIMESTAMP DEFAULT NOW(),   -- 用于离线收益计算
    updated_at TIMESTAMP DEFAULT NOW()
);

-- 索引
CREATE INDEX idx_accounts_username ON accounts(username);
CREATE UNIQUE INDEX idx_accounts_phone ON accounts(phone) WHERE phone IS NOT NULL;
CREATE INDEX idx_accounts_server ON accounts(server_id);
CREATE INDEX idx_player_data_updated ON player_data(updated_at);
CREATE INDEX idx_player_data_server ON player_data(server_id);
CREATE INDEX idx_player_data_version ON player_data(game_version);
```

**字段说明**：

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 主键，PostgreSQL `gen_random_uuid()` 自动生成 |
| `username` | VARCHAR(20) | 登录用户名（必填，初期唯一登录方式） |
| `password_hash` | VARCHAR(255) | 密码哈希（bcrypt 加密，必填） |
| `phone` | VARCHAR(11) | 手机号（后续扩展：手机号+验证码登录） |
| `auth_data` | JSONB | 第三方登录信息（后续扩展：TapTap 登录） |
| `server_id` | VARCHAR(20) | 区服ID，默认 `default` |
| `game_version` | VARCHAR(20) | 游戏版本号，方便大版本更新时数据迁移 |

**登录方式规划**：

| 登录方式 | 状态 | 说明 |
|----------|------|------|
| 用户名+密码 | ✅ 初期实现 | 必填字段 |
| 手机号+验证码 | 🔜 后续扩展 | 需接入短信服务 |
| TapTap 登录 | 🔜 后续扩展 | 需接入 TapSDK |

**后期扩展**：玩家数量增长后，可使用 PostgreSQL 分区表按 `server_id` 分区，无需修改代码。

### 3.2 player_data.data JSONB结构

基于实际代码的存档数据结构：

```json
{
    "player": {
        "realm": "炼气期",
        "realm_level": 1,
        "health": 500.0,
        "spirit_energy": 0.0,
        "nickname": "修仙者",
        "avatar_id": "default_1",
        "title_id": ""
    },
    "inventory": {
        "capacity": 50,
        "slots": {
            "0": {"id": "spirit_stone", "count": 100},
            "5": {"id": "mat_herb", "count": 50}
        }
    },
    "spell_system": {
        "player_spells": {},
        "equipped_spells": {
            "tuna": null,
            "active": [],
            "passive": []
        }
    },
    "alchemy_system": {
        "equipped_furnace_id": "",
        "learned_recipes": ["health_pill"]
    },
    "lianli_system": {
        "tower_highest_floor": 0,
        "daily_dungeon_data": {}
    },
    "timestamp": 1234567890
}
```

**字段说明：**
- `player`: 玩家基础属性
  - `realm`, `realm_level`: 境界相关（决定属性最大值）
  - `health`: 当前生命值（动态值，非最大值）
  - `spirit_energy`: 当前灵气值（动态值，非最大值）
  - `nickname`: 昵称（游戏内显示名称，可修改）
  - `avatar_id`: 头像ID（对应客户端素材，如 `default_1`, `cultivator_1`）
  - `title_id`: 称号ID（如 `first_breakthrough`, `tower_master`）
- `inventory`: 储纳系统（容量、稀疏存储的物品槽位）
- `spell_system`: 术法系统（已获得术法、装备配置）
- `alchemy_system`: 炼丹系统（装备的丹炉、已学丹方）
- `lianli_system`: 历练系统（无尽塔最高层、每日副本数据）
- `timestamp`: 存档时间戳

### 3.3 扩展性说明

JSONB结构支持灵活扩展：

```sql
-- 新增字段直接操作JSON
UPDATE player_data 
SET data = jsonb_set(data, '{new_field}', '"新值"');

-- 新增嵌套对象
UPDATE player_data 
SET data = jsonb_set(data, '{new_system}', '{}');

-- 为常用查询字段创建索引
CREATE INDEX idx_player_realm ON player_data ((data->'player'->>'realm'));
```

---

## 4. 核心机制详解

### 4.1 注册登录流程

#### 注册
```
POST /api/auth/register
Request:
{
    "username": "玩家名",
    "password": "密码"
}

Response:
{
    "success": true,
    "account_id": "uuid",
    "message": "注册成功"
}

# 错误响应
{
    "success": false,
    "error_code": 400,
    "message": "用户名已存在"
}
```

**验证规则：**
- 用户名：4-20位，字母数字下划线
- 密码：6-20位，至少包含字母和数字
- 用户名唯一
- **昵称**：3-10个字符，中文算一个字符

**注册时服务端处理：**
1. 验证用户名和密码格式
2. 检查用户名是否已存在
3. 加密密码
4. 创建账号记录
5. 自动创建初始游戏数据
   - 默认境界：炼气期 1 级
   - 初始背包：基础药品
   - **随机生成昵称**：从预设昵称库中随机选择
   - **随机选择头像**：从预设头像ID中随机选择
6. 返回账号ID

#### 登录
```
POST /api/auth/login
Request:
{
    "username": "玩家名",
    "password": "密码"
}

Response:
{
    "success": true,
    "token": "jwt_token",
    "expires_in": 604800,  // 7天
    "account_info": {
        "id": "uuid",
        "username": "玩家名",
        "server_id": "default"
    },
    "data": { /* 完整游戏数据 */ },
    "offline_reward": {    // 离线收益
        "spirit_energy": 100,
        "spirit_stones": 50
    },
    "offline_seconds": 3600
}

# 错误响应
{
    "success": false,
    "error_code": 401,
    "message": "用户名或密码错误"
}
```

**登录时服务端处理：**
1. 验证用户名密码
2. 检查账号是否被封禁
3. token_version + 1
4. 生成新JWT Token（包含account_id和version）
5. 计算离线收益（基于last_online_at）
6. 更新last_online_at
7. 返回账号信息和游戏数据

#### Token续期
```
POST /api/auth/refresh
Headers: Authorization: Bearer {old_token}

Response:
{
    "success": true,
    "token": "new_jwt_token",
    "expires_in": 604800
}

# 错误响应
{
    "success": false,
    "error_code": 403,
    "message": "Token无效或已过期"
}
```

**续期条件：**
- 旧Token未过期或刚过期不久（7天内）
- token_version匹配（未被其他设备登录）

---

### 4.2 单设备登录控制

#### 原理
使用token_version实现：

```javascript
// JWT Token结构
{
    "account_id": "uuid",
    "version": 5,        // 对应accounts.token_version
    "iat": 1234567890,
    "exp": 1235172690
}
```

#### 流程
```
A设备登录 → token_version=5 → Token_A(version=5)

B设备登录 → token_version=6 → Token_B(version=6)
                         → A设备的Token_A失效

A设备请求 → 验证Token_A.version(5) ≠ DB.version(6)
        → 返回401 KICKED_OUT
        → 客户端强制返回登录界面
```

#### 客户端处理
```gdscript
# 收到401 KICKED_OUT
func on_auth_failed(error_code):
    if error_code == "KICKED_OUT":
        clear_local_token()
        show_message("账号在其他设备登录")
        change_scene("res://scenes/login/Login.tscn")
```

---

### 4.3 存档机制

#### 纯云端存档
- **本地不存储任何游戏进度**
- 所有数据实时保存在PostgreSQL

#### 自动保存触发点
1. **定时保存**：每5分钟自动保存一次
2. **关键操作后保存**：
   - 突破境界（小境界/大境界）
   - 使用重要道具（突破丹、礼包等）
   - 炼丹成功
   - 战斗胜利（历练/无尽塔）
   - 学习术法/丹方
   - 购买重要物品
3. **退出时保存**：游戏退出前尝试保存一次

#### 保存接口
```
POST /api/game/save
Headers: Authorization: Bearer {token}
Request:
{
    "data": { /* 完整游戏数据 */ }
}

Response:
{
    "success": true,
    "last_online_at": 1234567890
}
```

**服务端处理：**
```sql
UPDATE player_data 
SET data = $1, 
    updated_at = NOW(),
    last_online_at = NOW()
WHERE account_id = $2
```

#### 加载流程
```
启动游戏
  ↓
检查本地Token
  ↓
有Token → 调用/api/auth/refresh续期
       → 成功：拉取数据进入游戏
       → 失败：显示登录界面
  ↓
无Token → 显示登录界面
  ↓
登录成功 → 服务端返回完整数据 → 进入游戏
```

---

### 4.4 离线收益计算

#### 计算时机
仅在**登录时**计算一次

#### 计算公式
```javascript
离线时长 = min(当前时间 - last_online_at, 4小时)

离线收益 = {
    spirit_energy: 离线时长 * 每秒灵气获取速度,
    spirit_stones: 离线时长 * 每小时灵石收益 / 3600
}
```

#### 服务端实现
```javascript
async function calculateOfflineReward(account_id) {
    const player = await db.query(
        'SELECT data, last_online_at FROM player_data WHERE account_id = $1',
        [account_id]
    );
    
    const offlineSeconds = Math.min(
        (Date.now() - player.last_online_at) / 1000,
        4 * 3600  // 最大4小时
    );
    
    // 根据玩家境界计算收益速度
    const realm = player.data.player.realm;
    const speed = getRealmCultivationSpeed(realm);
    
    return {
        spirit_energy: Math.floor(offlineSeconds * speed),
        spirit_stones: Math.floor(offlineSeconds * 10 / 3600)
    };
}
```

#### 客户端显示
登录后弹出离线收益界面：
```
欢迎回来！
离线时长：2小时30分钟
获得灵气：+900
获得灵石：+25
```

---

### 4.5 网络容错处理

#### 设计原则
- **关键操作**：同步验证，服务端确认后才执行
- **定时保存**：静默重试，不阻塞用户
- **用户体验**：快速响应时不弹窗，慢速时才提示

#### 关键操作处理流程

```
请求开始
    │
    ├─ 0.5秒内返回 ──→ 成功：执行操作 / 失败：提示原因（无弹窗）
    │
    └─ 0.5秒未返回 ──→ 显示弹窗"网络环境不佳，正在等待..."
           │
           ├─ 5秒内返回 ──→ 关闭弹窗，执行结果
           │
           └─ 5秒超时 ──→ 关闭弹窗，提示"操作失败，请检查网络"
```

#### NetworkManager 实现

```gdscript
# NetworkManager.gd
extends Node

const QUICK_THRESHOLD = 0.5   # 0.5秒内不显示弹窗
const REQUEST_TIMEOUT = 5.0   # 5秒超时

var loading_popup: AcceptDialog = null
var is_requesting: bool = false

func execute_critical_operation(api_path: String, body: Dictionary, on_success: Callable) -> void:
    if is_requesting:
        show_toast("请等待当前操作完成")
        return
    
    is_requesting = true
    
    var http = HTTPRequest.new()
    http.timeout = REQUEST_TIMEOUT
    add_child(http)
    
    var headers = ["Content-Type: application/json"]
    if current_token:
        headers.append("Authorization: Bearer " + current_token)
    
    http.request(API_BASE + api_path, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
    
    # 0.5秒后检查是否需要显示弹窗
    await get_tree().create_timer(QUICK_THRESHOLD).timeout
    var still_waiting = is_requesting
    
    if still_waiting:
        _show_loading_popup()
    
    var response = await http.request_completed
    http.queue_free()
    
    _hide_loading_popup()
    is_requesting = false
    
    var result = _parse_response(response)
    
    if result.success:
        on_success.call(result.data)
    else:
        show_error(result.message)

func _show_loading_popup():
    if not loading_popup:
        loading_popup = AcceptDialog.new()
        loading_popup.dialog_text = "网络环境不佳，正在等待..."
        loading_popup.get_ok_button().disabled = true
        add_child(loading_popup)
    loading_popup.popup_centered()

func _hide_loading_popup():
    if loading_popup and loading_popup.visible:
        loading_popup.hide()
```

#### 各系统调用示例

```gdscript
# RealmSystem.gd - 突破境界
func request_breakthrough(player: Node, inventory: Node):
    var body = {
        "current_realm": player.realm,
        "current_level": player.realm_level,
        "spirit_energy": player.spirit_energy
    }
    
    NetworkManager.execute_critical_operation(
        "/realm/breakthrough",
        body,
        func(data): _apply_breakthrough(player, data)
    )

func _apply_breakthrough(player: Node, data: Dictionary):
    player.realm = data.new_realm
    player.realm_level = data.new_level
    player.spirit_energy = data.remaining_spirit_energy
    player.apply_realm_stats()
    show_success("突破成功！")
```

```gdscript
# Inventory.gd - 使用重要道具
func use_important_item(item_id: String, count: int = 1):
    var body = {
        "item_id": item_id,
        "count": count
    }
    
    NetworkManager.execute_critical_operation(
        "/inventory/use_item",
        body,
        func(data): _apply_item_use(item_id, count, data)
    )

func _apply_item_use(item_id: String, count: int, data: Dictionary):
    _local_remove_item(item_id, count)
    _apply_item_effect(item_id, data.effect)
    show_success("使用成功")
```

#### 定时保存处理

定时保存不需要严格验证，失败静默重试，但连续失败3次则自动登出：

```gdscript
# CloudSaveManager.gd
const MAX_SAVE_FAILURES = 3

var save_failure_count: int = 0
var last_save_time: int = 0

func auto_save():
    var result = await NetworkManager.save_game(collect_game_data())
    
    if result.success:
        last_save_time = Time.get_unix_time_from_system()
        save_failure_count = 0  # 成功后重置计数
    else:
        save_failure_count += 1
        push_warning("自动保存失败 (%d/%d)" % [save_failure_count, MAX_SAVE_FAILURES])
        
        if save_failure_count >= MAX_SAVE_FAILURES:
            _force_logout()

func _force_logout():
    show_error("网络连接异常，请重新登录")
    NetworkManager.clear_token()
    get_tree().change_scene_to_file("res://scenes/login/Login.tscn")
```

#### 用户体验总结

| 场景 | 表现 |
|------|------|
| 网络良好（<0.5秒） | 无弹窗，直接执行 |
| 网络一般（0.5-5秒） | 显示弹窗，等待后执行 |
| 网络差（>5秒） | 显示弹窗，超时后提示失败 |

#### 被踢出处理
```gdscript
func on_request_error(response_code, error_code):
    if response_code == 401 and error_code == "KICKED_OUT":
        clear_local_token()
        show_message("账号在其他设备登录，请重新登录")
        change_scene("res://scenes/login/Login.tscn")
```

---

## 5. 服务端API列表

### 5.1 账号相关

| 接口 | 方法 | 描述 |
|------|------|------|
| /api/auth/register | POST | 注册账号 |
| /api/auth/login | POST | 登录，返回Token和游戏数据 |
| /api/auth/refresh | POST | Token续期 |
| /api/auth/logout | POST | 登出（可选） |

### 5.2 游戏数据

| 接口 | 方法 | 描述 | 认证 |
|------|------|------|------|
| /api/game/data | GET | 拉取存档 | 需要 |
| /api/game/save | POST | 保存存档 | 需要 |

### 5.3 管理后台

| 接口 | 方法 | 描述 | 权限 |
|------|------|------|------|
| /api/admin/login | POST | 管理员登录 | - |
| /api/admin/players | GET | 玩家列表 | 管理员 |
| /api/admin/player/:id | GET | 玩家详情 | 管理员 |
| /api/admin/player/:id/ban | POST | 封号 | 管理员 |

---

## 6. 客户端架构

### 6.1 新增文件结构

```
scripts/
├── network/
│   ├── NetworkManager.gd       # HTTP请求管理、Token管理
│   └── GameServerAPI.gd        # API封装
├── managers/
│   └── CloudSaveManager.gd     # 云端存档管理（替代SaveManager）
└── autoload/
    └── GameManager.gd          # 改造：添加网络初始化

scenes/
├── login/
│   ├── Login.tscn              # 登录界面
│   ├── Register.tscn           # 注册界面
│   └── LoginModule.gd          # 登录逻辑
└── main/
    └── Main.tscn               # 主游戏场景（已有）
```

### 6.2 NetworkManager.gd 核心功能

```gdscript
extends Node

const API_BASE = "http://localhost:8444/api"
const TOKEN_FILE = "user://auth_token.dat"

var current_token: String = ""

func _ready():
    # 启动时加载本地Token
    load_token()

func save_token(token: String):
    current_token = token
    var file = FileAccess.open(TOKEN_FILE, FileAccess.WRITE)
    file.store_string(token)
    file.close()

func load_token() -> bool:
    if FileAccess.file_exists(TOKEN_FILE):
        var file = FileAccess.open(TOKEN_FILE, FileAccess.READ)
        current_token = file.get_as_text()
        return true
    return false

func clear_token():
    current_token = ""
    if FileAccess.file_exists(TOKEN_FILE):
        DirAccess.remove_absolute(TOKEN_FILE)

func request(method: String, endpoint: String, body: Dictionary = {}) -> Dictionary:
    var http = HTTPRequest.new()
    add_child(http)
    
    var url = API_BASE + endpoint
    var headers = ["Content-Type: application/json"]
    
    if current_token:
        headers.append("Authorization: Bearer " + current_token)
    
    var body_json = JSON.stringify(body) if body else ""
    
    http.request(url, headers, method, body_json)
    
    var result = await http.request_completed
    http.queue_free()
    
    # 处理结果...
    return parse_response(result)
```

### 6.3 CloudSaveManager.gd 核心功能

```gdscript
extends Node

const AUTO_SAVE_INTERVAL = 300  # 5分钟

var last_save_time: int = 0

func _ready():
    start_auto_save()

func start_auto_save():
    while true:
        await get_tree().create_timer(AUTO_SAVE_INTERVAL).timeout
        await save_game()

func save_game() -> bool:
    var data = collect_game_data()
    var result = await GameServerAPI.save_game(data)
    
    if result.success:
        last_save_time = Time.get_unix_time_from_system()
        return true
    else:
        push_error("存档失败: " + result.error)
        return false

func collect_game_data() -> Dictionary:
    return {
        "player": PlayerData.get_save_data(),
        "inventory": Inventory.get_save_data(),
        "spell_system": SpellSystem.get_save_data(),
        "timestamp": Time.get_unix_time_from_system()
    }

func apply_game_data(data: Dictionary):
    PlayerData.load_save_data(data.player)
    Inventory.load_save_data(data.inventory)
    SpellSystem.load_save_data(data.spell_system)
```

### 6.4 登录流程

```gdscript
# LoginModule.gd

func on_login_button_pressed():
    var username = username_input.text
    var password = password_input.text
    
    var result = await GameServerAPI.login(username, password)
    
    if result.success:
        NetworkManager.save_token(result.token)
        CloudSaveManager.apply_game_data(result.data)
        
        # 显示离线收益
        if result.offline_seconds > 60:
            show_offline_reward(result.offline_reward, result.offline_seconds)
        
        # 进入游戏
        get_tree().change_scene_to_file("res://scenes/main/Main.tscn")
    else:
        show_error(result.error)

func on_auto_login():
    if not NetworkManager.load_token():
        show_login_form()
        return
    
    var result = await GameServerAPI.refresh_token()
    
    if result.success:
        NetworkManager.save_token(result.new_token)
        var data = await GameServerAPI.load_game_data()
        CloudSaveManager.apply_game_data(data)
        get_tree().change_scene_to_file("res://scenes/main/Main.tscn")
    else:
        # Token无效，显示登录界面
        NetworkManager.clear_token()
        show_login_form()
```

---

## 7. 服务端实现要点（Python + FastAPI）

### 7.1 项目结构

```
idle_cultivation_server/
├── requirements.txt            # Python依赖
├── main.py                     # 入口文件
├── app/
│   ├── __init__.py
│   ├── main.py                 # FastAPI应用实例
│   ├── api/
│   │   ├── __init__.py
│   │   ├── auth.py             # 账号相关路由
│   │   ├── game.py             # 游戏数据路由
│   │   └── admin.py            # 管理后台路由
│   ├── core/
│   │   ├── __init__.py
│   │   ├── config.py           # 配置管理
│   │   └── security.py         # JWT工具
│   ├── db/
│   │   ├── __init__.py
│   │   ├── database.py         # 数据库连接
│   │   └── models.py           # Tortoise ORM模型
│   └── schemas/
│       ├── __init__.py
│       ├── auth.py             # 认证相关Pydantic模型
│       └── player.py           # 玩家数据Pydantic模型
└── sql/
    └── init.sql                # 数据库初始化脚本
```

### 7.2 核心依赖（requirements.txt）

```
fastapi==0.104.0
uvicorn[standard]==0.24.0
tortoise-orm[asyncpg]==0.20.0
pyjwt==2.8.0
passlib[bcrypt]==1.7.4
python-multipart==0.0.6
pydantic==2.5.0
pydantic-settings==2.1.0
```

### 7.3 JWT验证依赖

```python
# app/core/security.py
from datetime import datetime, timedelta
from typing import Optional
import jwt
from passlib.context import CryptContext

SECRET_KEY = "your-secret-key-here"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_DAYS = 7

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(days=ACCESS_TOKEN_EXPIRE_DAYS))
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

def decode_token(token: str) -> Optional[dict]:
    try:
        return jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    except jwt.PyJWTError:
        return None
```

### 7.4 FastAPI JWT验证中间件

```python
# app/api/deps.py
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from app.core.security import decode_token
from app.db.models import Account

security = HTTPBearer()

async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)) -> Account:
    token = credentials.credentials
    payload = decode_token(token)
    
    if not payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="INVALID_TOKEN"
        )
    
    account_id = payload.get("account_id")
    token_version = payload.get("version")
    
    account = await Account.get_or_none(id=account_id)
    
    if not account:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="ACCOUNT_NOT_FOUND"
        )
    
    if account.token_version != token_version:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="KICKED_OUT"
        )
    
    return account
```

---

## 8. 现有系统改造详情

本节详细说明各现有系统改造为弱联网架构的具体实现。

### 系统概览

| 系统 | 改造类型 | 关键操作 | 说明 |
|------|----------|----------|------|
| SaveManager | 完全重写 | - | 改为 CloudSaveManager |
| AccountSystem | 完全重写 | 登录/注册 | 改为服务端JWT认证 |
| PlayerData | 数据同步 | 突破境界 | 数据从服务端获取 |
| Inventory | 部分改造 | 使用重要道具 | 普通道具本地操作 |
| CultivationSystem | 数据同步 | - | 修炼状态本地计算 |
| LianliSystem | 部分改造 | 战斗胜利 | 战斗过程本地执行 |
| SpellSystem | 部分改造 | 升级/充能 | 装备/卸下本地操作 |
| RealmSystem | 服务端验证 | 突破境界 | 权威验证 |
| AlchemySystem | 服务端验证 | 学习丹方/炼丹 | 新增系统 |

---

### 8.1 SaveManager → CloudSaveManager

**改造要点**：完全重写，本地不存任何数据

**现有代码结构**：
```gdscript
# scripts/core/SaveManager.gd
class_name SaveManager extends Node

const SAVE_VERSION = "1.3"
const USER_DATA_DIR = "res://user_data"

func save_game() -> bool:
    var save_data = {
        "player": player.get_save_data(),
        "inventory": inventory.get_save_data(),
        "spell_system": spell_system.get_save_data(),
        "timestamp": Time.get_unix_time_from_system(),
        "version": SAVE_VERSION
    }
    var file = FileAccess.open(save_file_path, FileAccess.WRITE)
    file.store_string(JSON.stringify(save_data))
    return true

func load_game() -> bool:
    var file = FileAccess.open(save_file_path, FileAccess.READ)
    var save_data = JSON.parse_string(file.get_as_text())
    apply_save_data(save_data)
    return true
```

**改造后代码**：
```gdscript
# scripts/managers/CloudSaveManager.gd
class_name CloudSaveManager extends Node

const AUTO_SAVE_INTERVAL = 300  # 5分钟
const MAX_SAVE_FAILURES = 3

var save_failure_count: int = 0
var last_save_time: int = 0

func _ready():
    start_auto_save()

func start_auto_save():
    while true:
        await get_tree().create_timer(AUTO_SAVE_INTERVAL).timeout
        await save_game()

func save_game() -> bool:
    var data = collect_game_data()
    var result = await NetworkManager.save_game(data)
    
    if result.success:
        last_save_time = Time.get_unix_time_from_system()
        save_failure_count = 0
        return true
    else:
        save_failure_count += 1
        push_warning("自动保存失败 (%d/%d)" % [save_failure_count, MAX_SAVE_FAILURES])
        
        if save_failure_count >= MAX_SAVE_FAILURES:
            _force_logout()
        return false

func _force_logout():
    show_error("网络连接异常，请重新登录")
    NetworkManager.clear_token()
    get_tree().change_scene_to_file("res://scenes/login/Login.tscn")

func load_game() -> bool:
    var result = await NetworkManager.load_game()
    if result.success:
        apply_game_data(result.data)
        return true
    return false

func collect_game_data() -> Dictionary:
    var game_manager = get_node("/root/GameManager")
    return {
        "player": game_manager.get_player().get_save_data(),
        "inventory": game_manager.get_inventory().get_save_data(),
        "spell_system": game_manager.get_spell_system().get_save_data(),
        "timestamp": Time.get_unix_time_from_system()
    }

func apply_game_data(data: Dictionary):
    var game_manager = get_node("/root/GameManager")
    game_manager.get_player().apply_save_data(data.get("player", {}))
    game_manager.get_inventory().apply_save_data(data.get("inventory", {}))
    game_manager.get_spell_system().apply_save_data(data.get("spell_system", {}))
```

---

### 8.2 AccountSystem → 服务端认证

**改造要点**：本地账号验证改为服务端JWT认证

**现有代码结构**：
```gdscript
# scripts/core/AccountSystem.gd
class_name AccountSystem extends Node

const ACCOUNTS_FILE = "user://accounts.json"
var accounts: Dictionary = {}

func login(username: String, password: String) -> bool:
    if not accounts.has(username):
        return false
    if accounts[username].password != password:
        return false
    current_account = username
    return true
```

**改造后代码**：
```gdscript
# scripts/core/AccountSystem.gd（改造版）
class_name AccountSystem extends Node

signal login_success(username: String, token: String)
signal login_failed(reason: String)
signal token_expired()

const TOKEN_FILE = "user://auth_token.dat"

var current_token: String = ""
var current_account: Dictionary = {}

func login(username: String, password: String) -> void:
    var body = {"username": username, "password": password}
    
    NetworkManager.execute_critical_operation(
        "/auth/login",
        body,
        func(data): _on_login_success(username, data)
    )

func _on_login_success(username: String, data: Dictionary):
    current_token = data.token
    current_account = data.account_info
    save_token(data.token)
    login_success.emit(username, data.token)

func register(username: String, password: String) -> void:
    var body = {"username": username, "password": password}
    
    NetworkManager.execute_critical_operation(
        "/auth/register",
        body,
        func(data): _on_register_success(username, data)
    )

func logout():
    current_token = ""
    current_account = {}
    clear_token()

func save_token(token: String):
    current_token = token
    var file = FileAccess.open(TOKEN_FILE, FileAccess.WRITE)
    file.store_string(token)

func load_token() -> bool:
    if FileAccess.file_exists(TOKEN_FILE):
        var file = FileAccess.open(TOKEN_FILE, FileAccess.READ)
        current_token = file.get_as_text()
        return not current_token.is_empty()
    return false

func clear_token():
    current_token = ""
    if FileAccess.file_exists(TOKEN_FILE):
        DirAccess.remove_absolute(TOKEN_FILE)

func get_auth_headers() -> Array:
    return ["Authorization: Bearer " + current_token]
```

---

### 8.3 PlayerData → 服务端数据加载

**改造要点**：数据从服务端获取，突破需服务端验证

**现有代码结构**：
```gdscript
# scripts/core/PlayerData.gd
class_name PlayerData extends Node

var realm: String = "炼气期"
var realm_level: int = 1
var health: float = 500.0
var spirit_energy: float = 0.0
var tower_highest_floor: int = 0
var learned_recipes: Array = []
var has_alchemy_furnace: bool = false
var daily_dungeon_data: Dictionary = {}

func attempt_breakthrough() -> Dictionary:
    var result = can_breakthrough()
    if not result.get("can", false):
        breakthrough_failed.emit(result.get("reason", ""))
        return result
    # 消耗资源并突破...
    
func get_save_data() -> Dictionary:
    return {
        "realm": realm,
        "realm_level": realm_level,
        "health": health,
        "spirit_energy": spirit_energy,
        "tower_highest_floor": tower_highest_floor,
        "learned_recipes": learned_recipes,
        "has_alchemy_furnace": has_alchemy_furnace,
        "daily_dungeon_data": daily_dungeon_data.duplicate()
    }
```

**改造后代码**：
```gdscript
# scripts/core/PlayerData.gd（改造版）
class_name PlayerData extends Node

signal breakthrough_verified(result: Dictionary)

func attempt_breakthrough() -> void:
    var game_manager = get_node("/root/GameManager")
    var inventory = game_manager.get_inventory()
    
    var body = {
        "current_realm": realm,
        "current_level": realm_level,
        "spirit_energy": spirit_energy,
        "inventory_items": _get_breakthrough_materials()
    }
    
    NetworkManager.execute_critical_operation(
        "/player/breakthrough",
        body,
        func(data): _apply_breakthrough(data)
    )

func _get_breakthrough_materials() -> Dictionary:
    var game_manager = get_node("/root/GameManager")
    var inventory = game_manager.get_inventory()
    var realm_system = game_manager.get_realm_system()
    
    var is_realm_breakthrough = (realm_level >= realm_system.get_realm_info(realm).get("max_level", 0))
    var required = realm_system.get_breakthrough_materials(realm, realm_level, is_realm_breakthrough)
    
    var items = {}
    for material_id in required.keys():
        items[material_id] = inventory.get_item_count(material_id)
    return items

func _apply_breakthrough(data: Dictionary):
    realm = data.new_realm
    realm_level = data.new_level
    spirit_energy = data.remaining_spirit_energy
    
    # 扣除服务端已验证的材料
    var game_manager = get_node("/root/GameManager")
    var inventory = game_manager.get_inventory()
    for material_id in data.materials_used.keys():
        inventory.remove_item(material_id, data.materials_used[material_id])
    
    apply_realm_stats()
    breakthrough_verified.emit(data)

func apply_server_data(data: Dictionary):
    realm = data.get("realm", "炼气期")
    realm_level = data.get("realm_level", 1)
    health = float(data.get("health", 500.0))
    spirit_energy = float(data.get("spirit_energy", 0.0))
    tower_highest_floor = data.get("tower_highest_floor", 0)
    learned_recipes = data.get("learned_recipes", [])
    has_alchemy_furnace = data.get("has_alchemy_furnace", false)
    daily_dungeon_data = data.get("daily_dungeon_data", {}).duplicate()
    apply_realm_stats()
```

---

### 8.4 Inventory → 道具使用验证

**改造要点**：重要道具使用需服务端验证

**现有代码结构**：
```gdscript
# scripts/core/Inventory.gd
class_name Inventory extends Node

var slots: Array = []
var capacity: int = 50

func add_item(item_id: String, count: int = 1) -> bool:
    # 本地添加物品...

func remove_item(item_id: String, count: int = 1) -> bool:
    # 本地移除物品...

func get_save_data() -> Dictionary:
    return {"slots": slots, "capacity": capacity}
```

**改造后代码**：
```gdscript
# scripts/core/Inventory.gd（改造版）
class_name Inventory extends Node

const IMPORTANT_ITEMS = ["foundation_pill", "golden_core_pill", "starter_pack", "recipe_scroll"]

func use_important_item(item_id: String, count: int = 1) -> void:
    var body = {
        "item_id": item_id,
        "count": count,
        "current_inventory": get_save_data()
    }
    
    NetworkManager.execute_critical_operation(
        "/inventory/use_item",
        body,
        func(data): _apply_item_use(item_id, count, data)
    )

func _apply_item_use(item_id: String, count: int, data: Dictionary):
    # 服务端已验证，执行本地操作
    remove_item(item_id, count)
    
    # 应用道具效果
    match item_id:
        "starter_pack":
            _apply_starter_pack(data.contents)
        "foundation_pill", "golden_core_pill":
            # 丹药效果已在服务端计算
            pass
    
    item_used.emit(item_id, count)

func add_item(item_id: String, count: int = 1) -> bool:
    # 普通添加物品，本地操作
    # ...原有逻辑...

func remove_item(item_id: String, count: int = 1) -> bool:
    # 普通移除物品，本地操作
    # ...原有逻辑...
```

---

### 8.5 CultivationSystem → 修炼数据同步

**改造要点**：修炼状态本地计算，定时保存时同步

**现有代码结构**：
```gdscript
# scripts/core/CultivationSystem.gd
class_name CultivationSystem extends Node

var is_cultivating: bool = false
var cultivation_timer: float = 0.0
var cultivation_interval: float = 1.0

func do_cultivate():
    # 计算灵气增长
    player.add_spirit_energy(spirit_gain)
    cultivation_progress.emit(player.spirit_energy, player.get_final_max_spirit_energy())
```

**改造说明**：
- 修炼过程完全本地计算，无需服务端实时验证
- 灵气数据在定时保存时同步到服务端
- 离线收益由服务端在登录时计算

**无需修改代码**，修炼系统保持现有逻辑。

---

### 8.6 LianliSystem → 战斗结果上报

**改造要点**：战斗过程本地执行，战斗胜利需服务端验证掉落

**现有代码结构**：
```gdscript
# scripts/core/LianliSystem.gd
class_name LianliSystem extends Node

var is_in_battle: bool = false
var current_enemy: Dictionary = {}

func _handle_battle_victory():
    # 计算掉落
    var loot = []
    for item_id in drops_config.keys():
        if randf() <= chance:
            loot.append({"item_id": item_id, "amount": amount})
            lianli_reward.emit(item_id, amount, "lianli")
```

**改造后代码**：
```gdscript
# scripts/core/LianliSystem.gd（改造版）
class_name LianliSystem extends Node

func _handle_battle_victory():
    is_in_battle = false
    _restore_health_after_combat()
    
    var body = {
        "area_id": current_area_id,
        "enemy_id": current_enemy.get("id", ""),
        "enemy_level": current_enemy.get("level", 1),
        "is_tower": is_in_tower,
        "tower_floor": current_tower_floor if is_in_tower else 0
    }
    
    NetworkManager.execute_critical_operation(
        "/battle/victory",
        body,
        func(data): _apply_battle_loot(data)
    )

func _apply_battle_loot(data: Dictionary):
    var loot = data.loot
    var game_manager = get_node("/root/GameManager")
    var inventory = game_manager.get_inventory()
    
    for item in loot:
        inventory.add_item(item.item_id, item.amount)
        lianli_reward.emit(item.item_id, item.amount, "lianli")
    
    # 更新无尽塔最高层数
    if is_in_tower and data.has("new_highest_floor"):
        game_manager.get_player().tower_highest_floor = data.new_highest_floor
    
    battle_ended.emit(true, loot, current_enemy.get("name", ""))
```

---

### 8.7 SpellSystem → 术法同步

**改造要点**：术法升级、充能需服务端确认

**现有代码结构**：
```gdscript
# scripts/core/SpellSystem.gd
class_name SpellSystem extends Node

var player_spells: Dictionary = {}
var equipped_spells: Dictionary = {}

func upgrade_spell(spell_id: String) -> Dictionary:
    # 检查条件并升级
    spell_info.level = next_level
    spell_info.charged_spirit -= spirit_cost
    spell_upgraded.emit(spell_id, next_level)

func charge_spell_spirit(spell_id: String, amount: int) -> Dictionary:
    # 扣除灵气并充能
    player.spirit_energy -= available
    spell_info.charged_spirit += available
```

**改造后代码**：
```gdscript
# scripts/core/SpellSystem.gd（改造版）
class_name SpellSystem extends Node

func upgrade_spell(spell_id: String) -> void:
    var spell_info = player_spells[spell_id]
    
    var body = {
        "spell_id": spell_id,
        "current_level": spell_info.level,
        "use_count": spell_info.use_count,
        "charged_spirit": spell_info.charged_spirit
    }
    
    NetworkManager.execute_critical_operation(
        "/spell/upgrade",
        body,
        func(data): _apply_spell_upgrade(spell_id, data)
    )

func _apply_spell_upgrade(spell_id: String, data: Dictionary):
    player_spells[spell_id].level = data.new_level
    player_spells[spell_id].charged_spirit = data.remaining_charged_spirit
    player_spells[spell_id].use_count = 0
    spell_upgraded.emit(spell_id, data.new_level)

func charge_spell_spirit(spell_id: String, amount: int) -> void:
    var body = {
        "spell_id": spell_id,
        "amount": amount,
        "player_spirit": player.spirit_energy
    }
    
    NetworkManager.execute_critical_operation(
        "/spell/charge",
        body,
        func(data): _apply_spell_charge(spell_id, amount, data)
    )

func _apply_spell_charge(spell_id: String, amount: int, data: Dictionary):
    player.spirit_energy -= amount
    player_spells[spell_id].charged_spirit += amount

# 装备/卸下术法：本地操作，无需服务端验证
func equip_spell(spell_id: String) -> Dictionary:
    # ...原有逻辑，保持不变...

func unequip_spell(spell_id: String) -> Dictionary:
    # ...原有逻辑，保持不变...
```

---

### 8.8 RealmSystem → 突破验证

**改造要点**：突破境界需服务端权威验证

**现有代码结构**：
```gdscript
# scripts/core/RealmSystem.gd
class_name RealmSystem extends Node

const BREAKTHROUGH_MATERIALS = {
    "realm_breakthrough": {...},
    "level_breakthrough": {...}
}

func can_breakthrough(realm_name: String, current_level: int, spirit_stone: int, spirit_energy: int, inventory_items: Dictionary) -> Dictionary:
    # 检查资源是否足够
    # 返回是否可以突破

func get_breakthrough_materials(realm_name: String, current_level: int, is_realm_breakthrough: bool) -> Dictionary:
    # 获取所需材料
```

**改造说明**：
- RealmSystem 保持现有配置和查询逻辑
- 实际突破操作由 PlayerData 调用 NetworkManager 执行
- 服务端验证时会使用相同的配置进行校验

**无需修改代码**，RealmSystem 作为配置查询工具使用。

---

### 8.9 AlchemySystem → 炼丹验证（新增）

**改造要点**：学习丹方、炼丹需服务端验证

**现有代码结构**：
```gdscript
# scripts/core/AlchemySystem.gd
class_name AlchemySystem extends Node

var is_crafting: bool = false
var current_craft_recipe: String = ""
var craft_success_count: int = 0
var craft_fail_count: int = 0

func learn_recipe(recipe_id: String) -> bool:
    if recipe_id in player.learned_recipes:
        return false
    player.learned_recipes.append(recipe_id)
    recipe_learned.emit(recipe_id)
    return true

func start_crafting_batch(recipe_id: String, count: int) -> Dictionary:
    # 检查材料、灵气
    # 开始炼制
    is_crafting = true
    # ...炼制逻辑...
```

**改造后代码**：
```gdscript
# scripts/core/AlchemySystem.gd（改造版）
class_name AlchemySystem extends Node

func learn_recipe(recipe_id: String) -> void:
    var body = {
        "recipe_id": recipe_id,
        "current_recipes": player.learned_recipes
    }
    
    NetworkManager.execute_critical_operation(
        "/alchemy/learn_recipe",
        body,
        func(data): _apply_learn_recipe(recipe_id, data)
    )

func _apply_learn_recipe(recipe_id: String, data: Dictionary):
    player.learned_recipes.append(recipe_id)
    recipe_learned.emit(recipe_id)

func start_crafting_batch(recipe_id: String, count: int) -> void:
    var body = {
        "recipe_id": recipe_id,
        "count": count,
        "materials": _get_current_materials(recipe_id, count),
        "spirit_energy": player.spirit_energy
    }
    
    NetworkManager.execute_critical_operation(
        "/alchemy/start_craft",
        body,
        func(data): _start_crafting_with_result(recipe_id, count, data)
    )

func _start_crafting_with_result(recipe_id: String, count: int, data: Dictionary):
    # 服务端已验证，开始本地炼制
    is_crafting = true
    current_craft_recipe = recipe_id
    current_craft_count = count
    craft_time_per_pill = calculate_craft_time(recipe_id)
    
    # 预先消耗材料
    _consume_materials_for_batch(recipe_id, count)
    
    crafting_started.emit(recipe_id, count)

func _complete_single_pill():
    # 炼制过程保持本地计算
    # 成功/失败由本地随机决定
    var success_rate = calculate_success_rate(current_craft_recipe)
    var roll = randf() * 100.0
    
    if roll <= success_rate:
        craft_success_count += 1
        # 添加成品
        var product = recipe_data.get_recipe_product(current_craft_recipe)
        inventory.add_item(product, recipe_data.get_recipe_product_count(current_craft_recipe))
    else:
        craft_fail_count += 1
        # 返还一半材料
        _return_half_materials(1)
```

---

### 8.10 GameUI/SettingsModule → 移除存档功能

**改造要点**：移除手动存档/读档按钮，添加登出流程

**改造要点**：移除手动存档/读档按钮，添加登录流程

```gdscript
# 改造后的 SettingsModule
class_name SettingsModule extends Node

# 移除了 save_button 和 load_button
var logout_button: Button = null

func _setup_signals():
    if logout_button:
        logout_button.pressed.connect(_on_logout_pressed)

func _on_logout_pressed():
    # 先同步数据
    await game_manager.get_save_manager().save_game()
    
    # 清除本地token
    NetworkManager.clear_token()
    
    # 返回登录界面
    get_tree().change_scene_to_file("res://scenes/login/Login.tscn")
```

```gdscript
# 新增的 LoginUI
class_name LoginUI extends Control

signal login_success(account_info: Dictionary)

func _ready():
    login_button.pressed.connect(_on_login_pressed)
    # 检查自动登录
    check_auto_login()

func check_auto_login():
    if NetworkManager.load_token():
        var result = await GameServerAPI.verify_token()
        if result.success:
            var data = await GameServerAPI.load_game()
            CloudSaveManager.apply_game_data(data)
            login_success.emit(result.account_info)
        else:
            show_login_form()
    else:
        show_login_form()

func _on_login_pressed():
    var result = await GameServerAPI.login(username_input.text, password_input.text)
    
    if result.success:
        NetworkManager.save_token(result.token)
        CloudSaveManager.apply_game_data(result.data)
        
        # 显示离线收益
        if result.offline_seconds > 60:
            show_offline_reward(result.offline_reward, result.offline_seconds)
        
        login_success.emit(result.account_info)
```

---

## 9. 注意事项

### 9.1 安全性
- 密码使用bcrypt加密存储
- JWT使用强密钥，定期更换
- 生产环境使用HTTPS
- 数据库连接使用环境变量配置

### 9.2 性能优化（后续）
- 如果玩家数据量大，考虑拆分JSONB字段
- 频繁查询的字段加索引
- 数据库连接池配置

### 9.3 数据迁移
- 现有本地存档不需要迁移
- 新用户直接云端存档
- 老用户重新注册登录后从初始状态开始

### 9.4 后续扩展
- 手机号绑定功能
- 找回密码功能
- 第三方登录（TapTap）
---
## 10. 开发阶段划分

### 10.1 第一阶段：环境配置

**目标**：搭建开发环境

| 配置项 | 值 |
|--------|-----|
| 服务端目录 | `idle_cultivation_server/`（与客户端同级） |
| 数据库名 | `idle_cultivation_game` |
| 服务端端口 | `8444` |

**安装清单**：

```bash
# 1. 创建服务端项目目录
mkdir idle_cultivation_server
cd idle_cultivation_server

# 2. 创建 Python 虚拟环境
python3.12 -m venv venv
source venv/bin/activate  # Linux/Mac
# venv\Scripts\activate  # Windows

# 3. 安装依赖
pip install fastapi uvicorn
pip install "tortoise-orm[asyncpg]"
pip install pyjwt
pip install "passlib[bcrypt]"
pip install streamlit
pip install python-multipart  # 表单支持
pip install python-dotenv     # 环境变量

# 4. 安装 PostgreSQL
# Linux: sudo apt install postgresql
# Mac: brew install postgresql
# Windows: 见下方 Windows 开发环境搭建

# 5. 创建数据库
createdb idle_cultivation_game
```

#### Windows 开发环境搭建

```powershell
# 1. 安装 Python 3.11+
# 下载地址: https://www.python.org/downloads/
# 安装时勾选 "Add Python to PATH"

# 2. 安装 PostgreSQL
# 下载地址: https://www.postgresql.org/download/windows/
# 安装时记住设置的密码（默认用户是 postgres）

# 3. 配置 PostgreSQL 环境变量（可选）
# 将 PostgreSQL 的 bin 目录添加到 PATH
# 例如: C:\Program Files\PostgreSQL\16\bin

# 4. 创建数据库
# 方式一：使用 pgAdmin 图形界面
# 方式二：使用命令行
psql -U postgres
# 输入密码后执行：
CREATE DATABASE idle_cultivation_game;

# 5. 创建服务端项目目录
mkdir idle_cultivation_server
cd idle_cultivation_server

# 6. 创建 Python 虚拟环境
python -m venv venv
venv\Scripts\activate

# 7. 安装依赖
pip install fastapi uvicorn
pip install "tortoise-orm[asyncpg]"
pip install pyjwt
pip install "passlib[bcrypt]"
pip install streamlit
pip install python-multipart
pip install python-dotenv
```

**验收标准**：
- PostgreSQL 可连接
- Python 虚拟环境正常
- 依赖安装成功

---

### 10.2 第二阶段：搭建服务端基础

**目标**：实现注册/登录 API

**配置项**：
| 配置项 | 值 |
|--------|-----|
| 服务端端口 | `8444` |
| JWT 密钥管理 | 配置文件 `config/secrets.yaml`（不入库） |

**开发内容**：
1. 项目目录结构
2. 数据库表创建（accounts, player_data）
3. JWT 工具类
4. 注册 API: `POST /api/auth/register`
5. 登录 API: `POST /api/auth/login`
6. Token 续期 API: `POST /api/auth/refresh`
7. 基础错误码定义

**验收标准**：
- 可用 Postman 测试注册/登录 API
- JWT Token 生成和验证正常

---

### 10.3 第三阶段：客户端网络层

**目标**：客户端可调用服务端 API

**配置项**：
| 配置项 | 值 |
|--------|-----|
| 服务端地址 | 配置文件 `ServerConfig.gd` |

**开发内容**：
1. `scripts/network/ServerConfig.gd` - 服务端配置
2. `scripts/network/NetworkManager.gd` - HTTP 请求管理、Token 管理
3. `scripts/network/GameServerAPI.gd` - API 封装
4. 网络错误处理
5. 加载弹窗组件

**验收标准**：
- 客户端可调用 API 并处理响应
- Token 自动存储和续期

---

### 10.4 第四阶段：存档同步 + 账号认证

**目标**：完整联网功能，可测试

**存档触发时机**：
| 触发时机 | 操作 |
|----------|------|
| 登录成功 | 自动加载云端数据 |
| 第一次登录 | 自动触发一次保存 |
| 退出游戏 | 自动保存 |
| 定时（5分钟） | 自动保存 |

**⚠️ 重要变更**：
- 设置界面的「保存」「读取」按钮 → **废弃**
- 所有存档操作 → **全自动，用户无感知**

**开发内容**：
1. 登录/注册界面
2. CloudSaveManager 替代 SaveManager
3. 登录时加载云端数据
4. 定时自动保存
5. 离线收益计算（服务端计算，登录时返回）

**验收标准**：
- 注册 → 登录 → 游玩 → 退出 → 登录 → 数据正确

---

### 10.5 第五阶段：关键操作验证

**目标**：关键操作服务端验证

**验证操作**：
| 操作 | 验证内容 |
|------|----------|
| 突破境界 | 验证资源是否足够 |
| 战斗胜利 | 验证战斗合法性，计算掉落 |
| 重要道具使用 | 验证道具是否拥有 |
| 术法升级/充能 | 验证资源是否足够 |
| 学习丹方 | 验证条件是否满足 |

**验收标准**：
- 关键操作有服务端验证
- 作弊操作被拒绝

---

### 10.6 第六阶段：运营管理平台

**目标**：可视化管理后台

**技术选型**：Streamlit（Python 快速 Web 框架）

**功能清单**：
1. 管理员登录
2. 玩家列表/搜索
3. 玩家详情查看
4. 封号/解封功能
5. 区服管理

**验收标准**：
- 管理员可查看玩家详情
- 管理员可封禁/解封玩家

---

## 11. 参考文档

- [PostgreSQL JSONB文档](https://www.postgresql.org/docs/current/datatype-json.html)
- [JWT官方文档](https://jwt.io/introduction)
- [FastAPI官方文档](https://fastapi.tiangolo.com/)
- [Godot HTTPRequest文档](https://docs.godotengine.org/en/stable/classes/class_httprequest.html)

---

**文档版本**: 1.0  
**创建日期**: 2026-03-14