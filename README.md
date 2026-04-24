# 修仙挂机客户端（Godot 4）

服务端权威模式下的 Godot 客户端项目。  
当前核心体验以真实 API 为准，客户端保留必要的展示、乐观更新和流程编排逻辑。

## 当前关键约束

- 修炼的乐观 `pending/flush` 链路保留
- 炼丹预扣池与停火汇总链路保留
- 历练按服务端返回时间轴进行播放回放
- 业务提示文案由客户端按 `reason_code + reason_data` 映射生成

## 目录总览

```text
idle_cultivation_client/
├── scenes/
├── scripts/
│   ├── autoload/
│   ├── core/
│   │   ├── alchemy/
│   │   ├── cultivation/
│   │   ├── inventory/
│   │   ├── lianli/
│   │   └── spell/
│   ├── managers/
│   ├── network/
│   └── ui/
│       ├── login/
│       └── modules/
├── tests_gut/
│   ├── support/
│   ├── unit/
│   └── integration/
└── docs/
    ├── 01-overview/
    ├── 02-modules/
    ├── 03-testing/
    ├── 04-maintenance/
    └── todo/
```

## 本地运行

1. 安装 Godot 4.6（或兼容 4.x）
2. 打开 `project.godot`
3. 运行主场景（`scenes/app/Main.tscn`）

## 测试入口（统一）

在项目根目录执行：

```bash
./run_tests.sh
```

说明：
- 脚本会自动探测 `godot4` / `godot` / macOS app 路径
- 统一跑 `tests_gut` 全量（含 unit + integration）
- 兼容入口 `./tests_gut/run_gut_tests.sh` 仅做转发

更多测试细节见 `tests_gut/README.md`。

## 相关文档

- 第一次接手这个项目，建议先看 `docs/快速开发手册.md`
- `docs/todo/瘦身计划.md`：客户端瘦身实施记录与约束
