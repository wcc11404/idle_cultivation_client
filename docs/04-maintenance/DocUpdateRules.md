# 文档更新规则

## 必须同步文档的改动类型

- 新增/删除业务接口调用。
- `reason_code` 映射或文案策略调整。
- 关键状态流转变化（如乐观更新、预扣、回放、收敛逻辑）。
- 测试入口、运行前置、测试账号约定变化。
- 公共 UI 模板或默认视觉契约变化（Tab、展示面板、弹窗、术法缩略卡等）。
- 全局字体真值、内置图标资源、系统字体/emoji 依赖策略变化。
- 主界面设计基线、长屏/异形屏安全区、`ContentFrame` 承载范围变化。

## 最低更新要求

- 更新对应模块文档（`docs/02-modules/*`）。
- 若涉及全局约束，更新 `docs/01-overview/*`。
- 若涉及测试链路，更新 `docs/03-testing/GUT_API_Testing.md`。
- 若涉及模板层变更，更新 `docs/04-maintenance/UI_Templates_Index.md`。

## 提交前检查

- 文档中不出现已下线能力：
  - `CloudSaveManager`
  - `SaveManager`
  - `OfflineReward`
  - `tests/TestRunner.tscn`
  - `run_all_tests.gd`
- 文档中的测试命令与当前脚本一致：`./run_tests.sh`。
- 默认 API 地址保持一致：`http://localhost:8444/api`。
