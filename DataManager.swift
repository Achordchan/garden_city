//
//  DataManager.swift
//  tingche
//
//  Created by A chord on 2025/9/8.
//

import Foundation
import SwiftUI

// MARK: - 应用设置模型
struct AppSettings: Codable {
    var backupLocation: String
    var autoBackupEnabled: Bool
    var backupInterval: Int // 小时
    var maxBackupFiles: Int
    var licensePlates: [String] // 车牌号列表
    var selectedLicensePlate: String // 当前选中的车牌号
    var selectedMaxCount: Int
    var exchangeCount: Int
    
    init() {
        self.backupLocation = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path ?? ""
        self.autoBackupEnabled = true
        self.backupInterval = 24 // 每24小时备份一次
        self.maxBackupFiles = 10 // 最多保留10个备份文件
        self.licensePlates = ["苏FC035N7"] // 默认车牌号
        self.selectedLicensePlate = "苏FC035N7" // 默认选中第一个
        self.selectedMaxCount = 10
        self.exchangeCount = 1
    }

    enum CodingKeys: String, CodingKey {
        case backupLocation
        case autoBackupEnabled
        case backupInterval
        case maxBackupFiles
        case licensePlates
        case selectedLicensePlate
        case selectedMaxCount
        case exchangeCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let defaultBackupLocation = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path ?? ""

        self.backupLocation = try container.decodeIfPresent(String.self, forKey: .backupLocation) ?? defaultBackupLocation
        self.autoBackupEnabled = try container.decodeIfPresent(Bool.self, forKey: .autoBackupEnabled) ?? true
        self.backupInterval = try container.decodeIfPresent(Int.self, forKey: .backupInterval) ?? 24
        self.maxBackupFiles = try container.decodeIfPresent(Int.self, forKey: .maxBackupFiles) ?? 10
        self.licensePlates = try container.decodeIfPresent([String].self, forKey: .licensePlates) ?? ["苏FC035N7"]
        self.selectedLicensePlate = try container.decodeIfPresent(String.self, forKey: .selectedLicensePlate) ?? (self.licensePlates.first ?? "苏FC035N7")
        self.selectedMaxCount = try container.decodeIfPresent(Int.self, forKey: .selectedMaxCount) ?? 10
        self.exchangeCount = try container.decodeIfPresent(Int.self, forKey: .exchangeCount) ?? 1
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(backupLocation, forKey: .backupLocation)
        try container.encode(autoBackupEnabled, forKey: .autoBackupEnabled)
        try container.encode(backupInterval, forKey: .backupInterval)
        try container.encode(maxBackupFiles, forKey: .maxBackupFiles)
        try container.encode(licensePlates, forKey: .licensePlates)
        try container.encode(selectedLicensePlate, forKey: .selectedLicensePlate)
        try container.encode(selectedMaxCount, forKey: .selectedMaxCount)
        try container.encode(exchangeCount, forKey: .exchangeCount)
    }
}

// MARK: - 删除记录模型
struct DeletedAccountRecord: Identifiable, Codable {
    let id: UUID
    let accountInfo: AccountInfo
    let deletedAt: Date
    let reason: String?
    
    init(accountInfo: AccountInfo, reason: String? = nil) {
        self.id = UUID()
        self.accountInfo = accountInfo
        self.deletedAt = Date()
        self.reason = reason
    }
}

// MARK: - 备份文件信息
struct BackupFileInfo: Identifiable, Codable {
    let id: UUID
    let fileName: String
    let filePath: String
    let createdAt: Date
    let fileSize: Int64
    let accountCount: Int
    
    init(fileName: String, filePath: String, fileSize: Int64, accountCount: Int) {
        self.id = UUID()
        self.fileName = fileName
        self.filePath = filePath
        self.createdAt = Date()
        self.fileSize = fileSize
        self.accountCount = accountCount
    }
    
    // 获取备份目录路径用于显示
    var backupDirectory: String {
        return (filePath as NSString).deletingLastPathComponent
    }
    
    // 获取备份目录的显示名称
    var backupDirectoryDisplayName: String {
        let directory = backupDirectory
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
        
        if directory.hasPrefix(homeDirectory) {
            let relativePath = String(directory.dropFirst(homeDirectory.count))
            return "~" + relativePath
        }
        return directory
    }
}

// MARK: - 数据管理器
class DataManager: ObservableObject {
    @Published var settings: AppSettings = AppSettings()
    @Published var deletedAccounts: [DeletedAccountRecord] = []
    @Published var backupFiles: [BackupFileInfo] = []
    @Published var isBackingUp: Bool = false
    @Published var lastBackupDate: Date?
    
    private let settingsKey = "appSettings"
    private let deletedAccountsKey = "deletedAccounts"
    private let backupFilesKey = "backupFiles"
    private let lastBackupDateKey = "lastBackupDate"
    private let securityBookmarkKey = "securityBookmark"
    
    private var backupTimer: Timer?
    private var securityScopedBookmark: Data?
    
    init() {
        loadSettings()
        loadDeletedAccounts()
        loadBackupFiles()
        loadLastBackupDate()
        loadSecurityBookmark()
        setupAutoBackup()
        setupNotificationObservers()
    }
    
    deinit {
        backupTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - 设置管理
    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let settings = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = settings
        }
    }
    
    func saveSettings() {
        do {
            let data = try JSONEncoder().encode(settings)
            UserDefaults.standard.set(data, forKey: settingsKey)
            
            // 重新设置自动备份
            setupAutoBackup()
        } catch {
            print("保存设置失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 安全书签管理
    private func loadSecurityBookmark() {
        securityScopedBookmark = UserDefaults.standard.data(forKey: securityBookmarkKey)
    }
    
    func saveSecurityBookmark(_ bookmark: Data) {
        securityScopedBookmark = bookmark
        UserDefaults.standard.set(bookmark, forKey: securityBookmarkKey)
    }
    
    func clearSecurityBookmark() {
        securityScopedBookmark = nil
        UserDefaults.standard.removeObject(forKey: securityBookmarkKey)
    }
    
    // MARK: - 删除记录管理
    private func loadDeletedAccounts() {
        if let data = UserDefaults.standard.data(forKey: deletedAccountsKey),
           let deletedAccounts = try? JSONDecoder().decode([DeletedAccountRecord].self, from: data) {
            self.deletedAccounts = deletedAccounts
        }
    }
    
    func addDeletedAccountRecord(_ account: AccountInfo, reason: String? = nil) {
        let record = DeletedAccountRecord(accountInfo: account, reason: reason)
        deletedAccounts.append(record)
        saveDeletedAccountsPrivate()
    }
    
    func removeDeletedAccountRecord(_ record: DeletedAccountRecord) {
        deletedAccounts.removeAll { $0.id == record.id }
        saveDeletedAccountsPrivate()
    }
    
    func clearDeletedAccountsHistory() {
        deletedAccounts.removeAll()
        saveDeletedAccountsPrivate()
    }
    
    private func saveDeletedAccountsPrivate() {
        do {
            let data = try JSONEncoder().encode(deletedAccounts)
            UserDefaults.standard.set(data, forKey: deletedAccountsKey)
        } catch {
            print("保存删除记录失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 备份文件管理
    private func loadBackupFiles() {
        if let data = UserDefaults.standard.data(forKey: backupFilesKey),
           let backupFiles = try? JSONDecoder().decode([BackupFileInfo].self, from: data) {
            self.backupFiles = backupFiles
        }
    }
    
    func saveBackupFiles() {
        do {
            let data = try JSONEncoder().encode(backupFiles)
            UserDefaults.standard.set(data, forKey: backupFilesKey)
        } catch {
            print("保存备份文件列表失败: \(error.localizedDescription)")
        }
    }
    
    private func loadLastBackupDate() {
        lastBackupDate = UserDefaults.standard.object(forKey: lastBackupDateKey) as? Date
    }
    
    private func saveLastBackupDate() {
        UserDefaults.standard.set(lastBackupDate, forKey: lastBackupDateKey)
    }
    
    // MARK: - 备份功能
    func createBackup(accounts: [AccountInfo]) async -> Bool {
        await MainActor.run {
            isBackingUp = true
        }
        
        defer {
            DispatchQueue.main.async {
                self.isBackingUp = false
            }
        }
        
        do {
            let timestamp = DateFormatter.backupFormatter.string(from: Date())
            let fileName = "tingche_backup_\(timestamp).json"
            
            // 使用用户设置的备份路径
            let backupDirURL: URL
            var needsSecurityScope = false
            
            if settings.backupLocation.isEmpty {
                // 如果没有设置路径，使用默认的安全目录
                let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                backupDirURL = documentsURL.appendingPathComponent("TingcheBackups")
            } else {
                // 使用用户设置的路径，需要安全访问
                backupDirURL = URL(fileURLWithPath: settings.backupLocation).appendingPathComponent("TingcheBackups")
                needsSecurityScope = true
            }
            
            // 安全访问的URL引用
            var securedURL: URL?
            
            // 如果需要安全访问，使用安全书签
            if needsSecurityScope, let bookmark = securityScopedBookmark {
                var isStale = false
                guard let resolvedURL = try? URL(resolvingBookmarkData: bookmark, 
                                              options: .withSecurityScope, 
                                              relativeTo: nil, 
                                              bookmarkDataIsStale: &isStale),
                      resolvedURL.startAccessingSecurityScopedResource() else {
                    print("无法访问安全范围的URL，请重新选择备份目录")
                    throw NSError(domain: "SecurityScopeError", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法访问备份目录，请重新选择"])
                }
                securedURL = resolvedURL
            }
            
            defer {
                // 在函数结束时释放安全访问
                securedURL?.stopAccessingSecurityScopedResource()
            }
            
            // 确保备份目录存在
            try FileManager.default.createDirectory(at: backupDirURL, withIntermediateDirectories: true, attributes: nil)
            
            let fileURL = backupDirURL.appendingPathComponent(fileName)
            
            // 创建备份数据
            let backupData = BackupData(
                accounts: accounts,
                deletedAccounts: deletedAccounts,
                createdAt: Date(),
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            )
            
            let data = try JSONEncoder().encode(backupData)
            try data.write(to: fileURL)
            
            // 记录备份文件信息
            let fileSize = try FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64 ?? 0
            let backupFileInfo = BackupFileInfo(
                fileName: fileName,
                filePath: fileURL.path,
                fileSize: fileSize,
                accountCount: accounts.count
            )
            
            await MainActor.run {
                self.backupFiles.append(backupFileInfo)
                self.lastBackupDate = Date()
                
                // 保持备份文件数量限制
                self.cleanOldBackups()
                
                self.saveBackupFiles()
                self.saveLastBackupDate()
            }
            
            print("备份创建成功: \(fileURL.path)")
            print("备份文件大小: \(fileSize) 字节")
            print("备份账号数量: \(accounts.count)")
            return true
            
        } catch {
            print("创建备份失败: \(error.localizedDescription)")
            
            // 记录详细错误信息
            if let nsError = error as NSError? {
                print("错误域: \(nsError.domain)")
                print("错误代码: \(nsError.code)")
                print("错误详情: \(nsError.userInfo)")
            }
            
            // 检查目录访问权限
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let backupDirURL = documentsURL.appendingPathComponent("TingcheBackups")
            
            do {
                let isWritable = try backupDirURL.resourceValues(forKeys: [.isWritableKey]).isWritable
                print("备份目录可写权限: \(isWritable ?? false)")
            } catch {
                print("无法检查备份目录权限: \(error.localizedDescription)")
            }
            
            if !FileManager.default.fileExists(atPath: backupDirURL.path) {
                print("备份目录不存在: \(backupDirURL.path)")
            } else {
                print("备份目录存在: \(backupDirURL.path)")
            }
            
            return false
        }
    }
    
    func restoreFromBackup(_ backupFile: BackupFileInfo) -> BackupData? {
        let fileURL = URL(fileURLWithPath: backupFile.filePath)
        var securedURL: URL?

        // 如果备份位于用户选择的目录，需要安全范围访问（App Sandbox）
        if !settings.backupLocation.isEmpty, let bookmark = securityScopedBookmark {
            do {
                var isStale = false
                let resolvedURL = try URL(
                    resolvingBookmarkData: bookmark,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )

                if resolvedURL.startAccessingSecurityScopedResource() {
                    securedURL = resolvedURL
                } else {
                    print("恢复备份失败: 无法访问安全范围的备份目录，请重新选择备份目录")
                }
            } catch {
                print("恢复备份失败: 解析安全书签失败: \(error.localizedDescription)")
            }
        }

        defer {
            securedURL?.stopAccessingSecurityScopedResource()
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let backupData = try JSONDecoder().decode(BackupData.self, from: data)
            return backupData
        } catch {
            print("恢复备份失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func cleanOldBackups() {
        // 按创建时间排序，保留最新的文件
        backupFiles.sort { $0.createdAt > $1.createdAt }
        
        while backupFiles.count > settings.maxBackupFiles {
            if let oldestBackup = backupFiles.last {
                // 删除文件
                try? FileManager.default.removeItem(atPath: oldestBackup.filePath)
                backupFiles.removeLast()
            }
        }
    }
    
    // MARK: - 自动备份
    private func setupAutoBackup() {
        backupTimer?.invalidate()
        
        guard settings.autoBackupEnabled else { return }
        
        let interval = TimeInterval(settings.backupInterval * 3600) // 转换为秒
        backupTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.triggerAutoBackup()
        }
    }
    
    private func triggerAutoBackup() {
        // 这里需要从外部获取账号数据，暂时留空，稍后在AccountManager中调用
        print("触发自动备份")
        NotificationCenter.default.post(name: .autoBackupTriggered, object: nil)
    }
    
    // MARK: - 导出功能
    func exportAccounts(_ accounts: [AccountInfo], to url: URL) -> Bool {
        do {
            let data = try JSONEncoder().encode(accounts)
            try data.write(to: url)
            return true
        } catch {
            print("导出账号失败: \(error.localizedDescription)")
            return false
        }
    }
    
    func importAccounts(from url: URL) -> [AccountInfo]? {
        do {
            let data = try Data(contentsOf: url)
            let accounts = try JSONDecoder().decode([AccountInfo].self, from: data)
            return accounts
        } catch {
            print("导入账号失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - 通知观察者
    private func setupNotificationObservers() {
        // 监听账号删除通知
        NotificationCenter.default.addObserver(
            forName: .accountDeleted,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let account = notification.object as? AccountInfo else { return }
            
            let reason = notification.userInfo?["reason"] as? String
            self.addDeletedAccountRecord(account, reason: reason)
        }
        
        // 监听自动备份执行通知
        NotificationCenter.default.addObserver(
            forName: .performAutoBackup,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let accounts = notification.object as? [AccountInfo] else { return }
            
            Task {
                let success = await self.createBackup(accounts: accounts)
                if success {
                    print("自动备份完成")
                } else {
                    print("自动备份失败")
                }
            }
        }
    }
    
    // 保存删除记录的方法（暴露给外部调用）
    func saveDeletedAccounts() {
        do {
            let data = try JSONEncoder().encode(deletedAccounts)
            UserDefaults.standard.set(data, forKey: deletedAccountsKey)
        } catch {
            print("保存删除记录失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 车牌号管理
    func addLicensePlate(_ plate: String) {
        guard !plate.isEmpty && !settings.licensePlates.contains(plate) else { return }
        settings.licensePlates.append(plate)
        saveSettings()
    }
    
    func removeLicensePlate(_ plate: String) {
        settings.licensePlates.removeAll { $0 == plate }
        // 如果删除的是当前选中的车牌号，选择第一个可用的
        if settings.selectedLicensePlate == plate {
            settings.selectedLicensePlate = settings.licensePlates.first ?? ""
        }
        saveSettings()
    }
    
    func selectLicensePlate(_ plate: String) {
        if settings.licensePlates.contains(plate) {
            settings.selectedLicensePlate = plate
            saveSettings()
        }
    }
    
    // 获取URL编码的车牌号
    func getEncodedSelectedLicensePlate() -> String {
        return settings.selectedLicensePlate.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? settings.selectedLicensePlate
    }
}

// MARK: - 备份数据模型
struct BackupData: Codable {
    let accounts: [AccountInfo]
    let deletedAccounts: [DeletedAccountRecord]
    let createdAt: Date
    let appVersion: String
}

// MARK: - 通知名称
extension Notification.Name {
    static let autoBackupTriggered = Notification.Name("autoBackupTriggered")
    static let performAutoBackup = Notification.Name("performAutoBackup")
    static let accountDeleted = Notification.Name("accountDeleted")
}

// MARK: - 日期格式化器
extension DateFormatter {
    static let backupFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()
    
    static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()
} 
