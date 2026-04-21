# UI 模板索引

本文记录客户端当前可复用的 UI 模板与使用约束，作为内视页面及后续模块 UI 改造的统一基线。

## 模板清单

### 1) `TabBarStyleTemplate`

- 路径：`scripts/ui/common/TabBarStyleTemplate.gd`
- 用途：统一主底部 Tab 与内视子 Tab 的样式、字号、分割线位置与选中态颜色。
- 核心约束：
  - 按钮宽度自动均分，`separation=0`。
  - 选中态仍由 `disabled=true` 驱动（当前项目约定）。
  - `line_position` 支持 `top/bottom`，用于主 Tab 与子 Tab 复用。

### 2) `DisplayPanelTemplate`

- 路径：`scripts/ui/common/DisplayPanelTemplate.gd`
- 用途：统一“展示面板”的标题行（左强调线 + 标题 + 分割线）与内容对齐规则。
- 核心约束：
  - 内容左侧对齐基线：`DEFAULT_CONTENT_LEFT_INSET = 12`
  - 标题下方留白：`DEFAULT_HEADER_BOTTOM_GAP = 8`
  - 后续新增内容必须遵循“标题首字左侧对齐 + 固定留白”。
- 当前应用：
  - 修炼页属性面板
  - 修炼页突破面板

### 3) `SpellThumbnailTemplate`

- 路径：`scripts/ui/common/SpellThumbnailTemplate.gd`
- 用途：统一术法缩略卡样式。
- 当前默认：
  - 卡片底色：`#f2e5cc`
  - 圆角边框风格
  - 按钮颜色策略由 `SpellModule` 在卡片行为层补充（查看浅棕、装备可点金色/不可点灰色）。

### 4) `PopupStyleTemplate`

- 路径：`scripts/ui/common/PopupStyleTemplate.gd`
- 用途：统一弹窗面板样式与遮罩视觉（外部暗化）。
- 当前默认：
  - 弹窗底色：`#eadab9`（不透明）
  - 圆角矩形 + 边框
  - 全屏遮罩暗化
  - 遮罩层不拦截点击；“点击弹窗外关闭”由具体弹窗组件实现（当前 `SpellDetailPopup`、`ProfileEditPopup` 已实现）
- 当前应用：
  - 术法详情弹窗 `SpellDetailPopup`
  - 顶部账号编辑弹窗 `ProfileEditPopup`（昵称/头像）

### 5) `ActionButtonTemplate`

- 路径：`scripts/ui/common/ActionButtonTemplate.gd`
- 用途：统一四类关键行为按钮配色与交互态（normal/hover/pressed/disabled），避免各模块重复写色值。
- 预设清单：
  - `PRESET_CULTIVATION_YELLOW`：开始/停止修炼黄按钮
  - `PRESET_BREAKTHROUGH_RED`：突破红按钮
  - `PRESET_ALCHEMY_GREEN`：开始炼制绿按钮
  - `PRESET_PROFILE_BLUE`：变更昵称蓝按钮
  - `PRESET_LIGHT_NEUTRAL`：淡白按钮（返回/整理/FPS 默认）
  - `PRESET_LIGHT_NEUTRAL_SELECTED`：淡白按钮选中态（FPS 当前档位）
  - `PRESET_SPELL_VIEW_BROWN`：术法查看棕色按钮（含术法弹窗 `+`/`x10`）
- 使用约束：
  - 业务侧只允许改按钮文字与尺寸（`custom_minimum_size` / `font_size`）。
  - 颜色、边框、圆角、状态色统一由模板提供，不在业务模块内手写。
- 当前应用：
  - 内视修炼按钮（黄）与突破按钮（红）
  - 炼丹房开始炼制（绿）、停止（红）、返回（淡白）
  - 账号编辑弹窗变更昵称/变更头像按钮（蓝）
  - 储纳：使用（黄）、丢弃（红）、扩容（黄）、整理（淡白）
  - 术法缩略卡：查看（棕色）、装备/卸下（黄）
  - 术法详情弹窗：升级（黄）、关闭（红）、`+`/`x10`（棕色）
  - 设置：FPS 档位按钮（淡白 + 选中态）、排行榜返回（淡白）

## 当前调试型 UI 工具

### `ResolutionPreview`

- 场景：`scenes/debug/ResolutionPreview.tscn`
- 脚本：`scripts/ui/debug/ResolutionPreview.gd`
- 用途：人工预览长屏 / 异形屏下的登录页与后续主界面布局
- 当前预设：
  - `1080×1920`
  - `1080×2400`
  - `1125×2436`
- 约束：
  - 只作为人工验收工具，不参与正式业务流程
  - 只有从该调试场景进入时才允许改窗口 / 预览分辨率
  - 正常从登录页或项目主入口启动时，不应触发改窗口逻辑

## 使用规则

- 新增同类 UI 时优先复用现有模板，不重复造样式。
- 如果模块必须自定义样式，先保留模板基线，再局部覆盖，不要破坏模板默认契约。
- 涉及模板参数或默认视觉变更时，必须同步更新本文与对应模块文档（`docs/02-modules/*`）。
- 涉及安全区、长屏、异形屏或弹窗尺寸策略变更时，必须同步更新测试文档中的人工验收说明。

## 关联文档

- [修炼与突破](../02-modules/02-cultivation-breakthrough.md)
- [术法](../02-modules/04-spell.md)
- [文档更新规则](./DocUpdateRules.md)
