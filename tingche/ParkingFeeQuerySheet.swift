// Purpose: Native parking fee query sheet attached to the main window.
// Author: Achord <achordchan@gmail.com>
import SwiftUI

private enum ParkingFeeQuerySheetError: LocalizedError {
    case missingPlate
    case missingForcedAccount
    case forcedAccountNotFound
    case loginFailed

    var errorDescription: String? {
        switch self {
        case .missingPlate:
            return "请先选择车牌号"
        case .missingForcedAccount:
            return "请先到高级设置选择“强制兑换账号”"
        case .forcedAccountNotFound:
            return "当前强制兑换账号已不存在，请重新选择"
        case .loginFailed:
            return "登录失败，无法查询停车费"
        }
    }
}

struct ParkingFeeQuerySheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var accountManager: AccountManager
    @ObservedObject var dataManager: DataManager

    @State private var didAutoQuery = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var result: APIService.ParkingFeeQueryResult?
    @State private var preparedAccount: AccountInfo?

    private var selectedPlate: String {
        dataManager.settings.selectedLicensePlate.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("查费用")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("当前车牌：\(selectedPlate.isEmpty ? "未选择" : selectedPlate)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("关闭") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }

            Divider()

            Group {
                if isLoading {
                    loadingView
                } else if let errorMessage {
                    failureView(message: errorMessage)
                } else if let result {
                    successView(result: result)
                } else {
                    Text("暂无查费结果")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Divider()

            HStack {
                Button("关闭") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)

                Button("重新查询") {
                    Task {
                        await performQuery()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)

                Spacer()

                Button("打开停车详情页") {
                    openParkingDetails()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading || preparedAccount == nil || result == nil)
            }
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 440)
        .task {
            guard !didAutoQuery else { return }
            didAutoQuery = true
            await performQuery()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("正在查询停车费用...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func failureView(message: String) -> some View {
        VStack(alignment: .center, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 30))
                .foregroundColor(.orange)

            Text("查询失败")
                .font(.headline)

            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func successView(result: APIService.ParkingFeeQueryResult) -> some View {
        ScrollView {
            VStack(spacing: 10) {
                parkingInfoRow(title: "车牌号", value: displayText(result.plateNo))
                parkingInfoRow(title: "商场名", value: displayText(result.mallName))
                parkingInfoRow(title: "车场名", value: displayText(result.parkName))
                parkingInfoRow(title: "入场时间", value: displayText(result.entryTime))
                parkingInfoRow(title: "停车时长", value: "\(result.parkingMinutes) 分钟")
                parkingInfoRow(title: "停车总费", value: currencyText(result.parkingTotalFee))
                parkingInfoRow(title: "待付金额", value: currencyText(result.needPayAmount))
                parkingInfoRow(title: "已付金额", value: currencyText(result.paidAmount))
                parkingInfoRow(title: "免费金额", value: currencyText(result.freeAmount))
                parkingInfoRow(title: "可用会员权益", value: displayText(result.memberRightsSummary ?? "未发现"))
                parkingInfoRow(title: "FeeId", value: displayText(result.feeId), monospaced: true)
            }
            .padding(.vertical, 4)
        }
    }

    private func parkingInfoRow(title: String, value: String, monospaced: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .foregroundColor(.secondary)
                .frame(width: 84, alignment: .leading)

            if monospaced {
                Text(value)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(value)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func displayText(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "未返回" : trimmed
    }

    private func currencyText(_ amount: Double) -> String {
        String(format: "%.2f 元", amount / 100)
    }

    private func resolveErrorMessage(_ error: Error) -> String {
        if let apiError = error as? APIService.APIError {
            return apiError.message
        }
        return error.localizedDescription
    }

    @MainActor
    private func currentQueryContext() throws -> (AccountInfo, String) {
        let plate = dataManager.settings.selectedLicensePlate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !plate.isEmpty else {
            throw ParkingFeeQuerySheetError.missingPlate
        }

        guard let forcedAccountId = dataManager.settings.forceExchangeAccountId, !forcedAccountId.isEmpty else {
            throw ParkingFeeQuerySheetError.missingForcedAccount
        }

        guard let account = accountManager.allManagedAccounts().first(where: { $0.id.uuidString == forcedAccountId }) else {
            throw ParkingFeeQuerySheetError.forcedAccountNotFound
        }

        return (account, plate)
    }

    private func loginAndPrepareAccount(_ account: AccountInfo) async throws -> AccountInfo {
        let (isValid, token, uid) = try await APIService.shared.login(username: account.username, password: account.password)
        guard isValid, let token, let uid else {
            throw ParkingFeeQuerySheetError.loginFailed
        }

        let updatedAccount = AccountInfo(
            id: account.id,
            username: account.username,
            password: account.password,
            token: token,
            voucherCount: account.voucherCount,
            isProcessedToday: account.isProcessedToday,
            bonus: account.bonus,
            uid: uid
        )

        await MainActor.run {
            if let index = accountManager.accounts.firstIndex(where: { $0.id == account.id }) {
                accountManager.accounts[index] = updatedAccount
                accountManager.saveAccounts()
            } else if let index = accountManager.nurseryAccounts.firstIndex(where: { $0.id == account.id }) {
                accountManager.nurseryAccounts[index] = updatedAccount
                accountManager.saveNurseryAccounts()
            }
        }

        return updatedAccount
    }

    private func performQuery() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
            result = nil
            preparedAccount = nil
        }

        do {
            let (account, plate) = try await MainActor.run {
                try currentQueryContext()
            }
            let updatedAccount = try await loginAndPrepareAccount(account)
            guard let token = updatedAccount.token, let uid = updatedAccount.uid else {
                throw ParkingFeeQuerySheetError.loginFailed
            }

            let queryResult = try await APIService.shared.queryParkingFee(token: token, uid: uid, plateNo: plate)

            await MainActor.run {
                preparedAccount = updatedAccount
                result = queryResult
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = resolveErrorMessage(error)
                isLoading = false
            }
        }
    }

    private func openParkingDetails() {
        guard let preparedAccount else { return }
        ParkingDetailWindowPresenter.present(
            account: preparedAccount,
            dataManager: dataManager,
            onClose: {
                Task {
                    await accountManager.refreshVoucherCount(for: preparedAccount)
                    await accountManager.refreshBonus(for: preparedAccount)
                }
            }
        )
    }
}
