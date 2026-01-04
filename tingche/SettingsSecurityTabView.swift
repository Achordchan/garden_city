// Purpose: Settings security/backup tab UI (backup settings, import/export, restore, deleted accounts).
// Author: Achord <achordchan@gmail.com>
import SwiftUI

struct SettingsSecurityTabView: View {
    @ObservedObject var dataManager: DataManager
    @ObservedObject var accountManager: AccountManager

    @Binding var showingFolderPicker: Bool
    @Binding var showingDeletedAccountsView: Bool
    @Binding var showingBackupListView: Bool

    let createManualBackup: () async -> Void
    let exportAccountData: () -> Void
    let importAccountData: () -> Void

    private static let integerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = 0
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    var body: some View {
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
}
