// Purpose: Advanced settings tab UI, including gift discovery, gift list selection, and nursery auto-checkin controls.
// Author: Achord <achordchan@gmail.com>
import SwiftUI
import AppKit

struct SettingsAdvancedTabView: View {
    @ObservedObject var dataManager: DataManager
    @ObservedObject var accountManager: AccountManager
    @ObservedObject var viewModel: SettingsViewModel

    @Environment(\.openWindow) private var openWindow

    private var forceExchangeAccountIdBinding: Binding<String> {
        Binding(
            get: { dataManager.settings.forceExchangeAccountId ?? "" },
            set: { newValue in
                dataManager.settings.forceExchangeAccountId = newValue.isEmpty ? nil : newValue
                dataManager.saveSettings()
            }
        )
    }

    private var forceExchangeCardLevelBinding: Binding<String> {
        Binding(
            get: { dataManager.settings.forceExchangeCardLevel.map(String.init) ?? "" },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    dataManager.settings.forceExchangeCardLevel = nil
                } else {
                    dataManager.settings.forceExchangeCardLevel = Int(trimmed)
                }
                dataManager.saveSettings()
            }
        )
    }

    private var forceExchangeCardTitleBinding: Binding<String> {
        Binding(
            get: { dataManager.settings.forceExchangeCardTitle ?? "" },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                dataManager.settings.forceExchangeCardTitle = trimmed.isEmpty ? nil : trimmed
                dataManager.saveSettings()
            }
        )
    }

    private var betaSMSReceiverSignatureBinding: Binding<String> {
        Binding(
            get: { dataManager.settings.betaSMSReceiverSignature },
            set: { newValue in
                dataManager.settings.betaSMSReceiverSignature = newValue
                dataManager.saveSettings()
            }
        )
    }

    private var selectableAccounts: [AccountInfo] {
        accountManager.accounts + accountManager.nurseryAccounts
    }

    private var selectedCheckinMallText: String {
        if let mallName = dataManager.settings.autoCheckinTargetMallName,
           let mallID = dataManager.settings.autoCheckinTargetMallID {
            return "\(mallName)（\(mallID)）"
        }
        return "未选定"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                GroupBox(label: HStack {
                    Label("高级设置", systemImage: "gearshape.2.fill")
                    Spacer()
                }) {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 10) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("测试：强制兑换账号")
                                    .font(.subheadline)

                                Picker("强制兑换账号", selection: forceExchangeAccountIdBinding) {
                                    Text("不强制（默认）").tag("")
                                    ForEach(accountManager.accounts, id: \.id) { account in
                                        Text(account.username).tag(account.id.uuidString)
                                    }
                                    ForEach(accountManager.nurseryAccounts, id: \.id) { account in
                                        Text("\(account.username)（养号区）").tag(account.id.uuidString)
                                    }
                                }
                                .pickerStyle(.menu)

                                Text("仅本地测试：顶部查费用与兑换都会复用该账号；兑换时还会使用其登录信息与等级。")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("测试：伪装卡等级")
                                    .font(.subheadline)

                                HStack(spacing: 10) {
                                    Text("CardLevel")
                                        .frame(width: 90, alignment: .leading)
                                    TextField("例如：3", text: forceExchangeCardLevelBinding)
                                        .textFieldStyle(.roundedBorder)
                                }

                                HStack(spacing: 10) {
                                    Text("CardTitle")
                                        .frame(width: 90, alignment: .leading)
                                    TextField("例如：黄金卡", text: forceExchangeCardTitleBinding)
                                        .textFieldStyle(.roundedBorder)
                                }

                                Text("仅本地测试：会在兑换请求体里追加 CardLevel/CardTitle。")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            HStack(spacing: 10) {
                                Text("兑换城市编号 Mid")
                                    .frame(width: 90, alignment: .leading)
                                TextField("例如：11992（徐州）", text: $dataManager.settings.exchangeMid)
                                    .textFieldStyle(.roundedBorder)
                            }

                            Toggle("Mock 停车券列表（仅UI学习）", isOn: $dataManager.settings.mockParkingRightsForParkingView)

                            HStack(spacing: 10) {
                                Text("兑换商品编号 Gid")
                                    .frame(width: 90, alignment: .leading)
                                TextField("例如：1007561", text: $dataManager.settings.exchangeGid)
                                    .textFieldStyle(.roundedBorder)
                            }

                            Divider()

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Beta：豪猪短信签名")
                                    .font(.subheadline)

                                HStack(spacing: 10) {
                                    Text("短信签名")
                                        .frame(width: 90, alignment: .leading)
                                    TextField("例如：花园城停车", text: betaSMSReceiverSignatureBinding)
                                        .textFieldStyle(.roundedBorder)
                                }

                                Text("供“获取账号（Beta）”窗口取号时作为短信签名筛选条件。")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
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
                                .disabled(viewModel.isDiscoveringGift || selectableAccounts.isEmpty)

                                Button(viewModel.isFetchingGiftList ? "拉取中..." : "拉取停车券礼品列表") {
                                    Task {
                                        await viewModel.fetchParkingVoucherGifts(
                                            dataManager: dataManager,
                                            accountManager: accountManager
                                        )
                                    }
                                }
                                .buttonStyle(.bordered)
                                .disabled(viewModel.isFetchingGiftList || selectableAccounts.isEmpty)

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

                                                Text(
                                                    gift.source.map { "gid=\(gift.id) · \($0)" } ?? "gid=\(gift.id)"
                                                )
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
                    }
                }

                GroupBox(label: HStack {
                    Label("养号签到", systemImage: "sparkles.rectangle.stack.fill")
                    Spacer()
                    Text("养号区：\(accountManager.nurseryAccounts.count) 个")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            Text("当前已选签到商场")
                                .frame(width: 120, alignment: .leading)
                            Text(selectedCheckinMallText)
                                .foregroundColor(dataManager.settings.autoCheckinTargetMallID == nil ? .secondary : .primary)
                            Spacer()
                        }

                        Text("自动签到只会使用这里选定的商场；软件启动时和每天 00:01 会按这个配置串行签到主账号与养号区账号。")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack(spacing: 10) {
                            Button(viewModel.isQueryingCheckinMalls ? "查询中..." : "查询签到商场") {
                                Task {
                                    await viewModel.queryCheckinMallRecommendations(
                                        dataManager: dataManager,
                                        accountManager: accountManager
                                    )
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(viewModel.isQueryingCheckinMalls || accountManager.nurseryAccounts.isEmpty)

                            if accountManager.nurseryAccounts.isEmpty {
                                Text("请先把账号移入养号区，再查询推荐商场。")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("只用一个养号区账号做样本扫描，速度更快。")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }

                        if !viewModel.checkinMallQueryStatusText.isEmpty {
                            Text(viewModel.checkinMallQueryStatusText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if !viewModel.checkinMallRecommendations.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(viewModel.checkinMallRecommendations) { recommendation in
                                    HStack(alignment: .top, spacing: 12) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack(spacing: 8) {
                                                Text(recommendation.mallName)
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)

                                                if dataManager.settings.autoCheckinTargetMallID == recommendation.mallID {
                                                    Text("当前使用中")
                                                        .font(.caption)
                                                        .foregroundColor(.green)
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 4)
                                                        .background(Color.green.opacity(0.12))
                                                        .clipShape(Capsule(style: .continuous))
                                                }
                                            }

                                            Text("样本账号：可签到")
                                                .font(.caption)
                                                .foregroundColor(.secondary)

                                            Text("今日预计可得：\(recommendation.estimatedRewardText)")
                                                .font(.caption)
                                                .foregroundColor(recommendation.isComplexRule ? .orange : .secondary)

                                            Text(recommendation.ruleDescription)
                                                .font(.caption)
                                                .foregroundColor(recommendation.isComplexRule ? .orange : .secondary)
                                        }

                                        Spacer()

                                        Button("选用") {
                                            viewModel.selectAutoCheckinMall(
                                                recommendation,
                                                dataManager: dataManager,
                                                accountManager: accountManager
                                            )
                                        }
                                        .buttonStyle(.borderedProminent)
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 10)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                            }
                        }
                    }
                }

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
            .frame(maxWidth: 860)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }
}
