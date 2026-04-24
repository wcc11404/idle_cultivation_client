# 代码结构与边界

本文用于回答两个问题：

- `scripts/` 里每层各做什么。
- `scenes/` 与 `scripts/ui/*` 的职责边界是什么。

## 顶层目录职责

### `scripts/`

- `autoload/`：全局单例与系统装配。
  - `GameManager.gd`：创建并持有玩家状态容器（player/inventory/spell/lianli/alchemy）与静态配置节点。
- `network/`：纯网络层。
  - `NetworkManager.gd`：HTTP 请求、技术错误过滤、鉴权失效处理。
  - `GameServerAPI.gd`：业务 API 封装（不含 `/api/test/*`）。
  - `ServerConfig.gd`：API 基址持久化与读取。
- `ui/`：界面控制层。
  - `ui/app/`：场景级脚本。
    - `LoginUI.gd`：登录页流程。
    - `GameUI.gd`：主界面入口、模块初始化与跨模块编排。
  - `ui/modules/`：业务模块控制器（修炼/储纳/术法/炼丹/历练/设置等）。
  - `ui/common/`：跨模块 UI 公共组件（日志、背景、进度条）。
- `core/`：本地状态容器 + 静态配置查询（非服务端真值）。
  - `core/player/PlayerData.gd`：玩家运行态入口。
  - `core/shared/AttributeCalculator.gd`：通用属性计算入口。
  - `core/account/AccountConfig.gd`：账号展示配置（头像等）。
  - `core/*/` 子目录：背包、术法、炼丹、历练、境界等配置与状态容器。
- `utils/`
  - `utils/flow/ActionLockManager.gd`：统一的短时动作锁，避免连点并发。
  - `UIUtils.gd`：少量 UI 辅助函数。

### `scenes/`

- `scenes/app/`
  - `Login.tscn`：登录场景。
  - `Main.tscn`：主游戏场景（容器与节点树）。

> 当前已移除未引用的 `components/devtools` 场景目录，避免“场景资产存在但运行链路未使用”的混淆。

## `scenes` 与 `scripts/ui` 的边界

- `scenes` 负责：
  - 节点树结构
  - 布局与主题
  - 可视控件挂载点
- `scripts/ui` 负责：
  - 事件响应
  - API 调用
  - 状态流转与文案输出

判定规则：

- 只改布局/节点样式：改 `scenes`。
- 只改交互流程/文案/请求：改 `scripts/ui`。
- 需要新增可复用控件逻辑：优先放 `scripts/ui/common`，场景只提供挂载容器。

## 当前模块装配关系

启动链路：

1. `project.godot` 进入 `scenes/app/Login.tscn`。
2. 登录成功后切到 `scenes/app/Main.tscn`。
3. `GameUI.gd` 在 `_ready` 中创建并初始化各 `ui/modules/*`。
4. 模块通过 `GameServerAPI + GameManager` 完成“API 真值同步 + 本地展示态更新”。

## 后续结构优化建议（不影响当前运行）

- 若后续继续拆分，可先把 `GameUI.gd` 的“节点绑定区”与“模块编排区”拆成两个 helper，降低单文件长度。
- `core/*System.gd` 继续作为状态容器保留，不建议回流到本地权威计算路径。
