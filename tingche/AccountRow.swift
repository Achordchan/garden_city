// Purpose: Account card UI showing status, voucher/bonus, and actions.
// Author: Achord <achordchan@gmail.com>
import SwiftUI
import AppKit

enum AccountRowMode {
    case main
    case nursery
}

enum AccountRowLayout {
    case card
    case list
}

struct AccountRow: View {
    let account: AccountInfo
    let mode: AccountRowMode
    let layout: AccountRowLayout
    let onMoveToNursery: () -> Void
    let onMoveToMain: () -> Void
    let onDeletePermanently: () -> Void
    let onRefreshBonus: () -> Void
    let onRefreshVoucher: () -> Void
    let onExchange: () -> Void
    let onCheckin: () -> Void

    @State private var isPasswordVisible = false
    @State private var showCopiedToast = false
    @State private var copiedText = ""
    @State private var showingMoveConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var showingCheckinDetails = false

    @ObservedObject var accountManager: AccountManager
    @ObservedObject var dataManager: DataManager

    private static let checkinDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private var isCurrentProcessing: Bool {
        mode == .main && accountManager.currentProcessingAccountId == account.id
    }

    private var isMainMode: Bool {
        mode == .main
    }

    private var isListLayout: Bool {
        layout == .list
    }

    private var shouldShowNewBadge: Bool {
        isMainMode && account.isNewToMain
    }

    private var processedStatusText: String {
        account.isProcessedToday ? "已处理" : "未处理"
    }

    private var processedStatusForegroundColor: Color {
        account.isProcessedToday ? .green : .orange
    }

    private var processedStatusBackgroundColor: Color {
        account.isProcessedToday ? Color.green.opacity(0.12) : Color.orange.opacity(0.12)
    }

    private var checkinStatusText: String {
        account.hasCheckedInToday ? "已签到" : "未签到"
    }

    private var checkinStatusForegroundColor: Color {
        account.hasCheckedInToday ? .green : .secondary
    }

    private var checkinStatusBackgroundColor: Color {
        account.hasCheckedInToday ? Color.green.opacity(0.12) : Color.gray.opacity(0.12)
    }

    private var cardStrokeColor: Color {
        isCurrentProcessing ? Color.accentColor.opacity(0.9) : Color(NSColor.separatorColor).opacity(0.55)
    }

    private var voucherCountColor: Color {
        if account.voucherCount == 0 {
            return .blue
        }
        if account.voucherCount <= 3 {
            return .primary
        }
        return .green
    }

    private var shouldHighlightParking: Bool {
        isMainMode && account.isProcessedToday && account.bonus > 0 && account.voucherCount > 0
    }

    private var parkingHighlightShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 10,
            bottomLeadingRadius: 10,
            bottomTrailingRadius: 0,
            topTrailingRadius: 0
        )
    }

    private var parkingTitleColor: Color {
        shouldHighlightParking ? .accentColor : .primary
    }

    private var exchangeIconName: String {
        account.isProcessedToday ? "checkmark.circle.fill" : "checkmark"
    }

    private var exchangeIconColor: Color {
        account.isProcessedToday ? .white : .accentColor
    }

    private var exchangeHighlightShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 10,
            topTrailingRadius: 10
        )
    }

    private var checkinSummaryText: String? {
        guard account.lastCheckinDate != nil else { return nil }

        var parts: [String] = []

        if let mallName = account.lastCheckinMallName, !mallName.isEmpty {
            parts.append(mallName)
        }

        if let reward = account.lastCheckinReward, reward > 0 {
            parts.append("+\(reward)积分")
        }

        if let message = account.lastCheckinMessage, !message.isEmpty {
            parts.append(message)
        }

        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var selectedCheckinMallName: String {
        let rawName = dataManager.settings.autoCheckinTargetMallName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !rawName.isEmpty {
            return rawName
        }
        if let mallID = dataManager.settings.autoCheckinTargetMallID {
            return CheckinMallCatalog.name(for: mallID) ?? "MallID \(mallID)"
        }
        return ""
    }

    private var isCheckinInProgress: Bool {
        accountManager.activeCheckinAccountIDs.contains(account.id)
    }

    private var canPerformCheckin: Bool {
        dataManager.settings.autoCheckinTargetMallID != nil && !isCheckinInProgress
    }

    private var checkinActionHelp: String {
        if isCheckinInProgress {
            return "该账号正在签到中"
        }
        guard canPerformCheckin else {
            return "请先在设置里选定签到商场"
        }
        return "立即签到：\(selectedCheckinMallName)"
    }

    private var checkinIconName: String {
        account.hasCheckedInToday ? "calendar.badge.checkmark" : "calendar"
    }

    private var checkinIconColor: Color {
        account.hasCheckedInToday ? .green : .accentColor
    }

    private var listRowBackgroundColor: Color {
        Color(NSColor.controlBackgroundColor)
    }

    private var formattedCheckinDate: String? {
        guard let date = account.lastCheckinDate else { return nil }
        return Self.checkinDateFormatter.string(from: date)
    }

    @ViewBuilder
    private var exchangeHighlightBackground: some View {
        if account.isProcessedToday {
            exchangeHighlightShape
                .fill(Color.green.opacity(0.88))
        } else {
            exchangeHighlightShape
                .fill(Color.accentColor.opacity(0.12))
        }
    }

    @ViewBuilder
    private var exchangeHighlightOverlay: some View {
        exchangeHighlightShape
            .stroke((account.isProcessedToday ? Color.green : Color.accentColor).opacity(0.30), lineWidth: 1)
    }

    @ViewBuilder
    private var parkingHighlightBackground: some View {
        if shouldHighlightParking {
            parkingHighlightShape
                .fill(Color.accentColor.opacity(0.20))
        }
    }

    @ViewBuilder
    private var parkingHighlightOverlay: some View {
        if shouldHighlightParking {
            parkingHighlightShape
                .stroke(Color.accentColor.opacity(0.35), lineWidth: 1)
        }
    }

    private func openParkingDetails() {
        Task {
            do {
                let (isValid, newToken, uid) = try await APIService.shared.login(username: account.username, password: account.password)

                if !isValid || newToken == nil {
                    accountManager.showToast("登录失败，无法查看停车费", type: .error)
                    return
                }

                var updatedAccount = account
                updatedAccount.token = newToken
                updatedAccount.uid = uid
                await MainActor.run {
                    accountManager.updateAccount(updatedAccount)
                }

                await MainActor.run {
                    ParkingDetailWindowPresenter.present(
                        account: AccountInfo(
                            username: account.username,
                            password: account.password,
                            token: newToken,
                            uid: uid
                        ),
                        dataManager: dataManager,
                        onClose: {
                            Task {
                                await self.accountManager.refreshVoucherCount(for: self.account)
                                await self.accountManager.refreshBonus(for: self.account)
                            }
                        }
                    )
                }
            } catch {
                accountManager.showToast("打开页面失败：\(error.localizedDescription)", type: .error)
            }
        }
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func noteCardInteraction() {
        guard isMainMode else { return }
        accountManager.clearNewBadgeIfNeeded(for: account.id)
    }

    private func showCopiedHint(_ label: String) {
        copiedText = label
        showCopiedToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopiedToast = false
        }
    }

    private func statusCapsuleLabel(
        text: String,
        foreground: Color,
        background: Color
    ) -> some View {
        Text(text)
            .font(.subheadline)
            .fontWeight(.bold)
            .foregroundColor(foreground)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(background)
            .clipShape(Capsule(style: .continuous))
    }

    private func statusCapsule(
        text: String,
        foreground: Color,
        background: Color,
        help: String? = nil
    ) -> some View {
        statusCapsuleLabel(
            text: text,
            foreground: foreground,
            background: background
        )
            .help(help ?? text)
    }

    private var newBadge: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 10, height: 10)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.9), lineWidth: 1.5)
            )
            .shadow(color: Color.red.opacity(0.25), radius: 3, x: 0, y: 1)
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .leading)

            Text(value)
                .font(.callout)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var checkinDetailPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(checkinStatusText)
                .font(.headline)
                .fontWeight(.semibold)

            if let formattedCheckinDate {
                detailRow(title: "时间", value: formattedCheckinDate)
            }

            if let mallName = account.lastCheckinMallName, !mallName.isEmpty {
                detailRow(title: "商场", value: mallName)
            } else if !selectedCheckinMallName.isEmpty {
                detailRow(title: "目标", value: selectedCheckinMallName)
            }

            if let reward = account.lastCheckinReward, reward > 0 {
                detailRow(title: "奖励", value: "+\(reward) 积分")
            }

            if let message = account.lastCheckinMessage, !message.isEmpty {
                detailRow(title: "详情", value: message)
            } else if account.lastCheckinDate == nil {
                Text("暂无签到记录")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 260, alignment: .leading)
        .padding(16)
    }

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(account.username)
                    .font(.headline)
                    .onTapGesture {
                        noteCardInteraction()
                        copyToClipboard(account.username)
                        showCopiedHint("账号")
                    }
                    .help("点击复制账号")

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("积分")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(account.bonus)")
                                .font(.title3)
                                .fontWeight(.semibold)

                            Button {
                                noteCardInteraction()
                                onRefreshBonus()
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                            .buttonStyle(.plain)
                            .help("刷新积分")
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("停车券")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(account.voucherCount)")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(voucherCountColor)

                            Button {
                                noteCardInteraction()
                                onRefreshVoucher()
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                            .buttonStyle(.plain)
                            .help("刷新停车券")
                        }
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                if isCurrentProcessing {
                    ProgressView()
                        .controlSize(.small)
                        .help("正在处理")
                }

                HStack(spacing: 8) {
                    if isMainMode {
                        statusCapsule(
                            text: processedStatusText,
                            foreground: processedStatusForegroundColor,
                            background: processedStatusBackgroundColor,
                            help: processedStatusText
                        )
                    }

                    Button {
                        noteCardInteraction()
                        showingCheckinDetails = true
                    } label: {
                        statusCapsuleLabel(
                            text: checkinStatusText,
                            foreground: checkinStatusForegroundColor,
                            background: checkinStatusBackgroundColor
                        )
                    }
                    .buttonStyle(.plain)
                    .help("点击查看签到详情")
                    .popover(isPresented: $showingCheckinDetails, arrowEdge: .top) {
                        checkinDetailPopover
                    }
                }
            }
        }
    }

    private var actionButtonsSection: some View {
        HStack(spacing: 8) {
            HStack(spacing: 0) {
                if isMainMode {
                    Button {
                        noteCardInteraction()
                        openParkingDetails()
                    } label: {
                        Image(systemName: "car.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 44, height: 34)
                            .foregroundColor(parkingTitleColor)
                            .background(parkingHighlightBackground)
                            .overlay(parkingHighlightOverlay)
                    }
                    .buttonStyle(.plain)
                    .help("查看停车")

                    Divider()
                        .frame(height: 18)
                }

                Button {
                    noteCardInteraction()
                    isPasswordVisible.toggle()
                } label: {
                    Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 44, height: 34)
                }
                .buttonStyle(.plain)
                .help(isPasswordVisible ? "隐藏密码" : "查看密码")

                if isMainMode {
                    Divider()
                        .frame(height: 18)

                    Button {
                        Task {
                            noteCardInteraction()
                            if account.isProcessedToday {
                                accountManager.showToast("该账号今天已处理", type: .info)
                                return
                            }
                            onExchange()
                        }
                    } label: {
                        Image(systemName: exchangeIconName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(exchangeIconColor)
                            .frame(width: 44, height: 34)
                            .background(exchangeHighlightBackground)
                            .overlay(exchangeHighlightOverlay)
                    }
                    .buttonStyle(.plain)
                    .help(account.isProcessedToday ? "该账号今天已处理" : "兑换")
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(NSColor.separatorColor).opacity(0.35), lineWidth: 1)
            )

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                Button {
                    noteCardInteraction()
                    onCheckin()
                } label: {
                    Image(systemName: checkinIconName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(checkinIconColor)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(!canPerformCheckin)
                .help(checkinActionHelp)

                if isMainMode {
                    Button {
                        noteCardInteraction()
                        showingMoveConfirmation = true
                    } label: {
                        Image(systemName: "tray.and.arrow.down")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .help("移入养号区")
                    .alert("移入养号区", isPresented: $showingMoveConfirmation) {
                        Button("取消", role: .cancel) { }
                        Button("移入") {
                            onMoveToNursery()
                        }
                    } message: {
                        Text("确定把账号 \(account.username) 移入养号区吗？")
                    }
                } else {
                    Button {
                        onMoveToMain()
                    } label: {
                        Image(systemName: "tray.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .help("移回主账号")

                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .help("彻底删除账号")
                    .alert("彻底删除账号", isPresented: $showingDeleteConfirmation) {
                        Button("取消", role: .cancel) { }
                        Button("删除", role: .destructive) {
                            onDeletePermanently()
                        }
                    } message: {
                            Text("确定要彻底删除账号 \(account.username) 吗？删除后会进入已删除历史。")
                        }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var passwordSection: some View {
        if isPasswordVisible {
            Text(account.password)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .onTapGesture {
                    noteCardInteraction()
                    copyToClipboard(account.password)
                    showCopiedHint("密码")
                }
                .help("点击复制密码")
        }
    }

    private func listMetricSection(
        title: String,
        value: String,
        valueColor: Color = .primary,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(valueColor)

                Button {
                    noteCardInteraction()
                    action()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)
                .help(help)
            }
        }
        .frame(width: 84, alignment: .leading)
    }

    private var listIdentitySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(account.username)
                .font(.headline)
                .onTapGesture {
                    noteCardInteraction()
                    copyToClipboard(account.username)
                    showCopiedHint("账号")
                }
                .help("点击复制账号")
        }
        .frame(minWidth: 170, alignment: .leading)
    }

    private var listStatusSection: some View {
        Button {
            noteCardInteraction()
            showingCheckinDetails = true
        } label: {
            statusCapsuleLabel(
                text: checkinStatusText,
                foreground: checkinStatusForegroundColor,
                background: checkinStatusBackgroundColor
            )
        }
        .buttonStyle(.plain)
        .help("点击查看签到详情")
        .popover(isPresented: $showingCheckinDetails, arrowEdge: .top) {
            checkinDetailPopover
        }
    }

    private var listActionButtonsSection: some View {
        HStack(spacing: 8) {
            Button {
                noteCardInteraction()
                isPasswordVisible.toggle()
            } label: {
                Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .help(isPasswordVisible ? "隐藏密码" : "查看密码")

            Button {
                noteCardInteraction()
                onCheckin()
            } label: {
                Image(systemName: checkinIconName)
                    .foregroundColor(checkinIconColor)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .disabled(!canPerformCheckin)
            .help(checkinActionHelp)

            if isMainMode {
                Button {
                    noteCardInteraction()
                    showingMoveConfirmation = true
                } label: {
                    Image(systemName: "tray.and.arrow.down")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help("移入养号区")
                .alert("移入养号区", isPresented: $showingMoveConfirmation) {
                    Button("取消", role: .cancel) { }
                    Button("移入") {
                        onMoveToNursery()
                    }
                } message: {
                    Text("确定把账号 \(account.username) 移入养号区吗？")
                }
            } else {
                Button {
                    onMoveToMain()
                } label: {
                    Image(systemName: "tray.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help("移回主账号")

                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help("彻底删除账号")
                .alert("彻底删除账号", isPresented: $showingDeleteConfirmation) {
                    Button("取消", role: .cancel) { }
                    Button("删除", role: .destructive) {
                        onDeletePermanently()
                    }
                } message: {
                    Text("确定要彻底删除账号 \(account.username) 吗？删除后会进入已删除历史。")
                }
            }
        }
    }

    private var listBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 16) {
                listIdentitySection

                Spacer(minLength: 8)

                listMetricSection(
                    title: "积分",
                    value: "\(account.bonus)",
                    help: "刷新积分",
                    action: onRefreshBonus
                )

                listMetricSection(
                    title: "停车券",
                    value: "\(account.voucherCount)",
                    valueColor: voucherCountColor,
                    help: "刷新停车券",
                    action: onRefreshVoucher
                )

                listStatusSection
                    .frame(minWidth: 86, alignment: .leading)

                Spacer(minLength: 8)

                listActionButtonsSection
            }

            if isPasswordVisible {
                HStack(spacing: 10) {
                    Text("密码")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(account.password)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .onTapGesture {
                            noteCardInteraction()
                            copyToClipboard(account.password)
                            showCopiedHint("密码")
                        }
                        .help("点击复制密码")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(listRowBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(cardStrokeColor, lineWidth: 1)
        )
    }

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerSection
            VStack(alignment: .leading, spacing: 8) {
                actionButtonsSection
                passwordSection
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(cardStrokeColor, lineWidth: isCurrentProcessing ? 2 : 1)
        )
    }

    var body: some View {
        Group {
            if isListLayout {
                listBody
            } else {
                cardBody
            }
        }
        .overlay(
            Group {
                if showCopiedToast {
                    Text("\(copiedText)已复制")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.8))
                        .clipShape(Capsule(style: .continuous))
                        .transition(.opacity)
                        .padding(.top, 8)
                }
            },
            alignment: .top
        )
        .overlay(
            Group {
                if shouldShowNewBadge {
                    newBadge
                        .padding(.top, 10)
                        .padding(.trailing, 10)
                }
            },
            alignment: .topTrailing
        )
        .animation(.easeInOut, value: showCopiedToast)
    }
}
