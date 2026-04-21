# 客户端文档总览

本目录描述 **当前客户端现状**（服务端权威模式），用于联调、维护与后续重构。

## 阅读顺序

1. [客户端定位与边界](./01-overview/ClientPositioning.md)
2. [核心体验不变项](./01-overview/CoreExperienceInvariants.md)
3. [代码结构与边界](./01-overview/CodeStructureAndBoundaries.md)
4. [模块文档](./02-modules/01-login-init.md)
5. [测试与联调](./03-testing/GUT_API_Testing.md)
6. [维护规范](./04-maintenance/SlimmingAndContracts.md)

## 术语约定

- `reason_code`：服务端返回的稳定业务语义码。
- `reason_data`：客户端拼装文案与展示所需的结构化数据。
- 乐观更新：客户端先行更新本地展示，后续再上报或全量同步。
- 预扣池：炼丹每次开炉后，本地先预扣当前轮次材料/灵气。
- 回放：历练按服务端返回的战斗时间轴进行本地 UI 播放。
- 字体/图标真值：客户端 UI 文本使用内置字体资源，常用图标使用客户端内置 SVG，不依赖系统 emoji 或系统中文字体回退。
- 安全区内容区：主界面逻辑设计基线固定为 `720×1280`，长屏/异形屏只把多余空间分配给安全区背景与少量可伸缩容器，不重新拉大核心构图。

## 模块导航

- [登录与初始化](./02-modules/01-login-init.md)
- [修炼与突破](./02-modules/02-cultivation-breakthrough.md)
- [储纳（背包）](./02-modules/03-inventory.md)
- [术法](./02-modules/04-spell.md)
- [炼丹](./02-modules/05-alchemy.md)
- [历练](./02-modules/06-lianli.md)
- [设置与通用提示](./02-modules/07-settings-common.md)
- [百草山采集](./02-modules/08-herb-gathering.md)

## 测试入口

- 客户端统一入口：`./run_tests.sh`
- 默认 API 基址：`http://localhost:8444/api`
- 测试账号：`test / test123`
- 分辨率 / 长屏人工预览场景：`res://scenes/debug/ResolutionPreview.tscn`

详见：[客户端 GUT API 化测试说明](./03-testing/GUT_API_Testing.md)

## UI 与分辨率验收

- [长屏 / 异形屏人工验收与预览工具说明](./03-testing/UI_Resolution_Manual_Checklist.md)
- [UI 自动化测试规划建议](./03-testing/UI_Automation_Roadmap.md)

## UI 模板索引

- [UI 模板索引（TabBar / 展示面板 / 术法缩略卡 / 弹窗）](./04-maintenance/UI_Templates_Index.md)
