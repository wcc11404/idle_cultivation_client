# 客户端 GUT API 化测试

## 测试目标

- 用真实服务端 API 验证客户端模块行为。
- 默认不以本地 `scripts/core/*` 旧逻辑作为业务真值。

## 前置条件

- 本地服务端已启动并可访问：`http://localhost:8444/api`
- 测试账号可用：`test / test123`
- 服务端支持 `/api/test/*` 测试接口

## 统一入口

在客户端根目录运行：

```bash
./run_tests.sh
```

可选环境变量：

```bash
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/godot
export GODOT_TEST_HOME="$(pwd)/.godot_test_home"
```

## 测试流程约定

每条 API 集成测试默认执行：

1. 清理本地 token / server_config
2. 登录测试账号
3. 调用 `/api/test/reset_account`
4. 按需调用 `/api/test/apply_preset`
5. 同步并断言模块状态、日志、文案

## 当前覆盖重点

- 修炼与突破
  - 连续非法上报仅提示一次
  - 非法后等待下一次 5 秒窗口再合并上报（不立即重试）
- 储纳与道具使用
  - 重要物品丢弃确认弹窗（确认/取消）
- 术法操作与战斗锁定
- 炼丹开炉/上报/停火
  - report 失败后的预扣回滚
- 历练模拟/结算/状态收敛
  - 连战等待态推进
- 设置（改昵称、排行榜、登出）
- 跨模块 smoke
- 网络层技术错误链
  - `AUTH_TOKEN_INVALID` / `AUTH_KICKED_OUT` 统一处理
  - 技术错误 UI 提示节流
  - `alchemy_report` / `lianli_finish` 单次延迟重试策略
