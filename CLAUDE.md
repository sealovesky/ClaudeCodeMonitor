# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

ClaudeCodeMonitor 是一款 macOS 菜单栏应用，用于监控 Claude Code 的使用统计。使用 SwiftUI + MenuBarExtra 实现，读取 `~/.claude/` 目录下的本地数据文件，展示活动统计、Token 消耗、模型分布、项目排行和 API 配额。

## 构建与运行

```bash
# 构建
swift build

# 运行
swift run

# Release 构建
swift build -c release
```

- 需要 macOS 14.0+，Xcode 16.0+，Swift 6.0+
- 使用 Swift Package Manager（Package.swift），无 .xcodeproj
- 无第三方依赖，仅使用 Apple 框架（SwiftUI, Charts, Security, ServiceManagement）

## 架构核心

### 数据流

```
文件监控 (FileMonitor / DispatchSource)
  ↓ 文件变化回调
解析器 (StatsParser / HistoryParser)
  ↓ Codable 解码
MonitorStore (@Observable)
  ↓ 数据绑定
Views (SwiftUI Charts + MenuBarExtra)
```

### 状态管理

`MonitorStore` 是核心状态管理类，使用 `@Observable` 宏（Observation 框架）。它整合了：
- 文件监控器（stats-cache.json + history.jsonl）
- 数据解析与缓存重建
- 派生属性（todayActivity, last7Days, hourlyDistribution 等）
- 防抖重载（1秒延迟）

### 文件监控

`FileMonitor` 使用底层 C API（`open()` + `DispatchSource.makeFileSystemObjectSource`）监听文件变化，比轮询高效。监听事件：`.write`, `.rename`, `.delete`。使用 `LockedBox<T>` 包装实现 `Sendable` 协议兼容 Swift 6 严格并发检查。

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

## 数据源

| 文件 | 格式 | 内容 |
|------|------|------|
| `~/.claude/stats-cache.json` | JSON | 每日活动、模型Token、小时分布、累计统计 |
| `~/.claude/history.jsonl` | JSONL（逐行JSON） | 提示词历史、项目路径、会话ID、时间戳 |
| `~/.claude/session-env/` | 目录 | 活跃会话（目录数 = 会话数） |

## 关键注意事项

- 所有 Model 类型必须符合 `Sendable` 协议（Swift 6 并发安全要求）
- `history.jsonl` 可能有数千行，解析必须在后台线程执行
- Token 值可能非常大（cache tokens 可达数十亿），使用 `Int`（64位）
- `hourCounts` 的 key 是字符串（"0"~"23"），不是连续的，展示时需补全
