// Purpose: Backup list UI for viewing and restoring backup files.
// Author: Achord <achordchan@gmail.com>
import SwiftUI
import Foundation
import AppKit

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
            try? FileManager.default.removeItem(atPath: backupFile.filePath)
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
