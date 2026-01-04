// Purpose: Advanced settings tab UI, including gift discovery and gift list selection.
// Author: Achord <achordchan@gmail.com>
import SwiftUI
import AppKit

struct SettingsAdvancedTabView: View {
    @ObservedObject var dataManager: DataManager
    @ObservedObject var accountManager: AccountManager
    @ObservedObject var viewModel: SettingsViewModel

    @Binding var advancedKeyInput: String
    @Binding var isAdvancedUnlocked: Bool

    @Environment(\.openWindow) private var openWindow

    var body: some View {
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

                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 10) {
                                    Text("兑换城市编号 Mid")
                                        .frame(width: 90, alignment: .leading)
                                    TextField("例如：11992（徐州）", text: $dataManager.settings.exchangeMid)
                                        .textFieldStyle(.roundedBorder)
                                }

                                HStack(spacing: 10) {
                                    Text("兑换商品编号 Gid")
                                        .frame(width: 90, alignment: .leading)
                                    TextField("例如：1007561", text: $dataManager.settings.exchangeGid)
                                        .textFieldStyle(.roundedBorder)
                                }

                                HStack {
                                    Button(viewModel.isDiscoveringGift ? "识别中..." : "自动识别停车券商品") {
                                        Task {
                                            await viewModel.discoverParkingVoucherGift(
                                                dataManager: dataManager,
                                                accountManager: accountManager
                                            )
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(viewModel.isDiscoveringGift)

                                    Button(viewModel.isFetchingGiftList ? "拉取中..." : "拉取停车券礼品列表") {
                                        Task {
                                            await viewModel.fetchParkingVoucherGifts(
                                                dataManager: dataManager,
                                                accountManager: accountManager
                                            )
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(viewModel.isFetchingGiftList)

                                    Button("查看日志") {
                                        openWindow(id: "logs")
                                    }
                                    .buttonStyle(.bordered)

                                    Spacer()
                                }

                                if !viewModel.parkingVoucherGifts.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("停车券礼品（\(viewModel.parkingVoucherGifts.count)）")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)

                                        ForEach(viewModel.parkingVoucherGifts, id: \.id) { gift in
                                            HStack(alignment: .top, spacing: 10) {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(gift.n)
                                                        .font(.subheadline)

                                                    Text("gid=\(gift.id)")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }

                                                Spacer()

                                                Button("选用") {
                                                    dataManager.settings.exchangeGid = String(gift.id)
                                                    dataManager.saveSettings()
                                                    accountManager.showToast("已选用：\(gift.n)（gid=\(gift.id)）", type: .success)
                                                }
                                                .buttonStyle(.borderedProminent)
                                            }
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 10)
                                            .background(Color(NSColor.controlBackgroundColor))
                                            .cornerRadius(8)
                                        }
                                    }
                                }
                            }
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
}
