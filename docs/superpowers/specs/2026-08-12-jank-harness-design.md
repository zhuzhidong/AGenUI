# AGenUI Harmony 卡顿/丢帧测试设计

- 日期：2026-08-12
- 范围：`playground/harmony`
- 方案：B（结构型走 story 菜单 + 时序型独立可见页 + 共享 FPS 覆盖层）

## 1. 背景与目标

`playground/harmony` 已有 `stability/` 压力测试框架，但它针对崩溃/健壮性，且 `StabilityTestAbility` 不挂 `AGenUIContainer`——屏幕上看不到渲染内容，无法直观观察丢帧。

本设计构建一套**交互式可见**的卡顿/丢帧示例：

- 肉眼可见画面卡顿；
- 屏幕实时显示 FPS / 平均帧时 / 丢帧数；
- 覆盖结构型（声明式 JSON 树）与时序型（ArkTS 驱动行为）两类卡顿源。

## 2. 卡顿原因分类

| 类型   | 病因                                                                    | 载体                                         |
| ------ | ----------------------------------------------------------------------- | -------------------------------------------- |
| 结构型 | 组件树本身大/深/过度绘制/载荷大 → layout/diff 慢                        | JSON story（树即病因）                       |
| 时序型 | 主线程阻塞、高频刷新、过密分块、setTimeout 动画、surface 抖动、内存抖动 | ArkTS 驱动器（基准小画面为画布，驱动即病因） |

关键区别：结构型 JSON 越大越卡；时序型基准 JSON 故意很小、本该流畅，卡顿来自 ArkTS 驱动。

## 3. 架构

两个可见出口，共享一个 FPS 组件：

```txt
playground/harmony/entry/src/main/
├── resources/rawfile/stories/A2UI Show/Jank/        ← 结构型（纯 JSON，进菜单）
│   ├── MassiveTree/updateComponents.json
│   ├── DeepNesting/updateComponents.json
│   ├── Overdraw/updateComponents.json
│   └── HugePayload/updateComponents.json
├── ets/components/
│   └── FpsOverlay.ets            ← 共享，displaySync 驱动的帧率覆盖层
├── ets/performance/               ← 新目录
│   ├── JankTestPage.ets          ← @Entry，时序型可见页
│   ├── JankScenarioEngine.ets    ← 时序坏行为驱动器集合
│   └── jankStories.ets           ← 基准画面 + 时序页私有 JSON 常量（.ets 以匹配工程约定）
└── resources/base/profile/main_pages.json           ← 加 pages/JankTestPage
```

- **结构型**：4 个 `updateComponents.json` 放进 story 目录，`AGenUIDemoPage` 菜单自动出现 "Jank" 分类。顶栏加 `📊 FPS` 开关，开启后挂 `FpsOverlay`，结构型卡顿也带帧率。
- **时序型**：新 `JankTestPage`（`@Entry`），自有 `SurfaceManager` + 可见 `AGenUIContainer` 渲染基准画面 + 场景按钮 + `FpsOverlay`。从 `AGenUIDemoPage` 顶栏加入口按钮，用 ArkUI `router.pushUrl('pages/JankTestPage')` 跳转，无需新 Ability。

## 4. 组件职责

| 组件                  | 职责                                                                                                                                 | 依赖                         |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------- |
| `FpsOverlay`          | 订阅 `displaySync.on('frame')`，每 500ms 算 FPS / 平均帧时 / 丢帧数，`@State` 渲染半透明小面板；`off('frame')` 于 `aboutToDisappear` | `@ohos.graphics.displaySync` |
| `JankScenarioEngine`  | 持有 `SurfaceManager` + `context`，暴露 `run(name)`/`stop()`；每场景一方法，循环型用可中止 `setInterval`                             | `@agenui/agenui`             |
| `JankTestPage`        | 装配基准 surface、按钮列表、`FpsOverlay`；把 engine 运行态绑到 `@State`（场景名/是否运行/错误）                                      | 上面两个                     |
| `AGenUIDemoPage` 改动 | 顶栏加 `📊 FPS` Toggle（条件挂 `FpsOverlay`）+ "Jank Lab" 入口按钮                                                                   | `FpsOverlay`                 |

## 5. 数据流（时序页）

```txt
aboutToAppear
  → new SurfaceManager + createSurface('jank-baseline') + 推基准 JSON
  → AGenUIContainer 绑定 'jank-baseline'（可见）
  → FpsOverlay 开始计帧

用户点 [MainThreadBlock]
  → engine.run('MainThreadBlock')
  → setInterval(100ms) busy-wait 50ms（可中止）
  → 基准画面掉帧 → FpsOverlay 显示 FPS 掉、丢帧++

用户点 [Stop] / 切换场景
  → engine.stop()（clearInterval）
  → 可选：重置基准 surface
```

## 6. FPS 采集

- `displaySync.create()` 拿 `DisplaySync` 实例，`setExpectedFrameRateRange({min:0, max:120, expected:60})`。
- `on('frame', cb)`：把 `timestamp` 推进滚动窗口。
- 每 500ms 聚合：`fps = 窗口内回调数 / 秒`；`avgFrameTime = Δtimestamp 均值`；`dropped = Δtimestamp > 1.5×期望帧间隔 的次数`。写回 3 个 `@State`，overlay 重绘。
- 准确性依据：主线程阻塞时 `on('frame')` 回调本身不按时触发（跑在主线程调度上），回调间隔直接反映主线程真实卡顿，即"应用层体感帧率"。
- 生命周期：`aboutToAppear` 注册，`aboutToDisappear` 必 `off('frame')`；切后台同理。

## 7. 场景清单

### 7.1 结构型（JSON story，4 个）

放 `playground/resource/stories/A2UI Show/Jank/<Name>/updateComponents.json`。组件只用 Text/Column/Row（无媒体资源依赖）。

> **同步机制待确认**：仓库中 `playground/resource/stories/`（跨平台 canonical 源）与 `playground/harmony/entry/src/main/resources/rawfile/stories/`（DevEco 运行时实际读取）是两份 git 跟踪的副本，未发现自动同步脚本（比对 List story 显示 rawfile 副本已落后于 resource 源）。实现时需把 4 个 JSON 写入 resource 源**并**复制到 harmony rawfile，或先确认/建立同步脚本。

| Story         | 卡顿机理                                        | 规模                               |
| ------------- | ----------------------------------------------- | ---------------------------------- |
| `MassiveTree` | 扁平大宽表，一次挂载触发大量 measure/layout     | 1 个 Column + 500 个 Text          |
| `DeepNesting` | 嵌套深，layout 自顶向下递归代价高               | Column 嵌 30 层，每层 3 个 Text    |
| `Overdraw`    | 多层半透明 Stack 叠加，每像素反复合成           | 20 层 Stack 半透明背景 + 1 个 Text |
| `HugePayload` | 单条 `updateComponents` 载荷过大，parse+diff 慢 | 1 个 Text 的 `text` 塞 ~200KB      |

每个文件 `version: v0.9` + `updateComponents`，参照现有 List story 结构。

### 7.2 时序型（ArkTS，6 个，JankTestPage 按钮）

每个循环型场景跑到用户按 **Stop**；`engine.stop()` 清所有句柄。

| 场景                  | 坏行为驱动器                                                 | 基准画面现象   |
| --------------------- | ------------------------------------------------------------ | -------------- |
| `MainThreadBlock`     | `setInterval(100ms)` 内 `while(Date.now()<end){}` 跑 50ms    | 周期性冻结     |
| `StateChurn`          | `setInterval(5ms)` 调 `syncState` 刷同一值                   | 列表闪烁/抖动  |
| `TinyChunkStream`     | `receiveTextChunk` 把基准 JSON 切 500 个 ~40 字节小块连推    | 渲染抖动、闪屏 |
| `SetTimeoutAnimation` | `setInterval(16ms)` 改 `@State` 移动方块 vs `animateTo` 对照 | 前者掉帧后者顺 |
| `SurfaceThrash`       | 循环 `createSurface`→`deleteSurface`                         | 画面闪退重建   |
| `MemoryChurn`         | `setInterval` 每轮分配 5MB 数组再丢                          | 周期性 GC 卡顿 |

## 8. 基准画面（时序页画布）

- `surfaceId: jank-baseline`，内容：一个 Column，含一个 `animateTo` 匀速往返色块 + 下方 10 项 List。
- 纯 AGenUI JSON，内联在 `jankStories.ets` 常量，**不进 story 菜单**（私有画布，非浏览 demo）。
- 本身顺滑；时序坏行为作用其上（阻塞主线程 / 高频刷其 state / 对它过密分块）→ 看它变卡。
- `SetTimeoutAnimation` 例外：自带方块，对比的是"驱动方式"。

## 9. 错误处理

- `JankScenarioEngine.run(name)`：未知 name → `hilog.warn` + 返回，不崩。
- 每场景 `try/catch`：异常 → 记 `lastError` 到 `@State`，overlay 状态栏显红 `ERR:xxx`（沿用 `StabilityTestPage` 状态色约定），不冒泡。
- `stop()` 幂等：多次调用安全；所有 `setInterval` 句柄集中存数组，统一清。
- `aboutToDisappear`：强制 `engine.stop()` + `surfaceManager.destroy()` + `FpsOverlay.off('frame')`，三件套防泄漏。
- `TinyChunkStream` / `SurfaceThrash` 加最大轮次上限（2000 次）兜底，防用户忘 Stop 把页面搞死。

## 10. 测试

- **结构型**：无单测（纯 JSON 数据）。加 `ohosTest` 冒烟：逐个读 4 个 JSON 断言 `version===v0.9` 且 `components.length` 符合预期。
- **时序型**：`JankScenarioEngine` 纯逻辑（句柄管理、上限计数、未知 name 返回）做 hypium 单测；`displaySync`/`SurfaceManager` 真实交互不在单测覆盖。
- **手测验收清单**：每个时序场景点开 → FPS 明显下降/丢帧上升；Stop → FPS 回升。4 个结构型 story 点开 → FPS 下降。
- **回归**：`AGenUIDemoPage` 加的 FPS 开关和入口按钮不破坏现有 story 流程（手测一遍现有菜单）。

## 11. 不做（YAGNI）

- 不做无人值守自动化跑分出报告（如需后续可复用 `JankScenarioEngine` + 仿 `StabilityTestAbility` 扩展）。
- 不做全局悬浮 FPS（随页面生命周期销毁即可）。
- 不做卡顿强度可调滑块（场景参数固定；如需再加）。
- 不引入新第三方依赖。
