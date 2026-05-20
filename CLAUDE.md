# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

ClaudeCodeMonitor 是一款 macOS 菜单栏 + 桌面 widget 应用，用于监控 Claude Code 的使用统计。使用 SwiftUI + MenuBarExtra + WidgetKit 实现，读取 `~/.claude/` 目录下的本地数据文件，展示活动统计、Token 消耗、模型分布、项目排行和 API 配额。

## 构建与运行

```bash
# 一键构建（regenerate xcodeproj + xcodebuild Release + 拷贝到 build/）
./build.sh

# 或手工流程
xcodegen generate
xcodebuild -project ClaudeCodeMonitor.xcodeproj -scheme ClaudeCodeMonitor -configuration Release build
```

- 需要 macOS 14.0+，Xcode 16.0+，Swift 6.0+
- 需要 `brew install xcodegen`（v2.44+）
- **xcodeproj 不入库**：从 `project.yml` 由 xcodegen 生成，已在 `.gitignore`
- 签名配置在 `project.local.yml`（gitignored）— 第一次 clone 后 `cp project.local.example.yml project.local.yml` 填入自己的 Apple Dev cert / Team ID
- Widget Extension 必须用带 `TeamIdentifier` 的 cert，自签证书不行，见下面 "macOS 致命陷阱"
- 无第三方依赖，仅使用 Apple 框架（SwiftUI, Charts, WidgetKit, Network, Security, ServiceManagement）

## 架构核心

### 数据流

```
启动 / 菜单栏 onAppear / 后台 timer (30 min)
  ↓
SessionParser (session JSONL 解析)  +  UsageAPI (OAuth 配额)
  ↓
MonitorStore (@Observable, MainActor)
  ↓ publishToWidget()
  ├→ SnapshotHTTPServer ─loopback─> Widget Extension
  └→ Views (SwiftUI Charts + MenuBarExtra)
```

### 状态管理

`MonitorStore` 是核心状态管理类，使用 `@Observable` 宏（Observation 框架）。它整合了：
- 按需 + 定时数据加载（不再依赖文件监控，commit 11ec58b 移除 FileMonitor）
- 数据解析与派生属性（todayActivity, last7Days, hourlyDistribution 等）
- OAuth 配额节流（60s 短窗）+ 后台 timer 30 min 定时刷新
- 推 WidgetSnapshot 到 SnapshotHTTPServer + 触发 `WidgetCenter.reloadAllTimelines()`

### API 配额

`UsageAPI` 从多个来源读取 OAuth Token（优先级）：
1. `CLAUDE_CODE_OAUTH_TOKEN` 环境变量
2. macOS Keychain（`Claude Code-credentials`）
3. `~/.claude/.credentials.json` 文件

调用 `https://api.anthropic.com/api/oauth/usage` 获取三类配额数据。

### 菜单栏 App 设置

- 使用 `MenuBarExtra` with `.menuBarExtraStyle(.window)` 支持复杂布局
- `NSApplication.shared.setActivationPolicy(.accessory)` 不显示 Dock 图标
- 开机启动通过 `SMAppService.mainApp` 实现

### Widget 数据通路（HTTP loopback）

App 和 Widget Extension 间数据传递走 `127.0.0.1:53128` HTTP loopback，**不走 App Group / UserDefaults / 共享文件**。

```
MonitorStore (loadUsage / loadStats)
     ↓ publishToWidget()
SnapshotHTTPServer (App 端 NWListener)
     ↓ 127.0.0.1:53128 GET
SnapshotLoader (Widget 端同步 URLSession)
     ↓
WidgetKit Timeline (chronod 每 5 分钟刷)
```

**为什么是 loopback 而不是文件共享**：macOS Sonoma+ TCC 把 widget extension 标 `kTCCServiceSystemPolicyAppData`，禁读其他进程产出文件且不弹同意框，App Group 容器也不例外。TCC 不管 loopback 网络。详细踩坑见 `~/Project/ClaudeTeamMonitor/CLAUDE.md` 「macOS 致命陷阱」段落。

**OAuth 调用节流**：`MonitorStore.loadUsage()` 60 秒内不重复调；后台 timer 30 分钟一次；widget 0 调用（纯本地 loopback）。

## macOS 致命陷阱

⚠️ **自签证书（TeamIdentifier=not set）签的 widget extension chronod 不加载**。`pluginkit -m` 显示 `+` 已 enable、`codesign --verify` 通过，但 Widget Gallery 静默不显示。必须用 Apple Development cert（带 Team ID）。详见 `memory/project_widget_signing_gotchas.md`。

⚠️ **pluginkit 锁定 first-seen appex 路径**。如果第一次 build 在 Debug 路径注册了，后续 Release build 即使覆盖了 appex 内容，chronod 还是去老 Debug 路径加载（可能是 broken 版本）。修复：
```bash
LSR="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
"$LSR" -u <old-path>
rm -rf <old-path>
"$LSR" -f <new-path>
killall chronod NotificationCenter Dock
```

⚠️ **App 不要沙盒**。我们最初按 TeamMonitor 模式沙盒化，结果 `home-relative-path` 例外无法 `readdir(~/.claude/projects/)`。Widget Gallery 显示的真正修复是 pluginkit 路径刷新（上一条），不是 sandbox。Widget Extension 自己保持沙盒（Apple 强制），App 保持非沙盒。

⚠️ **改 widget kind / configuration type 后**，已添加的 widget 实例不升级，必须 Remove + 重新从 Widget Gallery 添加。

## 数据源

| 文件 / 目录 | 格式 | 内容 | 解析器 |
|------|------|------|------|
| `~/.claude/projects/<project>/*.jsonl` | JSONL | 各项目 session 消息流，按 requestId 去重 assistant | `SessionParser` |
| `~/.claude/history.jsonl` | JSONL | 提示词历史、项目路径、会话ID、时间戳 | `HistoryParser` |
| `~/.claude/session-env/` | 目录 | 活跃会话（目录数 = 并发会话数） | 直接 ls |

`stats-cache.json` 已不再读取（commit b8cea6a 改为 SessionParser 直接解析 JSONL）。

## 项目布局

| 路径 | 用途 |
|---|---|
| `project.yml` | XcodeGen 配置；改完跑 `xcodegen generate` |
| `Sources/ClaudeCodeMonitor/` | App target 源码 |
| `Sources/ClaudeCodeMonitorWidget/` | Widget Extension target 源码 |
| `Sources/Shared/` | App + Widget 共享代码（`WidgetSnapshot` 模型、`SnapshotLoopback` 常量） |
| `ClaudeCodeMonitor.entitlements` | App entitlements（当前空，不沙盒） |
| `Sources/ClaudeCodeMonitorWidget/ClaudeCodeMonitorWidget.entitlements` | Widget sandbox + network.client |
| `assets/AppIcon.icns` | App 图标，xcodegen 通过 `resources:` 打包 |
| `build.sh` | 一键 xcodegen + xcodebuild + 拷贝 .app |

## 关键注意事项

- 所有 Model 类型必须符合 `Sendable` 协议（Swift 6 严格并发检查）
- `SnapshotHTTPServer` 用 `@unchecked Sendable`，内部 NSLock 保护 current 快照
- 沙盒下 `FileManager.homeDirectoryForCurrentUser` 和 `NSHomeDirectoryForUser` **都返回 container home**；要拿真实 `~`，直接拼 `/Users/\(NSUserName())`（见 `Utilities/Constants.swift`）
- `~/.claude/projects/` 下数十个目录、上千 JSONL 文件，`SessionParser.parse()` 必须在后台线程执行
- Token 值可能非常大（cache tokens 可达数十亿），使用 `Int`（64位）
- `hourCounts` 的 key 是字符串（"0"~"23"），不是连续的，展示时需补全
- Widget timeline 刷新间隔 5 min；后台 OAuth refresh 间隔 30 min；OAuth 节流 60 s
