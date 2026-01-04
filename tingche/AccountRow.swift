// Purpose: Account card UI showing status, voucher/bonus, and actions.
// Author: Achord <achordchan@gmail.com>
import SwiftUI
import AppKit

struct AccountRow: View {
    let account: AccountInfo
    let onDelete: () -> Void
    let onRefreshBonus: () -> Void
    let onRefreshVoucher: () -> Void
    let onExchange: () -> Void
    @State private var isPasswordVisible = false
    @State private var isRefreshing = false
    @State private var showCopiedToast = false
    @State private var copiedText = ""
    @ObservedObject var accountManager: AccountManager
    @ObservedObject var dataManager: DataManager
    @State private var showingDeleteConfirmation = false
    
    var isCurrentProcessing: Bool {
        accountManager.currentProcessingAccountId == account.id
    }

    private var statusText: String {
        account.isProcessedToday ? "已处理" : "未处理"
    }

    private var statusForegroundColor: Color {
        account.isProcessedToday ? .green : .orange
    }

    private var statusBackgroundColor: Color {
        account.isProcessedToday ? Color.green.opacity(0.12) : Color.orange.opacity(0.12)
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
        account.isProcessedToday && account.bonus > 0 && account.voucherCount > 0
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
                // 先刷新登录状态获取新token
                let (isValid, newToken, uid) = try await APIService.shared.login(username: account.username, password: account.password)
                
                if !isValid || newToken == nil {
                    accountManager.showToast("登录失败，无法查看停车费", type: .error)
                    return
                }
                
                // 更新账号信息
                if let index = accountManager.accounts.firstIndex(where: { $0.id == account.id }) {
                    var updatedAccount = accountManager.accounts[index]
                    updatedAccount.token = newToken
                    updatedAccount.uid = uid
                    accountManager.accounts[index] = updatedAccount
                    accountManager.saveAccounts()
                }
                
                // 创建和显示窗口，添加关闭回调
                DispatchQueue.main.async {
                    let controller = WebViewWindowController(
                        account: AccountInfo(
                            username: account.username,
                            password: account.password,
                            token: newToken,
                            uid: uid
                        ),
                        dataManager: dataManager,
                        onClose: {
                            // 窗口关闭时刷新停车券数量
                            Task {
                                await self.accountManager.refreshVoucherCount(for: self.account)
                            }
                        }
                    )
                    // 保持对 controller 的强引用，直到窗口关闭
                    controller.window?.delegate = controller
                    controller.showWindow(nil)
                }
                
            } catch {
                accountManager.showToast("打开页面失败：\(error.localizedDescription)", type: .error)
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(account.username)
                        .font(.headline)
                        .onTapGesture {
                            copyToClipboard(account.username)
                            copiedText = "账号"
                            showCopiedToast = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showCopiedToast = false
                            }
                        }
                        .help("点击复制账号")

                    HStack(spacing: 12) {
                        HStack(spacing: 6) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("积分")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Text("\(account.bonus)")
                                        .font(.title3)
                                        .fontWeight(.semibold)

                                    Button(action: onRefreshBonus) {
                                        Image(systemName: "arrow.clockwise")
                                    }
                                    .buttonStyle(.plain)
                                    .help("刷新积分")
                                }
                            }
                        }

                        HStack(spacing: 6) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("停车券")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Text("\(account.voucherCount)")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundColor(voucherCountColor)

                                    Button(action: onRefreshVoucher) {
                                        Image(systemName: "arrow.clockwise")
                                    }
                                    .buttonStyle(.plain)
                                    .help("刷新停车券")
                                }
                            }
                        }
                    }
                }

                Spacer()

                HStack(spacing: 10) {
                    if isCurrentProcessing {
                        ProgressView()
                            .controlSize(.small)
                            .help("正在处理")
                    }

                    Text(statusText)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(statusForegroundColor)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(statusBackgroundColor.opacity(1.25))
                        .clipShape(Capsule(style: .continuous))
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    HStack(spacing: 0) {
                        Button {
                            openParkingDetails()
                        } label: {
                            Label("查看停车", systemImage: "car.fill")
                                .labelStyle(.titleAndIcon)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .foregroundColor(parkingTitleColor)
                                .background(parkingHighlightBackground)
                                .overlay(parkingHighlightOverlay)
                        }
                        .buttonStyle(.plain)
                        .help("查看停车")

                        Divider()
                            .frame(height: 18)

                        Button {
                            isPasswordVisible.toggle()
                        } label: {
                            Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(width: 44, height: 34)
                        }
                        .buttonStyle(.plain)
                        .help(isPasswordVisible ? "隐藏密码" : "查看密码")

                        Divider()
                            .frame(height: 18)

                        Button {
                            Task {
                                if account.isProcessedToday {
                                    accountManager.showToast("该账号今天已处理", type: .info)
                                    return
                                }
                                await onExchange()
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
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color(NSColor.separatorColor).opacity(0.35), lineWidth: 1)
                    )

                    Spacer(minLength: 8)

                    Button {
                        showingDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .help("删除该账号")
                    .alert("确认删除", isPresented: $showingDeleteConfirmation) {
                        Button("取消", role: .cancel) { }
                        Button("删除", role: .destructive) {
                            onDelete()
                        }
                    } message: {
                        Text("确定要删除账号 \(account.username) 吗？此操作不可撤销。")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

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
                            copyToClipboard(account.password)
                            copiedText = "密码"
                            showCopiedToast = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showCopiedToast = false
                            }
                        }
                        .help("点击复制密码")
                }
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
        .animation(.easeInOut, value: showCopiedToast)
    }
    
    // 添加复制到剪贴板的辅助函数
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
