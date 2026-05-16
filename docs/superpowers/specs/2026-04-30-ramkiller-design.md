# BeagleX — Design Spec

**Date**: 2026-04-30
**Author**: a77 (with Claude)
**Status**: Draft → awaiting user review
**Bundle ID**: `com.vannaq.beaglex`
**Distribution**: 自用（Personal use only — 无 codesigning / notarize 要求）

---

## TL;DR

BeagleX 是一款 macOS 菜单栏 + 主窗口应用，整合 RAM 实时监控、进程管理、自动化告警、缓存清理、大文件查找、应用卸载、启动项管理等功能。目标是替代日常用户手工跑 `vm_stat` / `ps` / `sudo purge` 的工作流，并提供 CleanMyMac 风格的可视化交互。仅用于自用，**不上架 App Store**，因此可使用沙盒禁止的特权 API（`sudo purge`、跨进程 `kill`、清理用户缓存等）。

---

## Goals

1. **取代命令行工作流** — 监控 RAM、找凶手进程、kill、purge 全部 GUI 化
2. **后台守护** — 关闭主窗口后菜单栏继续监控 + 阈值告警
3. **CleanMyMac 同类清理能力** — 缓存、大文件、应用卸载、启动项
4. **数据驱动的"凶手时段"分析** — 长期持久化进程/内存快照
5. **安全的特权操作** — 通过 SMAppService daemon + XPC 白名单严格隔离 root 权限

## Non-Goals

- 不做付费授权 / 试用机制（自用）
- 不做远程 / 云端同步（仅本机 SwiftData）
- 不做内存"魔法清理"假动作 —— 实际能做的就是 `purge` + `kill`，不夸张宣传
- 不上架 App Store（沙盒会废掉核心功能）
- 不做 iOS / iPadOS 版

---

## Tech Foundation

| 维度 | 决定 |
|---|---|
| 最低 macOS 版本 | macOS 14.4 (Sonoma) + （SwiftData 早期版本有 bug，14.4+ 较稳）|
| 菜单栏实现 | SwiftUI `MenuBarExtra` |
| 主 UI 框架 | SwiftUI |
| 数据持久化 | SwiftData（macOS 14 原生）|
| 特权操作架构 | `SMAppService.daemon` + XPC bridge |
| UI 风格 | Apple 原生（List、Form、SF Symbols）|
| 本地化 | 中文 + 英文（`Localizable.xcstrings`） |
| 开机启动 | 默认开（设置可关），通过 `SMAppService.mainApp` 注册 |
| 后台行为 | 关主窗口不退出 app；菜单栏图标持续 |
| 名称 / Bundle ID | BeagleX / `com.vannaq.beaglex` |

---

## App Architecture

### 进程模型

```
┌─────────────────────────────────────┐
│   BeagleX.app                     │
│   (Main Process, sandbox=false)     │
│                                      │
│  ┌──────────┐    ┌─────────────┐   │
│  │ MenuBar  │    │ Main Window │   │
│  │  Extra   │    │  (Sidebar + │   │
│  │          │    │   Content)  │   │
│  └──────────┘    └─────────────┘   │
│        │                │           │
│  ┌─────▼────────────────▼───────┐  │
│  │  Services Layer              │  │
│  │  - MemoryService             │  │
│  │  - ProcessService            │  │
│  │  - DatabaseService           │  │
│  │  - HelperBridge (XPC client) │  │
│  └──────────┬───────────────────┘  │
└─────────────┼───────────────────────┘
              │ XPC (Mach service)
              ▼
┌──────────────────────────────────────┐
│  com.vannaq.beaglex.helper         │
│  (Privileged daemon, runs as root)   │
│  - SMAppService.daemon registered    │
│  - 仅接受白名单命令                   │
│  - purge / kill / unload-daemon ...  │
└──────────────────────────────────────┘
```

### 模块 / 文件结构

```
BeagleX.xcodeproj/
├── BeagleX/                         (Target 1: 主 app)
│   ├── App/
│   │   ├── BeagleXApp.swift        @main, MenuBarExtra + WindowGroup
│   │   └── AppDelegate.swift         启动初始化、helper 安装检查
│   ├── Core/
│   │   ├── Models/                   SwiftData @Model
│   │   ├── Services/                 MemoryService, ProcessService, ...
│   │   └── Extensions/
│   ├── Features/
│   │   ├── Monitoring/               P1
│   │   ├── Processes/                P2
│   │   ├── Automation/               P3
│   │   ├── CacheCleaner/             P4
│   │   ├── LargeFiles/               P5
│   │   ├── Uninstaller/              P6
│   │   └── LaunchItems/              P7
│   ├── UI/
│   │   ├── Sidebar/
│   │   ├── MenuBar/
│   │   └── Components/
│   ├── Resources/
│   │   ├── KnowledgeBase/cleaners.json   P4 内置清理目录列表
│   │   ├── Localizable.xcstrings
│   │   └── Assets.xcassets
│   └── Info.plist
│
├── BeagleXHelper/                   (Target 2: 特权 helper)
│   ├── main.swift                    XPC server 入口
│   ├── HelperService.swift           白名单命令分发
│   ├── Operations/
│   │   ├── PurgeOperation.swift
│   │   ├── KillOperation.swift
│   │   └── LaunchItemOperation.swift
│   └── Helper.entitlements
│
└── Shared/                            (Target 3: SPM Package, app + helper 共用)
    ├── XPCProtocol.swift             @objc protocol HelperProtocol
    ├── HelperCommand.swift           Codable 命令枚举
    └── HelperResult.swift            Codable 结果类型
```

### XPC 协议（安全核心）

Helper 仅接受以下命令枚举，**任何不在白名单的请求直接拒绝**。路径在 helper 端做二次校验，不信任 app 端。

```swift
public enum HelperCommand: Codable {
    case purgeMemory
    case killProcess(pid: Int32, signal: Int32)         // signal ∈ {SIGTERM, SIGKILL}
    case unloadLaunchAgent(label: String)
    case loadLaunchAgent(label: String)
    case removeLaunchPlist(path: String)                // 路径必须在 /Library/LaunchDaemons/ 或 /Library/LaunchAgents/
    case deleteFile(path: String)                       // 路径必须在 ~/Library/Caches、~/Library/Application Support 等白名单根下
}

public enum HelperResult: Codable {
    case success(payload: Data?)
    case denied(reason: String)
    case failed(error: String)
}
```

### 主窗口导航

侧边栏 + 内容区（macOS 原生 `NavigationSplitView`）：

```
┌──────────────┬──────────────────────────────┐
│ 🧠 内存监控   │                              │
│ 🔪 进程管理   │                              │
│ 🤖 自动化     │      Content View            │
│ 🗑️ 缓存清理   │      (随选中类目变化)          │
│ 📦 大文件     │                              │
│ 🚮 卸载器     │                              │
│ 🚀 启动项     │                              │
│ ─────        │                              │
│ ⚙️ 设置       │                              │
└──────────────┴──────────────────────────────┘
```

### 菜单栏下拉

`MenuBarExtra` 触发后展开一个紧凑视图：

```
┌──────────────────────────────┐
│ Used     28.3 GB / 36 GB    │
│ Unused    7.5 GB    🟢 OK    │
│ Compress  6.1 GB             │
│ Pressure  Green              │
│ ──────────────────────────── │
│ 🧹 Purge Memory   (60s 冷却) │
│ 🔪 Open Process List         │
│ ──────────────────────────── │
│ Show Main Window             │
│ Quit BeagleX               │
└──────────────────────────────┘
```

菜单栏图标：动态显示当前 RAM 使用百分比的 1-2 字符（如 `78%` 或彩色条），随压力等级变色。

---

## Data Model (SwiftData)

```swift
@Model
final class MemorySnapshot {
    var timestamp: Date            // index
    var usedBytes: Int64
    var unusedBytes: Int64
    var compressorBytes: Int64
    var wiredBytes: Int64
    var activeBytes: Int64
    var inactiveBytes: Int64
    var swapInPagesPerSec: Double
    var swapOutPagesPerSec: Double
    var pressureLevel: Int         // 0=green, 1=yellow, 2=red
}

@Model
final class ProcessSnapshot {
    var timestamp: Date
    var pid: Int32
    var name: String
    var bundleId: String?
    var rssBytes: Int64
    var cpuPercent: Double
    var elapsedSeconds: Int64
}

@Model
final class AlertEvent {
    var timestamp: Date
    var level: AlertLevel          // warning / critical / emergency
    var trigger: String            // "unused < 800MB for 30s"
    var resolvedAt: Date?
    var userActionTaken: String?   // "purged", "killed PID 1234", "ignored"
}

@Model
final class UserAction {
    var timestamp: Date
    var actionType: String         // "purge", "kill", "clean_cache", "uninstall", ...
    var targetIdentifier: String?  // PID, app bundle ID, cache id, etc.
    var bytesFreed: Int64?
    var success: Bool
    var error: String?
}
```

**保留策略**：

| 表 | 频率 | 保留 | 估算大小 |
|---|---|---|---|
| `MemorySnapshot` | 每 2s | 24h 滚动 | ~5 MB/天 |
| `ProcessSnapshot` | 每 60s, Top 30 | 24h 滚动 | ~3 MB/天 |
| `AlertEvent` | 事件触发 | 永久 | 极小 |
| `UserAction` | 用户操作 | 永久 | 极小 |

后台任务每小时执行一次过期清理。

---

## Phase Specs

### Phase 0 — Scaffolding（2-3 天）

**目标**：可运行的 app，菜单栏 + 主窗口框架已就绪，但所有功能页面是占位符。

**Deliverables**：

- Xcode 项目（3 target：app / helper / shared package）创建
- App entitlements 配置（无沙盒；helper 单独 entitlements）
- `BeagleXApp.swift` 实现 `MenuBarExtra` + `WindowGroup`
- 主窗口 `NavigationSplitView` 骨架（8 项侧边栏 + 设置项）
- 每个 Phase 对应 placeholder 页面（"Coming in Phase X"）
- 菜单栏弹出占位下拉
- 本地化基础设施（zh + en `Localizable.xcstrings`）
- Login Item 注册（默认开）
- 关闭主窗口不退出（菜单栏继续）
- 最小可用"设置"页（仅含"开机启动"开关 + 关于）。后续每个 Phase 在此页追加自己的设置区块。

**Out of scope**：实际数据、helper 安装、任何"清理"能力。

**Acceptance**：双击运行，菜单栏图标可见，主窗口可开关，关窗后菜单栏仍在。

---

### Phase 1 — Memory Monitoring（5-7 天）

**目标**：实时监控 RAM，替代命令行 `vm_stat` + `top` 工作流。

**Deliverables**：

- `MemoryService`：包装 `host_statistics64` + `vm_stat`，每 2s 采样并写 `MemorySnapshot`
- `ProcessService`：包装 `proc_listpids` + `proc_pidinfo`，每 60s 采 Top 30 写 `ProcessSnapshot`
- 数据库后台过期清理任务（24h 滚动）
- 菜单栏图标：动态显示 RAM 使用 %（数字或图形 bar）
- 菜单栏下拉：实时数值 + Pressure 等级 + Top 5 进程
- 主窗口 → 内存监控页：
  - 顶部 4 个 stat 卡片（Used / Unused / Compressor / Pressure）
  - 堆叠面积图（最近 1h Used/Unused/Compressor，可拖动到 24h）
  - Memory Pressure timeline（绿/黄/红着色背景）
  - Swap In/Out 速率折线图
  - "高级模式"开关 → 展开 Wired / Active / Inactive / Speculative 拆分
- 主窗口 → 进程管理页（仅展示）：
  - 列表显示 Top 30，可切到全量 + 搜索
  - 列：图标 / Name / PID / RSS / CPU% / 跑了多久 / User
  - 点击行 → 右侧详情面板（cmdline、cwd、打开的 jsonl、子进程数）

**Out of scope**：kill 按钮（在 Phase 2）、告警通知（Phase 3）、purge 按钮（Phase 2）。

**Acceptance**：能像今天我们用命令行一样查看任意时刻的内存状态和进程列表。

---

### Phase 2 — Actions: Kill + Purge（5-7 天，含 SMAppService 大坑）

**目标**：可执行 `kill` 和 `purge` 操作。这是技术风险最高的 Phase（特权 helper 安装、XPC 通信、entitlements）。

**Deliverables**：

- `BeagleXHelper` target 完整实现
  - `main.swift`：注册 XPC 服务
  - `HelperService.swift`：分发命令，命令白名单 + 路径白名单二次校验
  - `Operations/PurgeOperation.swift`：执行 `purge` 命令（system call）
  - `Operations/KillOperation.swift`：`kill(pid, signal)`，仅允许 SIGTERM/SIGKILL
- `Shared` package 实现 `HelperProtocol` 协议
- `HelperBridge`：app 端 XPC 客户端
  - 启动时检查 `SMAppService.daemon(...).status`
  - 未安装 → 弹安装授权对话框（一次性）
  - 已安装但版本不匹配 → 自动 update
- 进程列表加 ❌ Kill 按钮：
  - 用户进程：直接 `kill(SIGTERM)` 不需 helper
  - 系统进程（root / `_*` 用户）：通过 helper
  - 长按 / 右键 → "Force kill (SIGKILL)"
  - 一律弹确认对话框
- 主窗口顶部 + 菜单栏下拉都加 🧹 **Purge Memory** 按钮
  - 60 秒冷却（按钮变灰显示倒计时）
  - 操作记录到 `UserAction` 表
- "智能推荐 Banner"（Q17）：
  - 检测条件：CPU=0 持续 5min + RSS > 100MB + 非系统 user
  - 主窗口"内存监控"页面顶部弹 banner："发现 N 个长期闲置高内存进程"
  - "查看推荐 → 全选 → 一键 kill"

**风险点**：

- SMAppService 注册失败 → 测试 fallback 到弹窗提示用户手动批准
- 首次安装 helper 必须用户在系统设置 → 后台项里手动启用，UI 引导文案要清晰
- Helper bundle 路径必须严格匹配 `Contents/Library/LaunchDaemons/<label>.plist`

**Out of scope**：自动 purge 触发（在 Phase 3）。

**Acceptance**：

- 能 kill 任意进程（含系统进程，首次需授权）
- 能一键 Purge（首次需授权）
- helper 通信日志可在主 app 调试视图看到

---

### Phase 3 — Automation + Persistence（5-7 天）

**目标**：后台守护 + 阈值告警 + 历史分析。

**Deliverables**：

- `NotificationService`：UserNotifications 包装
  - 三档告警（warning / critical / emergency，配置见 Q18）
  - 通知点击 → deep link 跳到对应主窗口面板
- 阈值检测引擎：
  - 持续监控最近 N 秒的 `MemorySnapshot`
  - 满足条件 → 创建 `AlertEvent` 并发通知
  - 通知去重（同一 alert 在 cool-down 内不重发）
- 设置页 → "自动化"分类：
  - 三档阈值都可调（默认 2GB / 800MB / swap activity）
  - 每档 cool-down 时长可调
  - "自动 Purge"开关（默认关）+ 触发等级 + 冷却
- "凶手时段"分析视图（主窗口"自动化"页）：
  - 过去 7/30 天的内存压力时段图（按小时聚合 pressure level）
  - "压力高峰常见进程"Top 10（基于 ProcessSnapshot 在 pressure>0 时段的累计）
  - 用户操作历史（purge / kill 时间线）
- AlertEvent 历史列表 + 每个事件展开详情（触发时的快照）

**Out of scope**：缓存清理、大文件、卸载器。

**Acceptance**：内存吃紧时能收到通知；能看到过去一周哪些时段最凶哪些进程最常出现。

---

### Phase 4 — Cache Cleaner（7-10 天）

**目标**：扫描并清理 macOS 上常见的可回收缓存目录。

**Deliverables**：

- 内置 `cleaners.json` 知识库（手工维护）：

```json
[
  {
    "id": "xcode_derived_data",
    "name": "Xcode DerivedData",
    "description": "Xcode 编译缓存，删除不影响项目",
    "category": "developer",
    "safety": "safe",
    "paths": ["~/Library/Developer/Xcode/DerivedData/*"]
  },
  {
    "id": "homebrew_cache",
    "name": "Homebrew Downloads",
    "category": "developer",
    "safety": "safe",
    "paths": ["~/Library/Caches/Homebrew/downloads/*"]
  }
  // ... 30+ 项预置
]
```

- 类目（Q23）：开发工具 / 浏览器 / 媒体 / 应用缓存 / 系统 / 废纸篓
- 每条目标注 safety: `safe` / `caution` / `risky`
- `ScannerService`：
  - 异步并行扫描（每个 cleaner 一个 task）
  - 每个 cleaner 算总 bytes（递归 file size）
  - 进度条 + 取消支持
- 清理 UI：
  - 类目折叠列表，每条目显示 size + safety badge
  - 默认勾选所有 `safe`，`caution` / `risky` 默认不勾、需展开
  - 总览预估"将释放 X.X GB"
  - "Clean" 大按钮 → 二次确认 → 删除（系统级路径走 helper）
  - 删除完成 → 实际释放 vs 预估对比 + 写 UserAction
- 浏览器 cache 单独逻辑（不动 cookies/history，只清 `~/Library/Caches/Google/Chrome` 和 `~/Library/Caches/com.apple.Safari/...`）
- 废纸篓清空通过 `NSFileManager` 标准 API

**Out of scope**：远程更新知识库、用户自定义 cleaner。

**Acceptance**：能扫出 5GB+ 可清缓存，删除后磁盘空间确实释放。

---

### Phase 5 — Large Files + Duplicates（7-10 天）

**目标**：找出并清理大文件和重复文件。

**Deliverables**：

- `LargeFileScanner`：
  - 默认范围：`~/Downloads`、`~/Documents`、`~/Movies`、`~/Desktop`
  - 用户可拖入 / 移除
  - 阈值默认 100 MB（用户可改 50/200/500/1G）
  - 优先用 `MDQuery` Spotlight 取候选（秒级返回），fallback 全 walk
- `DuplicateScanner`：
  - 阶段 1：按 size 分桶
  - 阶段 2：同 size 桶内每文件取前 4 KB SHA-256 quick-hash
  - 阶段 3：quick-hash 一致再做全文件 SHA-256
  - 仅对 > 1 MB 文件做重复检测
- 大文件 UI：
  - 列表（按 size 倒序）
  - 列：缩略图 / 文件名 / 路径 / 大小 / 修改时间
  - 多选 → "Delete N files (X.X GB)"
- 重复文件 UI：
  - 分组列表（每组多个文件）
  - 默认保留**最早创建**的那份，其他打勾建议删
  - 用户可调整保留哪一份
  - "Delete duplicates (X.X GB freed)"
- 删除支持发到废纸篓（默认）或永久删除（用户主动选）

**Out of scope**：内容预览（图片/视频缩略图除外）。

**Acceptance**：能找出 ~/Downloads 下所有 > 100MB 文件；能识别重复的视频/iso/zip。

---

### Phase 6 — App Uninstaller（7-10 天）

**目标**：卸载 app 时同步清理散落在系统各处的残留。

**Deliverables**：

- `AppDiscoveryService`：扫 `/Applications` + `~/Applications`，列出所有 .app
- `LeftoverScanner`：
  - 给定 bundle.id 和 app name，扫描以下路径：
    - `~/Library/Application Support/<app>` / `<bundle.id>`
    - `~/Library/Caches/<bundle.id>` / `<app>`
    - `~/Library/Preferences/<bundle.id>.plist`
    - `~/Library/Logs/<app>` / `<bundle.id>`
    - `~/Library/Containers/<bundle.id>`
    - `~/Library/Group Containers/group.<bundle.id>`
    - `~/Library/HTTPStorages/<bundle.id>*`
    - `~/Library/Saved Application State/<bundle.id>.savedState`
    - `~/Library/LaunchAgents/*<bundle.id>*.plist`
    - `/Library/LaunchDaemons/*<bundle.id>*.plist`
- 卸载 UI：
  - 左侧应用列表（按 size / 名称排序）
  - 右侧详情：图标 + 版本 + 路径 + 占用空间
  - "Find Leftovers" → 列出所有匹配路径 + 大小
  - 用户勾选要删的路径（默认全选）
  - "Uninstall + Clean N items (X.X GB)" 按钮
  - 二次确认 → 删除（系统级路径走 helper）
- 拖拽区：拖入任意 .app → 自动跳到对应详情
- 防护：
  - 内置黑名单：苹果系统 app（Finder.app、Safari.app、Mail.app 等）
  - 检测 app 是否运行 → 提示先退出
  - 删除前列出**所有路径** + 二次确认

**Out of scope**：app 卸载前自动备份残留。

**Acceptance**：卸载一个测试 app，发现并删除其在 ~/Library 各处的残留。

---

### Phase 7 — Launch Items Manager（5-7 天）

**目标**：统一管理所有"开机/登录后台启动"项。

**Deliverables**：

- `PlistService`：解析以下源：
  - **Login Items**: `SMAppService.loginItem`
  - **User LaunchAgents**: `~/Library/LaunchAgents/*.plist`
  - **System LaunchAgents**: `/Library/LaunchAgents/*.plist`
  - **System LaunchDaemons**: `/Library/LaunchDaemons/*.plist`
  - **Background Tasks (macOS 13+)**: 通过私有 API 或解析 `BackgroundTaskManagementAgent` 数据库
- 启动项 UI：
  - 分组列表：Login Items / User Agents / System Daemons / Background Tasks
  - 每行：图标 / Label / 路径 / 状态（运行中 / 已禁用）/ 来源 app（反查 bundle.id）
  - 标记 🟢 已知必要（系统苹果守护）⚠️ 第三方
- 操作：
  - **禁用**：`launchctl bootout` + 把 plist 移到 `*.disabled` 后缀（可逆）
  - **启用**：从 `*.disabled` 还原 + `launchctl bootstrap`
  - **删除**：永久移除 plist（不可逆，二次确认）
  - 系统级路径全部通过 helper
- 内置已知守护进程数据库（避免用户手贱禁用 cfprefsd 等核心服务）

**Out of scope**：editing plist 内容（只能启停 / 删除）。

**Acceptance**：能看到所有第三方启动项，能禁用 Adobe Updater / Microsoft AutoUpdate 等典型烦人项并恢复。

---

## Phased Delivery Summary

| Phase | 内容 | 周期 | 累计可用产品 |
|---|---|---|---|
| P0 | 脚手架 | 2-3 天 | app 能启动 |
| P1 | 监控 | 5-7 天 | 替代命令行 RAM 检查 |
| P2 | Kill + Purge | 5-7 天 | 完整动作能力 |
| P3 | 自动化 + 持久化 | 5-7 天 | 后台告警 + 历史分析 |
| P4 | 缓存清理 | 7-10 天 | 第一个 CleanMyMac-like 功能 |
| P5 | 大文件 / 重复 | 7-10 天 | 磁盘空间回收 |
| P6 | 卸载器 | 7-10 天 | app 残留清理 |
| P7 | 启动项 | 5-7 天 | 后台进程审计 |

**总计 ~7-8 周（业余 50% 投入）/ 2-3 周（全职）。**

---

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| SMAppService daemon 注册失败 | Phase 2 先做最小可行测试（写一个 Hello-XPC daemon 验证），失败再调整 |
| macOS 14 → 15+ API 变更打破代码 | 优先用稳定 framework；私有 API（如 Background Tasks 列表）做 try/catch fallback |
| Spotlight 索引不全（如新文件未索引）→ Phase 5 漏报 | fallback 走文件系统 walk，仅在用户主动"全量扫描"时触发 |
| 删除文件出 bug 误删用户重要数据 | 默认走废纸篓，永久删要主动勾；P4/P5/P6 全部走二次确认；helper 路径白名单严格 |
| 进程列表读取性能差（每 60s 全 ps 太重）| `proc_listpids` + 仅取 `proc_pidinfo` 基础字段；Top 30 排序在内存里做 |
| SwiftData 在 macOS 14.0/14.1 早期版本有 bug | 最低支持已锁定 14.4+；第一版上手时确认本机版本 |
| 知识库（cleaners.json）维护成本 | 第一版只放 30 条最常见，靠用户反馈扩展 |

---

## Open Questions

1. 菜单栏图标 RAM 使用 % 用**数字**还是**横条 / 圆环图标**？(建议 P0 实现两种 + 设置切换)
2. P3 "凶手时段"图表精度（按小时还是按 5min 桶）？(建议小时，简单)
3. P4 浏览器缓存对 Chrome / Safari / Firefox / Edge / Arc 都做，还是只前 2 个？(建议先 Chrome + Safari，其他用户提需求再加)
4. P6 是否给 Setapp 安装的 app 特殊对待？（Setapp 有自己的卸载机制）

留 P0 实现时回答 #1；其他可在对应 Phase 开始前敲定。

---

## Acceptance for Whole Project

完成后能做到：

- [x] 不再打开 Terminal 跑 `vm_stat` / `ps` / `sudo purge`
- [x] 内存吃紧时收到通知
- [x] 看得到一周内的 RAM 压力凶手时段
- [x] 一键回收 5-10 GB 缓存空间
- [x] 找出 ~/Downloads 大文件清理
- [x] 卸载 app 时一并清掉残留
- [x] 看到 / 管理所有第三方启动项
