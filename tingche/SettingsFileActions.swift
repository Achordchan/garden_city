// Purpose: File operations used from settings (backup/export/import/restore/folder picker).
// Author: Achord <achordchan@gmail.com>
import AppKit
import Foundation
import UniformTypeIdentifiers

struct SettingsFileActions {
    static func createManualBackup(dataManager: DataManager, accountManager: AccountManager) async {
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

    static func exportAccountData(dataManager: DataManager, accountManager: AccountManager) {
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

    static func importAccountData(dataManager: DataManager, accountManager: AccountManager) {
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

    static func restoreFromBackup(dataManager: DataManager, accountManager: AccountManager, backupFile: BackupFileInfo) {
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

    static func showFolderPicker(dataManager: DataManager, onDismiss: @escaping () -> Void) {
        let panel = NSOpenPanel()
        panel.title = "选择备份目录"
        panel.message = "请选择用于保存备份文件的目录"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true

        panel.begin { response in
            DispatchQueue.main.async {
                onDismiss()

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
