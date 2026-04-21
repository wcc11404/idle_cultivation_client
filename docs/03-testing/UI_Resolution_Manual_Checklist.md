# 长屏 / 异形屏人工验收与预览工具说明

## 目的

本页记录最近一轮客户端 UI 结构调整、长屏/异形屏适配策略，以及当前人工验收的标准流程。

目标不是“让所有页面完全重排”，而是：

- 保持主界面核心构图接近 `720×1280` 设计稿
- 让 `1080×2400`、`1125×2436` 等长屏下，`TopBar` 仍贴顶、`TabBar` 仍贴底
- 主要通过 `ContentPanel` 与 `LogArea` 动态伸缩去吸收额外高度
- 避免刘海、灵动岛、Home Indicator、圆角屏遮挡关键控件

## 本轮 UI 相关改动总表

### 1. 设计基线恢复

- 客户端逻辑设计基线恢复为 `720×1280`
- 默认输出尺寸为 `1080×1920`
- 不再直接把 `1080×1920` 当成新的摆控件基线

对应位置：

- [project.godot](/Users/hsams/Documents/idle_cultivation_project/idle_cultivation_client/project.godot)

### 2. 主界面长屏策略（当前实现）

当前主界面不再采用“上下额外留大片纯空白”的方案，而是：

- `TopBar` 保持贴顶
- `TabBar` 保持贴底
- 中间新增高度主要分配给：
  - `ContentPanel`
  - `LogArea`

这意味着：

- 长屏下上下不会出现明显的整块留边
- 但核心面板（属性面板、小人、突破面板）仍尽量维持原构图节奏
- 允许列表区、日志区、空白承载区按比例变高

### 3. 去掉主界面错误的二次字号缩放

此前 `GameUI.gd` 会按 `screen_width / 720.0` 再做一轮字号放大，这会和项目级缩放叠加，导致不同设备下主界面比例漂移。

现在规则改为：

- 主界面常驻字号回归固定设计值
- 只有少数真正需要响应视口变化的弹窗，才按可用区域做局部适配

### 4. 弹窗安全区适配

当前以下弹窗已经改成“按安全区后的可用尺寸居中计算”：

- 术法详情弹窗
- 顶部账号编辑弹窗（昵称 / 头像）

对应位置：

- [SpellDetailPopup.gd](/Users/hsams/Documents/idle_cultivation_project/idle_cultivation_client/scripts/ui/modules/SpellDetailPopup.gd)
- [ProfileEditPopup.gd](/Users/hsams/Documents/idle_cultivation_project/idle_cultivation_client/scripts/ui/modules/ProfileEditPopup.gd)

### 5. 当前内视页微调

近期还做了两项构图微调：

- 修炼页属性面板和 `NeishiTabBar` 之间补出固定距离
- 中间修炼小人素材组整体缩小约 10%，中心点位置保持不变
- 修炼小人中间文字已改为直接写入素材图片，避免控件缩放时文字与人物不同步

对应位置：

- [Main.tscn](/Users/hsams/Documents/idle_cultivation_project/idle_cultivation_client/scenes/app/Main.tscn)

### 6. 全局字体与符号统一

为解决 Android / APK 上中文标点、图标和字体回退不稳定的问题，当前已经统一为：

- 内置中文字体资源
- 内置 SVG 图标资源

不再依赖系统 emoji 或系统中文字体回退。

## 哪些区域允许吃掉长屏新增空间

### 主界面核心区

以下区域默认保持主构图，不随长屏额外高度自由拉大：

- 顶部栏内容
- 内视页属性面板
- 内视页修炼小人
- 内视页突破面板
- 底部主 Tab

### 可伸缩页面

以下页面允许多吃一部分空间，但主要是“列表 / 滚动区 / 空白区”变高：

- 储纳
- 设置
- 历练选择页
- 百草山采集页
- 炼丹坊

规则是：

- 列表、滚动容器、日志区域可以更高
- 单卡片、主按钮、标题栏、详情面板不随长屏任意拉长

## 当前人工验收工具

### 调试场景

- 场景路径：[ResolutionPreview.tscn](/Users/hsams/Documents/idle_cultivation_project/idle_cultivation_client/scenes/debug/ResolutionPreview.tscn)
- 脚本路径：[ResolutionPreview.gd](/Users/hsams/Documents/idle_cultivation_project/idle_cultivation_client/scripts/ui/debug/ResolutionPreview.gd)

### 作用

该场景用于人工检查以下目标分辨率下的 UI 观感：

- `1080×1920`
- `1080×2400`
- `1125×2436`

它只服务于调试预览：

- 从该场景进入时，可切换预设分辨率
- 正常从登录页 / 主项目入口运行时，不会触发窗口改尺寸逻辑

### 使用方式

1. 在 Godot 中打开 [ResolutionPreview.tscn](/Users/hsams/Documents/idle_cultivation_project/idle_cultivation_client/scenes/debug/ResolutionPreview.tscn)
2. 使用“运行当前场景”
3. 左上角点击要预览的分辨率按钮
4. 在该预览环境内继续登录并检查主界面、弹窗、列表页

如果需要观察真实外部运行窗口尺寸变化：

- 编辑器设置中把运行窗口嵌入模式切为 `Disabled`

## 当前人工验收清单

### 基准屏：`1080×1920`

- 主界面整体观感应接近原 720×1280 设计稿的 1.5 倍
- 顶部栏、内视页属性面板、小人、突破面板、日志框、底部 Tab 相对位置不应发散

### 长屏：`1080×2400`

- `TopBar` 必须贴顶，`TabBar` 必须贴底
- 日志区与内容承载区允许变高
- 主界面核心按钮、文字和面板相对位置应基本不变
- 不应出现“整体拉空”或上下大块留边的观感

### iPhone 刘海 / 灵动岛：`1125×2436`

- 顶部昵称、境界、灵石等信息不得压到安全区危险边缘
- 底部 Tab 不得压到 Home Indicator
- 弹窗应在安全区内居中

## 页面抽查列表

- 登录页
- 主界面内视页
- 储纳页
- 设置页
- 历练选择页
- 炼丹坊
- 术法详情弹窗
- 改昵称 / 头像弹窗

## 当前结论

当前项目已经具备：

- 统一的设计基线
- 主界面长屏预览工具
- `TopBar` / `TabBar` 贴边、`ContentPanel` / `LogArea` 动态伸缩的长屏策略
- 基础的长屏人工预览工具

但还没有形成标准化的 UI 自动化验收流程，现阶段长屏/异形屏仍以人工验收为主。
