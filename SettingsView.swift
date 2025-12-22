//
//  SettingsView.swift
//  tingche
//
//  Created by Achord on 2025/9/8.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var dataManager: DataManager
    @ObservedObject var accountManager: AccountManager
    @Binding var isPresented: Bool
    
    @State private var showingFolderPicker = false
    @State private var showingDeletedAccountsView = false
    @State private var showingBackupListView = false
    @State private var showingRestoreAlert = false
    @State private var selectedBackupFile: BackupFileInfo?
    @State private var restoreAlertMessage = ""
    @State private var showingLicensePlateManager = false
    
    private enum SettingsTab: Hashable {
        case basic
        case security
        case advanced
    }

    struct SettingsCardGroupBoxStyle: GroupBoxStyle {
        func makeBody(configuration: Configuration) -> some View {
            VStack(alignment: .leading, spacing: 12) {
                configuration.label
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding(.bottom, 2)

                configuration.content
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.regularMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 10)
        }
    }
    
    @State private var selectedTab: SettingsTab = .basic
    @State private var advancedKeyInput = ""
    @State private var isAdvancedUnlocked = false
    
    private static let integerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = 0
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    private var tabSubtitle: String {
        switch selectedTab {
        case .basic:
            return "车牌与兑换相关设置"
        case .security:
            return "备份、恢复与数据管理"
        case .advanced:
            return "需要管理员秘钥"
        }
    }

    private var tabIconName: String {
        switch selectedTab {
        case .basic:
            return "gearshape.fill"
        case .security:
            return "lock.shield.fill"
        case .advanced:
            return "gearshape.2.fill"
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .basic:
            basicTab
        case .security:
            securityTab
        case .advanced:
            advancedTab
        }
    }

    private var basicTab: some View {
        ScrollView {
            VStack(spacing: 14) {
                GroupBox(label: HStack {
                    Label("车牌号管理", systemImage: "car.fill")
                    Spacer()
                    Text("当前：\(dataManager.settings.selectedLicensePlate)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }) {
                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("当前选中车牌号")
                                    .font(.headline)
                                Text("用于停车费查询")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Picker("选择车牌号", selection: $dataManager.settings.selectedLicensePlate) {
                                ForEach(dataManager.settings.licensePlates, id: \.self) { plate in
                                    Text(plate).tag(plate)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(minWidth: 120)
                        }

                        Divider()

                        HStack {
                            VStack(alignment: .leading) {
                                Text("车牌号列表")
                                    .font(.headline)
                                Text("管理所有车牌号")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button("管理车牌号") {
                                showingLicensePlateManager = true
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                GroupBox(label: HStack {
                    Label("停车券使用数量", systemImage: "ticket.fill")
                    Spacer()
                    Text("当前：\(dataManager.settings.selectedMaxCount) 张")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("每次使用数量")
                                    .font(.headline)
                                Text("影响“查看停车”页面里的可用数量")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Stepper(value: $dataManager.settings.selectedMaxCount, in: 1...20) {
                                Text("\(dataManager.settings.selectedMaxCount) 张")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.accentColor)
                            }
                            .frame(minWidth: 220)
                        }

                        HStack {
                            Text("1张")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("20张")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                GroupBox(label: HStack {
                    Label("兑换设置", systemImage: "arrow.left.arrow.right")
                    Spacer()
                    Text("当前：\(dataManager.settings.exchangeCount) 张")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("兑换数量")
                                    .font(.headline)
                                Text("影响每次“兑换停车券”的请求数量")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Stepper(value: $dataManager.settings.exchangeCount, in: 1...20) {
                                Text("\(dataManager.settings.exchangeCount) 张")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.accentColor)
                            }
                            .frame(minWidth: 220)
                        }

                        HStack {
                            Text("1张")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("20张")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .frame(maxWidth: 860)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }

    private var securityTab: some View {
        ScrollView {
            VStack(spacing: 14) {
                GroupBox(label: HStack {
                    Label("数据备份设置", systemImage: "externaldrive.fill.badge.icloud")
                    Spacer()
                    Text(dataManager.settings.autoBackupEnabled ? "自动备份：已开启" : "自动备份：已关闭")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }) {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("备份保存位置")
                                .font(.headline)

                            HStack {
                                Text(dataManager.settings.backupLocation.isEmpty ? "未选择目录（将使用文稿目录）" : dataManager.settings.backupLocation)
                                    .foregroundColor(dataManager.settings.backupLocation.isEmpty ? .secondary : .primary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)

                                Spacer()

                                Button("选择目录") {
                                    showingFolderPicker = true
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("启用自动备份", isOn: $dataManager.settings.autoBackupEnabled)
                                .font(.headline)

                            if dataManager.settings.autoBackupEnabled {
                                HStack(spacing: 10) {
                                    Text("备份间隔")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    TextField("", value: $dataManager.settings.backupInterval, formatter: Self.integerFormatter)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 72)
                                    Text("小时")
                                        .foregroundColor(.secondary)
                                    Stepper("", value: $dataManager.settings.backupInterval, in: 1...168)
                                        .labelsHidden()
                                }
                                .padding(.leading, 2)
                            }
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                Text("最大备份文件数")
                                    .font(.headline)
                                Spacer()
                                TextField("", value: $dataManager.settings.maxBackupFiles, formatter: Self.integerFormatter)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 72)
                                Text("个")
                                    .foregroundColor(.secondary)
                                Stepper("", value: $dataManager.settings.maxBackupFiles, in: 5...50)
                                    .labelsHidden()
                            }
                            Text("范围：5～50")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if let lastBackupDate = dataManager.lastBackupDate {
                            HStack {
                                Text("最后备份时间：")
                                    .foregroundColor(.secondary)
                                Text(DateFormatter.displayFormatter.string(from: lastBackupDate))
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .font(.caption)
                            .padding(.top, 8)
                        }
                    }
                }

                GroupBox(label: HStack {
                    Label("备份操作", systemImage: "arrow.up.doc.on.clipboard")
                    Spacer()
                    Text("备份：\(dataManager.backupFiles.count) 个")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }) {
                    VStack(spacing: 10) {
                        HStack {
                            Button(action: {
                                Task {
                                    await createManualBackup()
                                }
                            }) {
                                if dataManager.isBackingUp {
                                    HStack {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                        Text("备份中...")
                                    }
                                } else {
                                    Label("立即备份", systemImage: "icloud.and.arrow.up")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(dataManager.isBackingUp)

                            Spacer()

                            Button("查看备份") {
                                showingBackupListView = true
                            }
                            .buttonStyle(.bordered)
                        }

                        HStack {
                            Button("导出账号数据") {
                                exportAccountData()
                            }
                            .buttonStyle(.bordered)

                            Spacer()

                            Button("导入账号数据") {
                                importAccountData()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                GroupBox(label: HStack {
                    Label("数据管理", systemImage: "tray.full.fill")
                    Spacer()
                    Text("删除：\(dataManager.deletedAccounts.count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }) {
                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("删除记录")
                                    .font(.headline)
                                Text("查看已删除的账号记录")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button("查看 (\(dataManager.deletedAccounts.count))") {
                                showingDeletedAccountsView = true
                            }
                            .buttonStyle(.bordered)
                        }

                        Divider()

                        HStack {
                            VStack(alignment: .leading) {
                                Text("当前账号数量")
                                    .font(.headline)
                                Text("正在管理的账号总数")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Text("\(accountManager.accounts.count) 个")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .frame(maxWidth: 860)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }

    private var advancedTab: some View {
        ScrollView {
            VStack(spacing: 14) {
                GroupBox(label: HStack {
                    Label("高级设置", systemImage: "gearshape.2.fill")
                    Spacer()
                    Text(isAdvancedUnlocked ? "已解锁" : "未解锁")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }) {
                    VStack(alignment: .leading, spacing: 12) {
                        if isAdvancedUnlocked {
                            Label("已解锁", systemImage: "checkmark.seal.fill")
                                .foregroundColor(.green)
                                .font(.headline)

                            Text("暂无内容")
                                .foregroundColor(.secondary)
                        } else {
                            Label("请输入超级管理员秘钥以访问", systemImage: "lock.fill")
                                .foregroundColor(.secondary)

                            HStack(spacing: 10) {
                                SecureField("秘钥", text: $advancedKeyInput)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(minWidth: 220)

                                Button("解锁") {
                                    if advancedKeyInput == "Achord666" {
                                        isAdvancedUnlocked = true
                                        advancedKeyInput = ""
                                        accountManager.showToast("已解锁高级设置", type: .success)
                                    } else {
                                        accountManager.showToast("秘钥错误", type: .error)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                }

                if isAdvancedUnlocked {
                    GroupBox(label: HStack {
                        Label("危险区", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Spacer()
                        Text("谨慎操作")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("这里将放置高级维护功能（暂未开放）。")
                                .foregroundColor(.secondary)
                                .font(.subheadline)

                            HStack(spacing: 10) {
                                Button("清理缓存") { }
                                    .buttonStyle(.bordered)
                                    .disabled(true)
                                
                                Button("重置所有设置") { }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.red)
                                    .disabled(true)

                                Spacer()
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: 860)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                // 标题
                HStack {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.14))
                                .frame(width: 34, height: 34)
                            Image(systemName: tabIconName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.accentColor)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("应用设置")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text(tabSubtitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Button("保存并关闭") {
                        dataManager.saveSettings()
                        isPresented = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            accountManager.showToast("设置已保存", type: .success)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)
                
                VStack(spacing: 10) {
                    HStack {
                        Picker("", selection: $selectedTab) {
                            Label("基本", systemImage: "gearshape").tag(SettingsTab.basic)
                            Label("备份", systemImage: "lock.shield").tag(SettingsTab.security)
                            Label("高级", systemImage: "gearshape.2").tag(SettingsTab.advanced)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.black.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    
                    tabContent
                        .groupBoxStyle(SettingsCardGroupBoxStyle())
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.windowBackgroundColor))
            .background(
                LinearGradient(
                    colors: [
                        Color.accentColor.opacity(0.08),
                        Color.accentColor.opacity(0.02),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        .frame(minWidth: 760, idealWidth: 860, maxWidth: 980, minHeight: 640, idealHeight: 760, maxHeight: 980)
        .onChange(of: showingFolderPicker) { isPresented in
            if isPresented {
                DispatchQueue.main.async {
                    showFolderPicker()
                }
            }
        }
        .sheet(isPresented: $showingBackupListView) {
            BackupListView(dataManager: dataManager, accountManager: accountManager)
        }
        .sheet(isPresented: $showingDeletedAccountsView) {
            DeletedAccountsView(dataManager: dataManager, accountManager: accountManager)
        }
        .sheet(isPresented: $showingLicensePlateManager) {
            LicensePlateManagerView(dataManager: dataManager)
        }
        .alert("恢复备份", isPresented: $showingRestoreAlert) {
            Button("取消", role: .cancel) { }
            Button("确认恢复") {
                if let backupFile = selectedBackupFile {
                    restoreFromBackup(backupFile)
                }
            }
        } message: {
            Text(restoreAlertMessage)
        }
        .overlay(alignment: .top) {
            if accountManager.showToast
                && !showingBackupListView
                && !showingLicensePlateManager
                && !showingDeletedAccountsView
                && accountManager.toastMessage != "设置已保存" {
                ToastView(message: accountManager.toastMessage, type: accountManager.toastType)
                    .padding(.horizontal, 16)
                    .padding(.top, 64)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut, value: accountManager.showToast)
                    .zIndex(999)
                    .allowsHitTesting(false)
            }
        }
    }
    
    // MARK: - 私有方法
    private func createManualBackup() async {
        // 检查是否有账号数据
        guard !accountManager.accounts.isEmpty else {
            accountManager.showToast("没有账号数据需要备份", type: .info)
            return
        }
        
        let success = await dataManager.createBackup(accounts: accountManager.accounts)
        if success {
            let accountCount = accountManager.accounts.count
            accountManager.showToast("备份创建成功！已备份 \(accountCount) 个账号", type: .success)
        } else {
            accountManager.showToast("备份创建失败，请检查文件权限和存储空间", type: .error)
        }
    }
    
    private func exportAccountData() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "tingche_accounts_\(DateFormatter.backupFormatter.string(from: Date())).json"
        panel.allowedContentTypes = [UTType.json]
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                let success = dataManager.exportAccounts(accountManager.accounts, to: url)
                if success {
                    accountManager.showToast("导出成功", type: .success)
                } else {
                    accountManager.showToast("导出失败", type: .error)
                }
            }
        }
    }
    
    private func importAccountData() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.json]
        panel.allowsMultipleSelection = false
        
        panel.begin { response in
            if response == .OK, let url = panel.urls.first {
                if let importedAccounts = dataManager.importAccounts(from: url) {
                    // 过滤已存在的账号
                    let newAccounts = importedAccounts.filter { importedAccount in
                        !accountManager.accounts.contains { existingAccount in
                            existingAccount.username == importedAccount.username
                        }
                    }
                    
                    accountManager.accounts.append(contentsOf: newAccounts)
                    accountManager.saveAccounts()
                    
                    accountManager.showToast("成功导入 \(newAccounts.count) 个新账号", type: .success)
                } else {
                    accountManager.showToast("导入失败，请检查文件格式", type: .error)
                }
            }
        }
    }
    
    private func restoreFromBackup(_ backupFile: BackupFileInfo) {
        if let backupData = dataManager.restoreFromBackup(backupFile) {
            accountManager.accounts = backupData.accounts
            dataManager.deletedAccounts = backupData.deletedAccounts
            
            accountManager.saveAccounts()
            dataManager.saveDeletedAccounts()
            
            accountManager.showToast("备份恢复成功", type: .success)
        } else {
            accountManager.showToast("备份恢复失败", type: .error)
        }
    }
    
    // MARK: - 文件夹选择器
    private func showFolderPicker() {
        let panel = NSOpenPanel()
        panel.title = "选择备份目录"
        panel.message = "请选择用于保存备份文件的目录"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        
        panel.begin { response in
            DispatchQueue.main.async {
                self.showingFolderPicker = false
                
                if response == .OK, let url = panel.url {
                    // NSOpenPanel 已经获得了用户授权，可以直接访问
                    do {
                        // 创建安全书签 - 这是关键！需要读写权限
                        let bookmark = try url.bookmarkData(
                            options: [.withSecurityScope],
                            includingResourceValuesForKeys: nil,
                            relativeTo: nil
                        )
                        
                        // 保存路径和书签
                        dataManager.settings.backupLocation = url.path
                        dataManager.saveSecurityBookmark(bookmark)
                        dataManager.saveSettings()
                        
                        print("备份路径已设置为: \(url.path)")
                        print("安全书签已保存")
                    } catch {
                        print("创建安全书签失败: \(error.localizedDescription)")
                        // 仍然保存路径，稍后再处理权限
                        dataManager.settings.backupLocation = url.path
                        dataManager.saveSettings()
                    }
                }
            }
        }
    }
}

// MARK: - 删除记录查看视图
struct DeletedAccountsView: View {
    @ObservedObject var dataManager: DataManager
    @ObservedObject var accountManager: AccountManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                if dataManager.deletedAccounts.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "trash.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("暂无删除记录")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(dataManager.deletedAccounts) { record in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(record.accountInfo.username)
                                        .font(.headline)
                                    Spacer()

                                    Button("恢复") {
                                        restoreRecord(record)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .help("恢复该账号到主页")

                                    Text(DateFormatter.displayFormatter.string(from: record.deletedAt))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                if let reason = record.reason {
                                    Text("删除原因：\(reason)")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                                
                                HStack {
                                    Text("积分：\(record.accountInfo.bonus)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text("停车券：\(record.accountInfo.voucherCount)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete(perform: deleteRecords)
                    }
                }
            }
            .navigationTitle("删除记录")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    if !dataManager.deletedAccounts.isEmpty {
                        Button("清空所有") {
                            dataManager.clearDeletedAccountsHistory()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
        .frame(minWidth: 500, idealWidth: 550, maxWidth: 700, minHeight: 400, idealHeight: 450, maxHeight: 600)
        .overlay(alignment: .top) {
            if accountManager.showToast {
                ToastView(message: accountManager.toastMessage, type: accountManager.toastType)
                    .padding(.horizontal, 16)
                    .padding(.top, 56)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut, value: accountManager.showToast)
                    .zIndex(999)
                    .allowsHitTesting(false)
            }
        }
    }

    private func restoreRecord(_ record: DeletedAccountRecord) {
        if accountManager.accounts.contains(where: { $0.username == record.accountInfo.username }) {
            accountManager.showToast("恢复失败：该账号已存在", type: .info)
            return
        }

        accountManager.accounts.append(record.accountInfo)
        accountManager.saveAccounts()

        dataManager.removeDeletedAccountRecord(record)
        accountManager.showToast("已恢复账号 \(record.accountInfo.username)", type: .success)
    }
    
    private func deleteRecords(offsets: IndexSet) {
        for index in offsets {
            let record = dataManager.deletedAccounts[index]
            dataManager.removeDeletedAccountRecord(record)
        }
    }
}

// MARK: - 备份列表视图
struct BackupListView: View {
    @ObservedObject var dataManager: DataManager
    @ObservedObject var accountManager: AccountManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingRestoreAlert = false
    @State private var selectedBackupFile: BackupFileInfo?
    
    var body: some View {
        NavigationStack {
            VStack {
                if dataManager.backupFiles.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "externaldrive.badge.questionmark")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("暂无备份文件")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(dataManager.backupFiles) { backupFile in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(backupFile.fileName)
                                        .font(.headline)
                                    Spacer()
                                    
                                    Button("在访达中显示") {
                                        showInFinder(backupFile)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    
                                    Button("恢复") {
                                        selectedBackupFile = backupFile
                                        showingRestoreAlert = true
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                                
                                HStack {
                                    Text("创建时间：\(DateFormatter.displayFormatter.string(from: backupFile.createdAt))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Text("账号数：\(backupFile.accountCount)")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    
                                    Text("大小：\(formatFileSize(backupFile.fileSize))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack {
                                    Text("保存位置：\(backupFile.backupDirectoryDisplayName)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete(perform: deleteBackupFiles)
                    }
                }
            }
            .navigationTitle("备份文件")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 600, idealWidth: 650, maxWidth: 800, minHeight: 400, idealHeight: 450, maxHeight: 600)
        .alert("恢复备份", isPresented: $showingRestoreAlert) {
            Button("取消", role: .cancel) { }
            Button("确认恢复") {
                if let backupFile = selectedBackupFile {
                    restoreFromBackup(backupFile)
                    dismiss()
                }
            }
        } message: {
            if let backupFile = selectedBackupFile {
                Text("确定要恢复到 \(DateFormatter.displayFormatter.string(from: backupFile.createdAt)) 的备份吗？\n当前数据将被覆盖。")
            }
        }
        .overlay(alignment: .top) {
            if accountManager.showToast {
                ToastView(message: accountManager.toastMessage, type: accountManager.toastType)
                    .padding(.horizontal, 16)
                    .padding(.top, 56)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut, value: accountManager.showToast)
                    .zIndex(999)
                    .allowsHitTesting(false)
            }
        }
    }
    
    private func deleteBackupFiles(offsets: IndexSet) {
        for index in offsets {
            let backupFile = dataManager.backupFiles[index]
            // 删除文件
            try? FileManager.default.removeItem(atPath: backupFile.filePath)
            // 从列表中移除
            dataManager.backupFiles.remove(at: index)
        }
        dataManager.saveBackupFiles()
    }
    
    private func restoreFromBackup(_ backupFile: BackupFileInfo) {
        if let backupData = dataManager.restoreFromBackup(backupFile) {
            accountManager.accounts = backupData.accounts
            dataManager.deletedAccounts = backupData.deletedAccounts
            
            accountManager.saveAccounts()
            dataManager.saveDeletedAccounts()
            
            accountManager.showToast("备份恢复成功", type: .success)
        } else {
            accountManager.showToast("备份恢复失败", type: .error)
        }
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func showInFinder(_ backupFile: BackupFileInfo) {
        NSWorkspace.shared.selectFile(backupFile.filePath, inFileViewerRootedAtPath: backupFile.backupDirectory)
    }

}

// MARK: - 车牌号管理视图
struct LicensePlateManagerView: View {
    @ObservedObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    @State private var newPlate = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingDeleteConfirmation = false
    @State private var platePendingDeletion: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Spacer(minLength: 14)

                VStack(spacing: 18) {
                    // 标题
                    HStack {
                        Text("车牌号管理")
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                        Button("完成") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.horizontal, 20)

                    ScrollView {
                        VStack(spacing: 16) {
                            // 添加车牌号
                            GroupBox("添加新车牌号") {
                                VStack(spacing: 12) {
                                    HStack {
                                        TextField("输入车牌号", text: $newPlate)
                                            .textFieldStyle(.roundedBorder)
                                            .onSubmit {
                                                addLicensePlate()
                                            }

                                        Button("添加") {
                                            addLicensePlate()
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .disabled(newPlate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                    }

                                    Text("例如：苏A12345、京B54321")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                            }

                            // 车牌号列表
                            GroupBox("已有车牌号") {
                                if dataManager.settings.licensePlates.isEmpty {
                                    Text("暂无车牌号")
                                        .foregroundColor(.secondary)
                                        .padding()
                                } else {
                                    VStack(spacing: 8) {
                                        ForEach(dataManager.settings.licensePlates, id: \.self) { plate in
                                            HStack {
                                                Text(plate)
                                                    .font(.system(.body, design: .monospaced))

                                                if plate == dataManager.settings.selectedLicensePlate {
                                                    Text("当前选中")
                                                        .font(.caption)
                                                        .foregroundColor(.green)
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 2)
                                                        .background(Color.green.opacity(0.1))
                                                        .cornerRadius(4)
                                                }

                                                Spacer()

                                                Button("选择") {
                                                    dataManager.selectLicensePlate(plate)
                                                }
                                                .buttonStyle(.bordered)
                                                .disabled(plate == dataManager.settings.selectedLicensePlate)
                                                .help(plate == dataManager.settings.selectedLicensePlate ? "当前已选中" : "设为当前车牌号")

                                                Button(action: {
                                                    platePendingDeletion = plate
                                                    showingDeleteConfirmation = true
                                                }) {
                                                    Image(systemName: "trash")
                                                        .foregroundColor(.red)
                                                }
                                                .buttonStyle(.plain)
                                                .disabled(dataManager.settings.licensePlates.count <= 1)
                                                .help(dataManager.settings.licensePlates.count <= 1 ? "至少需要保留一个车牌号" : "删除该车牌号")
                                            }
                                            .padding(.horizontal)
                                            .padding(.vertical, 8)
                                            .background(Color(NSColor.controlBackgroundColor))
                                            .cornerRadius(8)
                                        }
                                    }
                                    .padding()
                                }
                            }
                        }
                        .frame(maxWidth: 560)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 18)
                    }
                }

                Spacer(minLength: 14)
            }
        }
        .frame(minWidth: 500, idealWidth: 550, maxWidth: 700, minHeight: 400, idealHeight: 450, maxHeight: 600)
        .confirmationDialog(
            "确认删除车牌号",
            isPresented: $showingDeleteConfirmation,
            presenting: platePendingDeletion
        ) { plate in
            Button("删除", role: .destructive) {
                removeLicensePlate(plate)
                platePendingDeletion = nil
            }
            Button("取消", role: .cancel) {
                platePendingDeletion = nil
            }
        } message: { plate in
            Text("确定要删除车牌号 \(plate) 吗？")
        }
        .alert("提示", isPresented: $showingAlert) {
            Button("确定") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func addLicensePlate() {
        let plate = newPlate.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !plate.isEmpty else {
            alertMessage = "车牌号不能为空"
            showingAlert = true
            return
        }
        
        guard !dataManager.settings.licensePlates.contains(plate) else {
            alertMessage = "车牌号已存在"
            showingAlert = true
            return
        }
        
        dataManager.addLicensePlate(plate)
        newPlate = ""
        alertMessage = "车牌号添加成功"
        showingAlert = true
    }
    
    private func removeLicensePlate(_ plate: String) {
        guard dataManager.settings.licensePlates.count > 1 else {
            alertMessage = "至少需要保留一个车牌号"
            showingAlert = true
            return
        }
        
        dataManager.removeLicensePlate(plate)
        alertMessage = "车牌号删除成功"
        showingAlert = true
    }
} 
