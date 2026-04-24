// Purpose: Advanced settings tab UI, including gift discovery, gift list selection, and nursery auto-checkin controls.
// Author: Achord <achordchan@gmail.com>
import SwiftUI
import AppKit

struct SettingsAdvancedTabView: View {
    @ObservedObject var dataManager: DataManager
    @ObservedObject var accountManager: AccountManager
    @ObservedObject var viewModel: SettingsViewModel

    @Environment(\.openWindow) private var openWindow
    @State private var showDebugTools = false

    private static let integerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = 0
        formatter.maximum = 99999
        return formatter
    }()

    private var nurseryAutoPromoteBonusThresholdBinding: Binding<Int> {
        Binding(
            get: { max(0, dataManager.settings.nurseryAutoPromoteBonusThreshold) },
            set: { newValue in
                dataManager.settings.nurseryAutoPromoteBonusThreshold = max(0, newValue)
                dataManager.saveSettingsDebounced(rebuildAutoBackup: false)
            }
        )
    }

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
                    Label("兑换与自动化", systemImage: "arrow.triangle.2.circlepath")
                    Spacer()
                }) {
                    VStack(alignment: .leading, spacing: 16) {
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
                                Button(viewModel.isDiscoveringGift ? "识别中..." : "识别停车券商品") {
                                    Task {
                                        await viewModel.discoverParkingVoucherGift(
                                            dataManager: dataManager,
                                            accountManager: accountManager
                                        )
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(viewModel.isDiscoveringGift || selectableAccounts.isEmpty)

                                Button(viewModel.isFetchingGiftList ? "获取中..." : "获取礼品列表") {
                                    Task {
                                        await viewModel.fetchParkingVoucherGifts(
                                            dataManager: dataManager,
                                            accountManager: accountManager
                                        )
                                    }
                                }
                                .buttonStyle(.bordered)
                                .disabled(viewModel.isFetchingGiftList || selectableAccounts.isEmpty)

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

                        Divider()

                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                Text("签到商场")
                                    .frame(width: 120, alignment: .leading)
                                Text(selectedCheckinMallText)
                                    .foregroundColor(dataManager.settings.autoCheckinTargetMallID == nil ? .secondary : .primary)
                                Spacer()
                            }

                            HStack(spacing: 10) {
                                Text("回流积分阈值")
                                    .frame(width: 120, alignment: .leading)
                                TextField(
                                    "积分阈值",
                                    value: nurseryAutoPromoteBonusThresholdBinding,
                                    formatter: Self.integerFormatter
                                )
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 120)

                                Stepper("每次 ±100", value: nurseryAutoPromoteBonusThresholdBinding, in: 0...99999, step: 100)
                                    .frame(minWidth: 180)

                                Text("\(dataManager.settings.nurseryAutoPromoteBonusThreshold) 积分")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }

                            Text("自动签到只会使用这里选定的商场；软件启动时和每天 00:01 会按这个配置串行签到主账号与养号区账号。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("养号区账号积分达到该阈值后，会自动移回主账号区。")
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
                }

                GroupBox(label: HStack {
                    Label("调试工具", systemImage: "wrench.and.screwdriver.fill")
                    Spacer()
                }) {
                    DisclosureGroup(isExpanded: $showDebugTools) {
                        VStack(alignment: .leading, spacing: 14) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("兑换账号覆盖（调试）")
                                    .font(.subheadline)

                                Picker("兑换账号覆盖", selection: forceExchangeAccountIdBinding) {
                                    Text("不覆盖（默认）").tag("")
                                    ForEach(accountManager.accounts, id: \.id) { account in
                                        Text(account.username).tag(account.id.uuidString)
                                    }
                                    ForEach(accountManager.nurseryAccounts, id: \.id) { account in
                                        Text("\(account.username)（养号区）").tag(account.id.uuidString)
                                    }
                                }
                                .pickerStyle(.menu)

                                Text("用于排查问题。日常建议保持默认。")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("卡等级覆盖（调试）")
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

                                Text("用于排查兑换参数。日常建议保持默认。")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Toggle("演示数据模式（调试）", isOn: $dataManager.settings.mockParkingRightsForParkingView)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("短信签名筛选（Beta）")
                                    .font(.subheadline)

                                HStack(spacing: 10) {
                                    Text("短信签名")
                                        .frame(width: 90, alignment: .leading)
                                    TextField("例如：花园城停车", text: betaSMSReceiverSignatureBinding)
                                        .textFieldStyle(.roundedBorder)
                                }

                                Text("供“获取账号（Beta）”窗口筛选接码手机号。")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            HStack {
                                Button("查看日志") {
                                    openWindow(id: "logs")
                                }
                                .buttonStyle(.bordered)
                                Spacer()
                            }
                        }
                    } label: {
                        Text("默认收起，排查问题时再展开")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
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
