// Purpose: UI for viewing and restoring deleted account history.
// Author: Achord <achordchan@gmail.com>
import SwiftUI
import Foundation

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
