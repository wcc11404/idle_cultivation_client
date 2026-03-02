# 弱联网系统设计方案

## 1. 概述

本文档描述将单机修仙游戏改造为弱联网游戏的技术方案。

### 核心原则
- **纯云端存档**：本地不存储任何游戏进度
- **单设备登录**：同一时间只允许一个设备在线
- **弱网友好**：断网可继续游戏，联网后自动同步
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

### Mac开发环境搭建

```bash
# 安装Homebrew（如果还没有）
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 安装PostgreSQL
brew install postgresql
brew services start postgresql

# 安装Python（3.9+）
brew install python@3.11

# 创建虚拟环境
cd idle_cultivation_server
python3.11 -m venv venv
source venv/bin/activate

# 安装依赖
pip install -r requirements.txt

# 创建数据库
createdb xiuxian_game
```

---

## 3. 数据库设计

### 3.1 表结构

```sql
-- 账号表
CREATE TABLE accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(20) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    phone VARCHAR(11),                    -- 可选，后续绑定手机号用于找回密码
    token_version INT DEFAULT 0,          -- 单设备登录控制，每次登录+1
    created_at TIMESTAMP DEFAULT NOW()
);

-- 玩家数据表
CREATE TABLE player_data (
    account_id UUID PRIMARY KEY REFERENCES accounts(id),
    data JSONB NOT NULL,                  -- 所有游戏数据（详见下文结构）
    last_online_at TIMESTAMP DEFAULT NOW(), -- 用于离线收益计算
    updated_at TIMESTAMP DEFAULT NOW()
);

-- 索引
CREATE INDEX idx_accounts_username ON accounts(username);
CREATE INDEX idx_player_data_updated ON player_data(updated_at);
```

### 3.2 player_data.data JSONB结构

```json
{
    "version": "1.0",
    "player": {
        "realm": "炼气期",
        "realm_level": 1,
        "health": 100,
        "spirit_energy": 50,
        "spirit_stones": 1000,
        "tower_highest_floor": 0,
        "learned_recipes": [],
        "has_alchemy_furnace": false
    },
    "inventory": {
        "slots": [
            {"item_id": "spirit_stone", "quantity": 100}
        ],
        "capacity": 50
    },
    "spell_system": {
        "player_spells": {},
        "equipped_spells": {
            "tuna": null,
            "active": [],
            "passive": []
        }
    },
    "timestamp": 1234567890
}
```

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
    "account_id": "uuid"
}
```

**验证规则：**
- 用户名：4-20位，字母数字下划线
- 密码：6-20位
- 用户名唯一

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
    "data": { /* 完整游戏数据 */ },
    "offline_reward": {    // 离线收益
        "spirit_energy": 100,
        "spirit_stones": 50
    },
    "offline_seconds": 3600
}
```

**登录时服务端处理：**
1. 验证用户名密码
2. token_version + 1
3. 生成新JWT Token（包含account_id和version）
4. 计算离线收益（基于last_online_at）
5. 更新last_online_at
6. 返回游戏数据

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

#### 弱网/断网情况
- 游戏**继续运行**，不阻塞玩家操作
- 保存请求失败时，记录日志，继续游戏
- 下次保存时重试

#### 关键操作失败处理
```gdscript
func on_use_item(item_id):
    var result = await GameServerAPI.use_item(item_id)
    
    if result.success:
        # 服务端已扣除道具，客户端同步状态
        Inventory.remove_item(item_id)
    else:
        # 失败提示，道具未扣除
        show_message("使用失败，请检查网络")
```

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

const API_BASE = "http://localhost:3000/api"
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
        "version": "1.0",
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

### 8.1 SaveManager → CloudSaveManager

**改造要点**：完全重写，本地不存任何数据

```gdscript
# 原 SaveManager 核心逻辑
class_name SaveManager extends Node

const USER_DATA_DIR = "res://user_data"

func save_game() -> bool:
    var save_data = collect_save_data()
    var file = FileAccess.open(save_file_path, FileAccess.WRITE)
    file.store_string(JSON.stringify(save_data))
    return true

func load_game() -> bool:
    var file = FileAccess.open(save_file_path, FileAccess.READ)
    var json_string = file.get_as_text()
    var save_data = JSON.parse_string(json_string)
    apply_save_data(save_data)
    return true
```

```gdscript
# 新 CloudSaveManager 核心逻辑
class_name CloudSaveManager extends Node

const AUTO_SAVE_INTERVAL = 300  # 5分钟

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

func load_game() -> bool:
    var result = await GameServerAPI.load_game()
    if result.success:
        apply_game_data(result.data)
        return true
    return false

func collect_game_data() -> Dictionary:
    return {
        "version": "1.0",
        "player": PlayerData.get_save_data(),
        "inventory": Inventory.get_save_data(),
        "spell_system": SpellSystem.get_save_data(),
        "timestamp": Time.get_unix_time_from_system()
    }
```

---

### 8.2 AccountSystem → 服务端认证

**改造要点**：本地账号验证改为服务端JWT认证

```gdscript
# 原 AccountSystem 核心逻辑
class_name AccountSystem extends Node

const ACCOUNTS_FILE = "user://accounts.json"
var accounts: Dictionary = {}

func login(username: String, password: String) -> bool:
    if not accounts.has(username):
        return false
    if accounts[username].password != password:
        return false
    return true
```

```gdscript
# 新 AccountSystem 核心逻辑
class_name AccountSystem extends Node

signal login_success(username: String, token: String)
signal login_failed(reason: String)
signal token_expired()

const API_BASE_URL = "http://localhost:3000/api"
const TOKEN_FILE = "user://auth_token.dat"

var current_token: String = ""
var current_account: Dictionary = {}

func login(username: String, password: String) -> bool:
    var http = HTTPRequest.new()
    add_child(http)
    
    var body = JSON.stringify({
        "username": username,
        "password": password
    })
    
    var error = http.request(
        API_BASE_URL + "/auth/login",
        ["Content-Type: application/json"],
        HTTPClient.METHOD_POST,
        body
    )
    
    if error != OK:
        login_failed.emit("网络错误")
        return false
    
    var response = await http.request_completed
    var result = parse_response(response)
    
    if result.success:
        current_token = result.token
        current_account = result.account_info
        save_token(result.token)
        login_success.emit(username, result.token)
        return true
    else:
        login_failed.emit(result.message)
        return false

func verify_token() -> bool:
    if current_token.is_empty():
        return false
    
    var http = HTTPRequest.new()
    add_child(http)
    
    var headers = ["Authorization: Bearer " + current_token]
    var error = http.request(
        API_BASE_URL + "/auth/verify",
        headers,
        HTTPClient.METHOD_GET
    )
    
    var response = await http.request_completed
    var result = parse_response(response)
    
    if not result.success:
        token_expired.emit()
        return false
    return true
```

---

### 8.3 PlayerData → 服务端数据加载

**改造要点**：数据从服务端获取，关键操作需验证

```gdscript
# 改造后的 PlayerData 核心逻辑
class_name PlayerData extends Node

signal realm_breakthrough_success(new_realm: String, new_level: int)
signal realm_breakthrough_failed(reason: String)

var server_authority_data: Dictionary = {}

func apply_server_data(data: Dictionary):
    """应用服务端下发的权威数据"""
    server_authority_data = data.duplicate()
    realm = data.get("realm", "炼气期")
    realm_level = data.get("realm_level", 1)
    health = data.get("health", 500.0)
    spirit_energy = data.get("spirit_energy", 0.0)
    apply_realm_stats()

func attempt_breakthrough() -> Dictionary:
    """突破境界，需服务端验证"""
    var http = HTTPRequest.new()
    add_child(http)
    
    var game_manager = get_node("/root/GameManager")
    var inventory = game_manager.get_inventory()
    
    var body = JSON.stringify({
        "current_realm": realm,
        "current_level": realm_level,
        "spirit_energy": spirit_energy,
        "inventory": {
            "spirit_stone": inventory.get_item_count("spirit_stone")
        }
    })
    
    var error = http.request(
        API_BASE_URL + "/player/breakthrough",
        game_manager.get_account_system().get_auth_headers(),
        HTTPClient.METHOD_POST,
        body
    )
    
    var response = await http.request_completed
    var result = parse_response(response)
    
    if result.success:
        apply_server_data(result.player_data)
        realm_breakthrough_success.emit(realm, realm_level)
    else:
        realm_breakthrough_failed.emit(result.reason)
    
    return result
```

---

### 8.4 Inventory → 道具使用验证

**改造要点**：重要道具使用需服务端验证

```gdscript
# 改造后的 Inventory 核心逻辑
class_name Inventory extends Node

signal item_operation_failed(operation: String, reason: String)

var pending_operations: Array = []

func remove_item(item_id: String, count: int = 1, reason: String = "consume") -> bool:
    # 检查是否是重要道具
    if is_important_item(item_id):
        return await remove_item_with_verification(item_id, count, reason)
    
    # 普通道具本地移除
    var success = _local_remove_item(item_id, count)
    if success:
        pending_operations.append({
            "type": "remove",
            "item_id": item_id,
            "count": count,
            "reason": reason,
            "timestamp": Time.get_unix_time_from_system()
        })
    return success

func remove_item_with_verification(item_id: String, count: int, reason: String) -> bool:
    var http = HTTPRequest.new()
    add_child(http)
    
    var game_manager = get_node("/root/GameManager")
    
    var body = JSON.stringify({
        "item_id": item_id,
        "count": count,
        "reason": reason,
        "current_inventory": get_save_data()
    })
    
    var error = http.request(
        API_BASE_URL + "/inventory/consume",
        game_manager.get_account_system().get_auth_headers(),
        HTTPClient.METHOD_POST,
        body
    )
    
    var response = await http.request_completed
    var result = parse_response(response)
    
    if result.success:
        apply_server_inventory(result.inventory_data)
        return true
    else:
        item_operation_failed.emit("remove", result.message)
        return false
```

---

### 8.5 CultivationSystem → 修炼数据同步

**改造要点**：修炼状态定期同步，离线收益服务端计算

```gdscript
# 改造后的 CultivationSystem 核心逻辑
class_name CultivationSystem extends Node

signal cultivation_synced(server_spirit: float)

const SYNC_INTERVAL = 10.0
var server_spirit_energy: float = 0.0

func _ready():
    var timer = Timer.new()
    timer.wait_time = SYNC_INTERVAL
    timer.timeout.connect(sync_cultivation_to_server)
    add_child(timer)

func do_cultivate():
    if not is_cultivating or not player:
        return
    
    cultivation_timer += get_process_delta_time()
    
    if cultivation_timer >= cultivation_interval:
        cultivation_timer = 0.0
        
        # 本地计算（乐观更新）
        var spirit_gain = calculate_spirit_gain()
        player.add_spirit_energy(spirit_gain)
        cultivation_progress.emit(player.spirit_energy, player.get_final_max_spirit_energy())

func sync_cultivation_to_server():
    if not is_cultivating:
        return
    
    var http = HTTPRequest.new()
    add_child(http)
    
    var game_manager = get_node("/root/GameManager")
    
    var body = JSON.stringify({
        "current_spirit": player.spirit_energy,
        "realm": player.realm,
        "timestamp": Time.get_unix_time_from_system()
    })
    
    var error = http.request(
        API_BASE_URL + "/cultivation/sync",
        game_manager.get_account_system().get_auth_headers(),
        HTTPClient.METHOD_POST,
        body
    )
    
    var response = await http.request_completed
    var result = parse_response(response)
    
    if result.success:
        server_spirit_energy = result.server_spirit
        cultivation_synced.emit(server_spirit_energy)
```

---

### 8.6 LianliSystem → 战斗结果上报

**改造要点**：战斗结果上报服务端验证

```gdscript
# 改造后的 LianliSystem 核心逻辑
class_name LianliSystem extends Node

signal battle_result_verified(victory: bool, server_loot: Array)

var battle_log: Array = []
var current_battle_id: String = ""

func start_battle(enemy_data: Dictionary) -> bool:
    # 向服务端申请战斗会话
    var session = await request_battle_session(enemy_data)
    if not session.success:
        return false
    
    current_battle_id = session.battle_id
    battle_log.clear()
    # ... 原有战斗初始化逻辑

func request_battle_session(enemy_data: Dictionary) -> Dictionary:
    var http = HTTPRequest.new()
    add_child(http)
    
    var game_manager = get_node("/root/GameManager")
    
    var body = JSON.stringify({
        "area_id": current_area_id,
        "enemy_template": enemy_data.get("template_id", ""),
        "enemy_level": enemy_data.get("level", 1),
        "player_realm": player.realm
    })
    
    var error = http.request(
        API_BASE_URL + "/battle/start",
        game_manager.get_account_system().get_auth_headers(),
        HTTPClient.METHOD_POST,
        body
    )
    
    var response = await http.request_completed
    return parse_response(response)

func _handle_battle_victory():
    is_in_battle = false
    
    var battle_duration = Time.get_unix_time_from_system() - battle_start_time
    
    # 上报战斗结果
    var result = await report_battle_result(true, battle_duration)
    
    if result.success:
        var server_loot = result.loot
        for item in server_loot:
            lianli_reward.emit(item.item_id, item.amount, "lianli")
        battle_result_verified.emit(true, server_loot)
    else:
        log_message.emit("战斗验证失败：" + result.reason)

func report_battle_result(victory: bool, duration: int) -> Dictionary:
    var http = HTTPRequest.new()
    add_child(http)
    
    var game_manager = get_node("/root/GameManager")
    
    var body = JSON.stringify({
        "battle_id": current_battle_id,
        "victory": victory,
        "duration": duration,
        "battle_log": battle_log,
        "final_player_health": player.health
    })
    
    var error = http.request(
        API_BASE_URL + "/battle/end",
        game_manager.get_account_system().get_auth_headers(),
        HTTPClient.METHOD_POST,
        body
    )
    
    var response = await http.request_completed
    return parse_response(response)
```

---

### 8.7 SpellSystem → 术法同步

**改造要点**：术法升级、充能需服务端确认

```gdscript
# 改造后的 SpellSystem 核心逻辑
class_name SpellSystem extends Node

signal spell_synced(spell_id: String, server_data: Dictionary)

func upgrade_spell(spell_id: String) -> Dictionary:
    var spell_info = player_spells[spell_id]
    
    # 向服务端请求升级
    var server_result = await request_upgrade_spell(spell_id)
    
    if server_result.success:
        player_spells[spell_id].level = server_result.new_level
        player_spells[spell_id].charged_spirit = server_result.remaining_spirit
        spell_upgraded.emit(spell_id, server_result.new_level)
        return {"success": true, "new_level": server_result.new_level}
    else:
        return {"success": false, "reason": server_result.reason}

func request_upgrade_spell(spell_id: String) -> Dictionary:
    var http = HTTPRequest.new()
    add_child(http)
    
    var game_manager = get_node("/root/GameManager")
    var spell_info = player_spells[spell_id]
    
    var body = JSON.stringify({
        "spell_id": spell_id,
        "current_level": spell_info.level,
        "use_count": spell_info.use_count,
        "charged_spirit": spell_info.charged_spirit
    })
    
    var error = http.request(
        API_BASE_URL + "/spell/upgrade",
        game_manager.get_account_system().get_auth_headers(),
        HTTPClient.METHOD_POST,
        body
    )
    
    var response = await http.request_completed
    return parse_response(response)

func charge_spell_spirit(spell_id: String, amount: int) -> Dictionary:
    # 先扣除本地灵气
    var player = get_node("/root/GameManager").get_player()
    if player.spirit_energy < amount:
        return {"success": false, "reason": "灵气不足"}
    
    player.spirit_energy -= amount
    
    # 向服务端确认充能
    var result = await request_charge_spell(spell_id, amount)
    
    if result.success:
        player_spells[spell_id].charged_spirit += amount
        return {"success": true}
    else:
        # 回滚灵气
        player.spirit_energy += amount
        return {"success": false, "reason": result.reason}
```

---

### 8.8 RealmSystem → 突破验证

**改造要点**：突破境界需服务端权威验证

```gdscript
# 改造后的 RealmSystem 核心逻辑
class_name RealmSystem extends Node

signal breakthrough_verified(result: Dictionary)

func request_breakthrough(player: Node, inventory: Node) -> Dictionary:
    var http = HTTPRequest.new()
    add_child(http)
    
    var game_manager = get_node("/root/GameManager")
    
    var body = JSON.stringify({
        "current_realm": player.realm,
        "current_level": player.realm_level,
        "spirit_energy": player.spirit_energy,
        "inventory": {
            "spirit_stone": inventory.get_item_count("spirit_stone")
        }
    })
    
    var error = http.request(
        API_BASE_URL + "/realm/breakthrough",
        game_manager.get_account_system().get_auth_headers(),
        HTTPClient.METHOD_POST,
        body
    )
    
    var response = await http.request_completed
    var server_result = parse_response(response)
    
    if server_result.success:
        # 应用服务端结果
        if server_result.type == "realm":
            player.realm = server_result.new_realm
            player.realm_level = 1
        else:
            player.realm_level = server_result.new_level
        
        # 扣除资源
        inventory.remove_item("spirit_stone", server_result.stone_cost)
        player.spirit_energy -= server_result.energy_cost
        player.apply_realm_stats()
        
        breakthrough_verified.emit(server_result)
    
    return server_result
```

---

### 8.9 GameUI/SettingsModule → 移除存档功能

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
- 邮箱验证
- 第三方登录（TapTap）

---

## 10. 参考文档

- [PostgreSQL JSONB文档](https://www.postgresql.org/docs/current/datatype-json.html)
- [JWT官方文档](https://jwt.io/introduction)
- [FastAPI官方文档](https://fastapi.tiangolo.com/)
- [Godot HTTPRequest文档](https://docs.godotengine.org/en/stable/classes/class_httprequest.html)

---

**文档版本**: 1.0  
**创建日期**: 2026-02-26  
**最后更新**: 2026-02-26