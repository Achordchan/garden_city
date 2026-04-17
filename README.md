# 花园城停车助手 v3

一款用于管理账号、查询/兑换停车券、管理车牌号，并支持备份与恢复的 macOS 应用。

本项目为个人学习与效率工具，核心目标是：把“账号/车牌/停车券兑换”这些操作整合到一个更顺手的桌面应用里。

## 功能概览

### 账号与停车券
- 添加账号 / 删除账号（带二次确认）
- 导入/导出账号 JSON
- 查询积分 / 查询停车券数量
- 兑换停车券（支持设置兑换数量）
- 一键执行全部账号任务（只处理“未处理”的账号）
- 每日自动重置处理状态
- 手机号重复检查（避免重复导入/重复添加）

### 车牌号与停车费窗口
- 车牌号管理（新增/删除/选择）
- 快速切换车牌号（主界面快捷菜单）
- 停车费详情窗口：复制链接 / 浏览器打开
- 详情窗口关闭后智能刷新停车券数量

### 设置（v3 优化）
- 基本设置 / 安全与备份 / 高级设置（分段式选项卡）
- 备份设置：备份目录、自动备份、最大备份文件数、最后备份时间
- 备份操作：立即备份、查看备份、导入/导出
- 高级设置：管理员秘钥解锁（秘钥：`Achord666`）


## 架构设计（SwiftUI + 轻量 MVVM）

本项目采用 **SwiftUI + 轻量 MVVM（MVVM-ish）** 的结构化分层，目标是：
- UI 只负责展示与事件转发
- 业务状态与动作集中在 ViewModel / Manager
- 网络请求与本地数据读写隔离成独立层

### 分层职责

#### View（SwiftUI 视图层）
职责：界面渲染、用户交互、把事件转发给 ViewModel/Manager。

代表文件（示例）：
- `ContentView.swift` / `SettingsView.swift`
- `AccountsMainContent.swift` / `ContentToolbar.swift` / `ContentSheets.swift`
- `Settings*TabView.swift` / `SettingsOverlays.swift`

#### ViewModel（状态编排/动作入口）
职责：组合界面所需状态、提供页面动作入口、协调多个底层对象。

代表文件：
- `AccountsViewModel.swift`
- `SettingsViewModel.swift`

#### Manager / Store（可观察的业务状态与操作）
职责：持有核心业务数据（账号列表等），提供增删改查与批处理动作。

代表文件：
- `AccountManager.swift`

#### Service（网络服务层）
职责：封装所有网络请求，屏蔽 API 细节与请求/响应解析。

代表文件：
- `APIService.swift`

为了便于测试与替换实现，引入协议抽象：
- `APIServiceProtocol.swift`

#### Data（本地数据/设置/备份）
职责：本地持久化（UserDefaults）、设置模型、备份/恢复、文件导入导出。

代表文件：
- `DataManager.swift`
- `SettingsFileActions.swift`

### 数据流（简化）

用户操作 -> View -> ViewModel/Manager -> Service/Data -> 更新 Published 状态 -> View 自动刷新

## 重要说明（请务必阅读）

### 使用范围与免责声明
本工具仅用于个人学习与效率提升。除基础的网络请求调用与界面管理外，未进行任何逆向破解行为。

请勿用于任何违规用途。若你下载或使用本项目代码/应用，请在法律与平台规则允许范围内使用。

### Token 机制（技术说明）
应用使用 Token 进行身份验证：
- 每个账号登录后会获得一个 Token
- Token 会在验证成功后自动保存
- 后续 API 请求会携带 Token
- Token 可能失效，应用会在需要时自动重新登录获取新 Token
- 请勿泄露 Token 与导出的账号数据

### 双接口策略
为提升稳定性，部分功能采用新旧双接口协作：
- 新接口优先
- 新接口失败时自动切换旧接口（兜底）

## 数据与安全
当前版本数据存储策略：
- 账号数据保存在本地 `UserDefaults`（JSON 编码），包含账号密码等敏感字段
- 暂未接入 Keychain / AES 加密

安全建议：
- 仅在可信设备上使用
- 不要分享导出的 JSON、备份文件
- 若你担心风险，可自行修改为 Keychain 存储后再使用

## 开发环境
- macOS
- Xcode（建议 Xcode 15 或更高）
- Swift / SwiftUI

## 本地运行（Debug）
1. 用 Xcode 打开 `tingche.xcodeproj`
2. 选择 Scheme 后直接 Run

如果遇到构建问题：
- Product -> Clean Build Folder
- 删除派生数据（可选）：`rm -rf ~/Library/Developer/Xcode/DerivedData/tingche-*`

## 联系方式
- 作者：Achord
- Email：achordchan@gmail.com
- Tel：13160235855

## 变更记录

### 2026-01-12（停车页：停车券列表 UI Mock）
- 在“停车费详情窗口”的 WebView 内，对 `DiscountCore/QueryEn` 响应做 UI-only mock：
  - Mock 开启时，“商场停车券”始终展示完整券列表（数据来自真实 coupon API 预取并缓存到 `localStorage`）。
  - `SelectedMaxCount` 由应用内设置注入并强制生效。
- 修复“Mock 已命中但 UI 仍只显示 1 条停车券”的问题：
  - 对 `mallRule` 强制覆盖/写入 `RightsList`/`rightsList`，并强制 `ShowType/showType = 2`，避免前端走单条渲染分支。
  - XHR 拦截在 mock 命中时同时覆盖 `xhr.responseText` 与 `xhr.response`，避免页面读取到未被替换的数据。
  - 增强 WebView 日志：输出 real coupon API 拉取数量、UseState 分布、以及 QueryEn 规则的 `rightsCount/showType`。
- 删除不再使用的测试功能：
  - 移除“查看停车使用随机车牌（测试）”开关与相关 Swift/JS 冗余逻辑（现在停车页请求始终使用选中的车牌）。

## TODO
- 文本格式批量导入（例如：账号-密码-停车券数量-今日是否获取）