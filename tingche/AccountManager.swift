// Purpose: Observable store that manages accounts and orchestrates login, refresh, exchange, and batch operations.
// Author: Achord <achordchan@gmail.com>
import Foundation
import SwiftUI

// 账号管理类
class AccountManager: ObservableObject {
    static let shared = AccountManager()

    @Published var accounts: [AccountInfo] = []
    @Published var nurseryAccounts: [AccountInfo] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var showToast = false
    @Published var toastMessage = ""
    @Published var toastType: ToastType = .success
    @Published var isExecutingAll = false
    @Published var currentProcessingAccountId: UUID?
    @Published var isAutoCheckinRunning = false
    @Published var autoCheckinProgressCurrent = 0
    @Published var autoCheckinProgressTotal = 0
    @Published var autoCheckinProgressText = ""
    @Published var autoCheckinCurrentAccountUsername: String?
    @Published private(set) var activeCheckinAccountIDs: Set<UUID> = []
    private let accountsKey = "savedAccounts"
    private let nurseryAccountsKey = "nurseryAccounts"
    private let lastResetDateKey = "lastResetDate"
    private var resetTimer: Timer?

    enum AccountStorageSection {
        case main
        case nursery
    }

    enum ToastType {
        case success
        case error
        case info

        var backgroundColor: Color {
            switch self {
            case .success: return Color.green.opacity(0.9)
            case .error: return Color.red.opacity(0.9)
            case .info: return Color.blue.opacity(0.9)
            }
        }

        var iconName: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "exclamationmark.circle.fill"
            case .info: return "info.circle.fill"
            }
        }
    }

    func showToast(_ message: String, type: ToastType) {
        Task { @MainActor in
            let typeText: String
            switch type {
            case .success: typeText = "SUCCESS"
            case .error: typeText = "ERROR"
            case .info: typeText = "INFO"
            }
            LogStore.shared.add(category: "UI", "TOAST[\(typeText)]: \(message)")
        }

        DispatchQueue.main.async {
            self.toastMessage = message
            self.toastType = type
            self.showToast = true

            // 3秒后自动隐藏
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.showToast = false
            }
        }
    }

    init() {
        loadAccounts()
        loadNurseryAccounts()
        checkAndResetStatus()
        setupResetTimer()
        setupNotificationObservers()
    }

    deinit {
        resetTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    // 设置定时器在每天0点重置状态
    private func setupResetTimer() {
        // 获取下一个0点的时间
        let now = Date()
        let calendar = Calendar.current
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
              let nextMidnight = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: tomorrow) else {
            return
        }

        // 计算到下一个0点的时间间隔
        let timeInterval = nextMidnight.timeIntervalSince(now)

        // 设置定时器
        resetTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
            self?.resetAllProcessedStatus()
            // 重新设置下一天的定时器
            self?.setupResetTimer()
        }
    }

    // 添加检查和重置状态的方法
    private func checkAndResetStatus() {
        let calendar = Calendar.current
        let now = Date()

        // 获取上次重置的日期（如果没有，默认为很早以前的日期）
        let lastResetDate = UserDefaults.standard.object(forKey: lastResetDateKey) as? Date ?? Date.distantPast

        // 检查是否是不同的日期
        if !calendar.isDate(lastResetDate, inSameDayAs: now) {
            resetAllAccountStatuses(clearCheckinStatus: true)
            saveAccounts()
            saveNurseryAccounts()

            // 更新最后重置日期
            UserDefaults.standard.set(now, forKey: lastResetDateKey)
            print("软件启动时检测到新的一天，已重置所有账号状态")
        }
    }

    // 修改原有的重置方法，同时更新最后重置日期
    func resetAllProcessedStatus() {
        DispatchQueue.main.async {
            self.resetAllAccountStatuses(clearCheckinStatus: true)
            self.saveAccounts()
            self.saveNurseryAccounts()

            // 更新最后重置日期
            UserDefaults.standard.set(Date(), forKey: self.lastResetDateKey)
            self.showToast("已重置所有账号的处理状态", type: .info)
        }
    }

    func resetDailyStatusesIfNeeded() {
        let calendar = Calendar.current
        let now = Date()
        let lastResetDate = UserDefaults.standard.object(forKey: lastResetDateKey) as? Date ?? Date.distantPast

        guard !calendar.isDate(lastResetDate, inSameDayAs: now) else {
            return
        }

        DispatchQueue.main.async {
            self.resetAllAccountStatuses(clearCheckinStatus: true)
            self.saveAccounts()
            self.saveNurseryAccounts()
            UserDefaults.standard.set(now, forKey: self.lastResetDateKey)
            LogStore.shared.add(category: "CHECKIN", "跨天重置账号状态完成")
        }
    }

    // 加载账号
    private func loadAccounts() {
        if let data = UserDefaults.standard.data(forKey: accountsKey) {
            do {
                accounts = try JSONDecoder().decode([AccountInfo].self, from: data)
                print("成功加载\(accounts.count)个账号")
            } catch {
                print("加载账号失败: \(error.localizedDescription)")
            }
        } else {
            print("没有找到保存的账号数据")
        }
    }

    private func loadNurseryAccounts() {
        if let data = UserDefaults.standard.data(forKey: nurseryAccountsKey) {
            do {
                nurseryAccounts = try JSONDecoder().decode([AccountInfo].self, from: data)
                print("成功加载\(nurseryAccounts.count)个养号账号")
            } catch {
                print("加载养号账号失败: \(error.localizedDescription)")
            }
        }
    }

    // 保存账号
    func saveAccounts() {
        do {
            let data = try JSONEncoder().encode(accounts)
            UserDefaults.standard.set(data, forKey: accountsKey)
            print("成功保存\(accounts.count)个账号")
            NotificationCenter.default.post(name: .accountsStorageDidChange, object: self)
        } catch {
            print("保存账号失败: \(error.localizedDescription)")
        }
    }

    func saveNurseryAccounts() {
        do {
            let data = try JSONEncoder().encode(nurseryAccounts)
            UserDefaults.standard.set(data, forKey: nurseryAccountsKey)
            print("成功保存\(nurseryAccounts.count)个养号账号")
            NotificationCenter.default.post(name: .accountsStorageDidChange, object: self)
        } catch {
            print("保存养号账号失败: \(error.localizedDescription)")
        }
    }

    private func resetAllAccountStatuses(clearCheckinStatus: Bool) {
        for index in accounts.indices {
            accounts[index].isProcessedToday = false
            if clearCheckinStatus {
                accounts[index].resetTodayCheckinStatus()
            }
        }

        for index in nurseryAccounts.indices {
            nurseryAccounts[index].isProcessedToday = false
            if clearCheckinStatus {
                nurseryAccounts[index].resetTodayCheckinStatus()
            }
        }
    }

    // 添加检查手机号是否存在的方法
    func isPhoneNumberExists(_ phoneNumber: String) -> Bool {
        accounts.contains { $0.username == phoneNumber }
            || nurseryAccounts.contains { $0.username == phoneNumber }
    }

    func accountLocation(for accountID: UUID) -> AccountStorageSection? {
        if accounts.contains(where: { $0.id == accountID }) {
            return .main
        }
        if nurseryAccounts.contains(where: { $0.id == accountID }) {
            return .nursery
        }
        return nil
    }

    func accountLocation(forUsername username: String) -> AccountStorageSection? {
        if accounts.contains(where: { $0.username == username }) {
            return .main
        }
        if nurseryAccounts.contains(where: { $0.username == username }) {
            return .nursery
        }
        return nil
    }

    func accountLocationText(forUsername username: String) -> String? {
        switch accountLocation(forUsername: username) {
        case .main:
            return "已在主窗口"
        case .nursery:
            return "已在养号区"
        case nil:
            return nil
        }
    }

    func allManagedAccounts() -> [AccountInfo] {
        accounts + nurseryAccounts
    }

    func importDeletedAccountsToNurseryIfNeeded(_ deletedAccounts: [DeletedAccountRecord]) {
        var importedUsernames = Set<String>()
        let uniqueAccounts = deletedAccounts.compactMap { record -> AccountInfo? in
            guard importedUsernames.insert(record.accountInfo.username).inserted else {
                return nil
            }
            guard !isPhoneNumberExists(record.accountInfo.username) else {
                return nil
            }
            return record.accountInfo
        }

        guard !uniqueAccounts.isEmpty else { return }
        nurseryAccounts.append(contentsOf: uniqueAccounts)
        saveNurseryAccounts()
    }

    func moveAccountToNursery(account: AccountInfo) {
        guard let index = accounts.firstIndex(where: { $0.id == account.id }) else { return }
        let accountToMove = accounts[index]
        guard !hasConflictingNurseryAccount(for: accountToMove) else {
            showToast("移入失败：养号区已存在同手机号账号", type: .error)
            return
        }

        accounts.remove(at: index)
        nurseryAccounts.removeAll { $0.id == accountToMove.id }
        nurseryAccounts.append(accountToMove)
        saveAccounts()
        saveNurseryAccounts()
        showToast("已移入养号区：\(account.username)", type: .info)
    }

    private func prepareMainAccount(_ account: AccountInfo, markAsNew: Bool) -> AccountInfo {
        var preparedAccount = account
        if markAsNew {
            preparedAccount.isNewToMain = true
        }
        return preparedAccount
    }

    private func hasConflictingAccount(in source: [AccountInfo], for account: AccountInfo) -> Bool {
        guard let existingAccount = source.first(where: { $0.username == account.username }) else {
            return false
        }
        return existingAccount.id != account.id
    }

    private func hasConflictingMainAccount(for account: AccountInfo) -> Bool {
        hasConflictingAccount(in: accounts, for: account)
    }

    private func hasConflictingNurseryAccount(for account: AccountInfo) -> Bool {
        hasConflictingAccount(in: nurseryAccounts, for: account)
    }

    @discardableResult
    func insertAccountIntoMain(_ account: AccountInfo, markAsNew: Bool = true) -> AccountInfo? {
        let preparedAccount = prepareMainAccount(account, markAsNew: markAsNew)
        if let existingIndex = accounts.firstIndex(where: { $0.id == preparedAccount.id }) {
            accounts[existingIndex] = preparedAccount
            return preparedAccount
        }

        guard !hasConflictingMainAccount(for: preparedAccount) else {
            return nil
        }

        accounts.append(preparedAccount)
        return preparedAccount
    }

    @discardableResult
    func insertAccountsIntoMain(_ newAccounts: [AccountInfo], markAsNew: Bool = true) -> Int {
        var insertedCount = 0
        for account in newAccounts {
            if insertAccountIntoMain(account, markAsNew: markAsNew) != nil {
                insertedCount += 1
            }
        }
        return insertedCount
    }

    @discardableResult
    func insertAccountIntoNursery(_ account: AccountInfo) -> AccountInfo? {
        if let existingIndex = nurseryAccounts.firstIndex(where: { $0.id == account.id }) {
            nurseryAccounts[existingIndex] = account
            return account
        }

        guard !accounts.contains(where: { $0.username == account.username }),
              !hasConflictingNurseryAccount(for: account) else {
            return nil
        }

        nurseryAccounts.append(account)
        return account
    }

    @discardableResult
    func insertAccountsIntoNursery(_ newAccounts: [AccountInfo]) -> Int {
        var insertedCount = 0
        for account in newAccounts {
            if insertAccountIntoNursery(account) != nil {
                insertedCount += 1
            }
        }
        return insertedCount
    }

    func moveNurseryAccountToMain(account: AccountInfo) {
        guard let index = nurseryAccounts.firstIndex(where: { $0.id == account.id }) else { return }
        let accountToMove = nurseryAccounts[index]
        guard !hasConflictingMainAccount(for: accountToMove) else {
            showToast("移回失败：主账号区已存在同手机号账号", type: .error)
            return
        }

        nurseryAccounts.remove(at: index)
        guard insertAccountIntoMain(accountToMove, markAsNew: true) != nil else {
            nurseryAccounts.insert(accountToMove, at: index)
            showToast("移回失败：主账号区已存在同手机号账号", type: .error)
            return
        }
        saveAccounts()
        saveNurseryAccounts()
        showToast("已移回主账号：\(account.username)", type: .success)
    }

    func permanentlyDeleteNurseryAccount(account: AccountInfo) {
        guard let index = nurseryAccounts.firstIndex(where: { $0.id == account.id }) else { return }
        let username = nurseryAccounts[index].username

        NotificationCenter.default.post(
            name: .accountDeleted,
            object: nurseryAccounts[index],
            userInfo: ["reason": "养号区彻底删除"]
        )

        nurseryAccounts.remove(at: index)
        saveNurseryAccounts()
        showToast("已彻底删除账号：\(username)", type: .info)
    }

    @MainActor
    @discardableResult
    func promoteNurseryAccountIfNeeded(accountID: UUID, trigger: String? = nil) -> Bool {
        guard let nurseryIndex = nurseryAccounts.firstIndex(where: { $0.id == accountID }) else {
            return false
        }

        let account = nurseryAccounts[nurseryIndex]
        guard account.bonus >= 100 else {
            return false
        }

        guard !hasConflictingMainAccount(for: account) else {
            LogStore.shared.add(category: "CHECKIN", "跳过自动回流：主账号区已存在同手机号账号 \(account.username)")
            return false
        }

        nurseryAccounts.remove(at: nurseryIndex)
        guard insertAccountIntoMain(account, markAsNew: true) != nil else {
            nurseryAccounts.insert(account, at: nurseryIndex)
            LogStore.shared.add(category: "CHECKIN", "自动回流失败：主账号区已存在同手机号账号 \(account.username)")
            return false
        }
        saveAccounts()
        saveNurseryAccounts()

        let suffix = trigger.map { "（\($0)）" } ?? ""
        showToast("账号 \(account.username) 已回到主窗口\(suffix)", type: .success)
        return true
    }

    func clearNewBadgeIfNeeded(for accountID: UUID) {
        guard let index = accounts.firstIndex(where: { $0.id == accountID }) else { return }
        guard accounts[index].isNewToMain else { return }
        accounts[index].isNewToMain = false
        saveAccounts()
    }

    // 修改添加账号的方法
    func addAccountWithValidation(username: String, password: String) async -> Bool {
        // 先检查手机号是否已存在
        if isPhoneNumberExists(username) {
            await MainActor.run {
                self.errorMessage = "该手机号已存在，请勿重复添加"
                self.showToast("该手机号已存在，请勿重复添加", type: .error)
            }
            return false
        }

        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
            self.successMessage = nil
        }

        do {
            let (isValid, token, uid) = try await APIService.shared.login(username: username, password: password)

            if isValid, let token {
                await MainActor.run {
                    self.successMessage = "登录成功！Token: \(token), UID: \(uid ?? "")"
                    self.addAccount(username: username, password: password, token: token, uid: uid)
                    self.isLoading = false
                }
                return true
            } else {
                await MainActor.run {
                    self.errorMessage = self.errorMessage ?? "登录失败，请检查账号密码"
                    self.isLoading = false
                }
                return false
            }
        } catch let error as APIService.APIError {
            await MainActor.run {
                self.errorMessage = error.message
                self.isLoading = false
            }
            return false
        } catch {
            await MainActor.run {
                self.errorMessage = "网络错误：\(error.localizedDescription)"
                self.isLoading = false
            }
            return false
        }
    }

    // 添加账号
    func addAccount(username: String, password: String, token: String? = nil, uid: String? = nil) {
        let account = AccountInfo(username: username, password: password, token: token, uid: uid)
        guard let insertedAccount = insertAccountIntoMain(account, markAsNew: true) else {
            showToast("该手机号已存在，请勿重复添加", type: .error)
            return
        }
        saveAccounts()
        Task {
            await refreshBonus(for: insertedAccount)
        }
    }

    // 删除账号
    func deleteAccount(account: AccountInfo) {
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            let username = account.username

            // 通知 DataManager 记录删除操作
            NotificationCenter.default.post(
                name: .accountDeleted,
                object: account,
                userInfo: ["reason": "用户手动删除"]
            )

            accounts.remove(at: index)
            saveAccounts()
            showToast("已删除账号：\(username)", type: .info)
        }
    }

    @MainActor
    private func updateAccount(
        withID accountID: UUID,
        in section: AccountStorageSection,
        mutate: (inout AccountInfo) -> Void
    ) {
        switch section {
        case .main:
            guard let index = accounts.firstIndex(where: { $0.id == accountID }) else { return }
            var updatedAccount = accounts[index]
            mutate(&updatedAccount)
            accounts[index] = updatedAccount
            saveAccounts()
        case .nursery:
            guard let index = nurseryAccounts.firstIndex(where: { $0.id == accountID }) else { return }
            var updatedAccount = nurseryAccounts[index]
            mutate(&updatedAccount)
            nurseryAccounts[index] = updatedAccount
            saveNurseryAccounts()
        }
    }

    // 更新账号状态
    func updateAccount(_ account: AccountInfo) {
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index] = account
            saveAccounts()
            return
        }

        if let index = nurseryAccounts.firstIndex(where: { $0.id == account.id }) {
            nurseryAccounts[index] = account
            saveNurseryAccounts()
        }
    }

    private func logCheckin(_ message: String) {
        Task { @MainActor in
            LogStore.shared.add(category: "CHECKIN", message)
        }
    }

    private func extractFirstInteger(from texts: [String?]) -> Int? {
        for text in texts {
            guard let text else { continue }
            let pattern = #"\d+"#
            if let match = text.range(of: pattern, options: .regularExpression) {
                return Int(text[match])
            }
        }
        return nil
    }

    private func isAlreadyCheckedIn(from response: APIService.CheckinBeforeResponse) -> Bool {
        (response.d?.IsCheckIn ?? false) || (response.d?.IsCheckInForGroup ?? false)
    }

    private func canAttemptCheckin(from response: APIService.CheckinBeforeResponse) -> Bool {
        guard response.m == 1 else { return false }
        return (response.d?.IsOpenCheckin ?? false) || (response.d?.IsOpenCheckinForGroup ?? false)
    }

    private func resolveCheckinReward(from response: APIService.CheckinActionResponse) -> Int? {
        extractFirstInteger(
            from: [
                response.d?.Content,
                response.d?.Msg,
                response.d?.Notice,
                response.d?.Desc,
                response.e
            ]
        )
    }

    private func resolveCheckinMessage(
        from response: APIService.CheckinActionResponse,
        fallback: String
    ) -> String {
        if let msg = response.d?.Msg, !msg.isEmpty { return msg }
        if let notice = response.d?.Notice, !notice.isEmpty { return notice }
        if let desc = response.d?.Desc, !desc.isEmpty { return desc }
        if let error = response.e, !error.isEmpty { return error }
        return fallback
    }

    private func resolveCheckinFailureMessage(from response: APIService.CheckinBeforeResponse) -> String {
        if let error = response.e, !error.isEmpty {
            return error
        }
        if let tips = response.d?.GroupTips, !tips.isEmpty {
            return tips
        }
        if response.d?.IsOpenMemberCard == false {
            return "未开通线上会员卡或已冻结"
        }
        return "当前商场暂不可签到"
    }

    private func shouldAttemptAutoMallCardRepair(from response: APIService.CheckinBeforeResponse) -> Bool {
        if response.d?.IsOpenMemberCard == false {
            return true
        }

        let texts = [
            response.e,
            response.d?.GroupTips
        ]

        return texts
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .contains { $0.contains("未开通线上会员卡") }
    }

    @MainActor
    private func markAutoMallCardRepairAttempt(accountID: UUID, section: AccountStorageSection) {
        updateAccount(withID: accountID, in: section) { updatedAccount in
            updatedAccount.markAutoMallCardRepairAttempt()
        }
    }

    private func retryCheckinAfterMallCardRepair(
        account: AccountInfo,
        section: AccountStorageSection,
        token: String,
        uid: String?,
        mallID: Int,
        mallName: String,
        trigger: String
    ) async -> Bool {
        do {
            let before = try await APIService.shared.getCheckinBefore(token: token, mallID: mallID)
            let resolvedMallName = resolveMallName(for: mallID, fallback: before.d?.MallName ?? mallName)

            if isAlreadyCheckedIn(from: before) {
                let latestBonus = try? await APIService.shared.getBonus(token: token)
                let message = before.d?.GroupTips?.isEmpty == false ? before.d?.GroupTips ?? "今天已经签到" : "今天已经签到"
                logCheckin("账号 \(account.username) 补开卡后状态：\(message)")
                await updateCheckinResult(
                    accountID: account.id,
                    section: section,
                    token: token,
                    uid: uid,
                    bonus: latestBonus,
                    mallID: mallID,
                    mallName: resolvedMallName,
                    reward: nil,
                    message: message,
                    succeeded: true,
                    promoteTrigger: trigger
                )
                return true
            }

            guard canAttemptCheckin(from: before) else {
                let latestBonus = try? await APIService.shared.getBonus(token: token)
                let message = "自动补开卡后仍不可签到：\(resolveCheckinFailureMessage(from: before))"
                logCheckin("账号 \(account.username) 补开卡后仍不可签到：\(message)")
                await updateCheckinResult(
                    accountID: account.id,
                    section: section,
                    token: token,
                    uid: uid,
                    bonus: latestBonus,
                    mallID: mallID,
                    mallName: resolvedMallName,
                    reward: nil,
                    message: message,
                    succeeded: false,
                    promoteTrigger: trigger,
                    preserveExistingSuccessOnFailure: true
                )
                return false
            }

            let result = try await APIService.shared.performCheckin(token: token, mallID: mallID)
            let succeeded = (result.m == 1 && result.d?.IsGiveSucess == true) || result.m == 2054
            let shouldDelayBonusRefresh = result.m == 1 && result.d?.IsGiveSucess == true
            let latestBonus = await loadLatestBonusAfterCheckin(token: token, shouldDelay: shouldDelayBonusRefresh)
            let message = resolveCheckinMessage(
                from: result,
                fallback: succeeded ? "今天已经签到" : "签到失败"
            )
            let reward = succeeded ? resolveCheckinReward(from: result) : nil

            logCheckin("账号 \(account.username) 补开卡后重试签到结果：\(message)")
            await updateCheckinResult(
                accountID: account.id,
                section: section,
                token: token,
                uid: uid,
                bonus: latestBonus,
                mallID: mallID,
                mallName: resolvedMallName,
                reward: reward,
                message: message,
                succeeded: succeeded,
                promoteTrigger: trigger,
                preserveExistingSuccessOnFailure: true
            )
            return succeeded
        } catch let apiError as APIService.APIError {
            let message = "自动补开卡后重试失败：\(apiError.message)"
            logCheckin("账号 \(account.username) \(message)")
            await updateCheckinResult(
                accountID: account.id,
                section: section,
                token: token,
                uid: uid,
                bonus: nil,
                mallID: mallID,
                mallName: mallName,
                reward: nil,
                message: message,
                succeeded: false,
                promoteTrigger: trigger,
                preserveExistingSuccessOnFailure: true
            )
            return false
        } catch {
            let message = "自动补开卡后重试失败：\(error.localizedDescription)"
            logCheckin("账号 \(account.username) \(message)")
            await updateCheckinResult(
                accountID: account.id,
                section: section,
                token: token,
                uid: uid,
                bonus: nil,
                mallID: mallID,
                mallName: mallName,
                reward: nil,
                message: message,
                succeeded: false,
                promoteTrigger: trigger,
                preserveExistingSuccessOnFailure: true
            )
            return false
        }
    }

    private func resolveMallName(for mallID: Int, fallback: String?) -> String {
        if let fallback, !fallback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return fallback
        }
        return CheckinMallCatalog.name(for: mallID) ?? "MallID \(mallID)"
    }

    private func updateCheckinResult(
        accountID: UUID,
        section: AccountStorageSection,
        token: String?,
        uid: String?,
        bonus: Int?,
        mallID: Int,
        mallName: String,
        reward: Int?,
        message: String,
        succeeded: Bool,
        promoteTrigger: String,
        preserveExistingSuccessOnFailure: Bool = false
    ) async {
        await MainActor.run {
            self.updateAccount(withID: accountID, in: section) { updatedAccount in
                updatedAccount.token = token
                updatedAccount.uid = uid
                if let bonus {
                    updatedAccount.bonus = bonus
                }
                let shouldPreserveExistingSuccess = preserveExistingSuccessOnFailure
                    && !succeeded
                    && updatedAccount.hasCheckedInToday
                if !shouldPreserveExistingSuccess {
                    updatedAccount.updateCheckinStatus(
                        mallID: mallID,
                        mallName: mallName,
                        reward: reward,
                        message: message,
                        succeeded: succeeded
                    )
                }
            }

            _ = self.promoteNurseryAccountIfNeeded(accountID: accountID, trigger: promoteTrigger)
        }
    }

    @MainActor
    private func beginCheckinIfPossible(accountID: UUID) -> Bool {
        guard !activeCheckinAccountIDs.contains(accountID) else {
            return false
        }
        activeCheckinAccountIDs.insert(accountID)
        return true
    }

    @MainActor
    private func endCheckin(accountID: UUID) {
        activeCheckinAccountIDs.remove(accountID)
    }

    @MainActor
    private func beginAutoCheckinProgress(total: Int) {
        isAutoCheckinRunning = true
        autoCheckinProgressCurrent = 0
        autoCheckinProgressTotal = total
        autoCheckinCurrentAccountUsername = nil
        autoCheckinProgressText = "正在执行自动签到中 0/\(total)"
    }

    @MainActor
    private func updateAutoCheckinProgress(current: Int, total: Int, username: String) {
        autoCheckinProgressCurrent = current
        autoCheckinProgressTotal = total
        autoCheckinCurrentAccountUsername = username
        autoCheckinProgressText = "正在执行自动签到中 \(current)/\(total)"
    }

    @MainActor
    private func resetAutoCheckinProgress() {
        isAutoCheckinRunning = false
        autoCheckinProgressCurrent = 0
        autoCheckinProgressTotal = 0
        autoCheckinProgressText = ""
        autoCheckinCurrentAccountUsername = nil
    }

    private func loadLatestBonusAfterCheckin(token: String, shouldDelay: Bool) async -> Int? {
        if shouldDelay {
            logCheckin("签到成功，等待积分入账后再刷新")
            try? await Task.sleep(nanoseconds: 1_800_000_000)
        }
        return try? await APIService.shared.getBonus(token: token)
    }

    private func performCheckinForAccount(
        _ account: AccountInfo,
        section: AccountStorageSection,
        mallID: Int,
        mallName: String,
        trigger: String
    ) async -> Bool {
        let didBeginCheckin = await MainActor.run {
            beginCheckinIfPossible(accountID: account.id)
        }

        guard didBeginCheckin else {
            logCheckin("账号 \(account.username) 跳过\(trigger)：已有签到任务在执行")
            return account.hasCheckedInToday
        }

        defer {
            Task { @MainActor [weak self] in
                self?.endCheckin(accountID: account.id)
            }
        }

        do {
            logCheckin("账号 \(account.username) 开始\(trigger)，目标商场：\(mallName)(\(mallID))")

            let (isValid, newToken, uid) = try await APIService.shared.login(
                username: account.username,
                password: account.password
            )

            guard isValid, let token = newToken else {
                let message = uid?.isEmpty == false ? "登录失败：\(uid!)" : "登录失败"
                logCheckin("账号 \(account.username) \(trigger)登录失败：\(message)")
                await updateCheckinResult(
                    accountID: account.id,
                    section: section,
                    token: nil,
                    uid: uid,
                    bonus: nil,
                    mallID: mallID,
                    mallName: mallName,
                    reward: nil,
                    message: message,
                    succeeded: false,
                    promoteTrigger: trigger,
                    preserveExistingSuccessOnFailure: true
                )
                return false
            }

            let before = try await APIService.shared.getCheckinBefore(token: token, mallID: mallID)

            if isAlreadyCheckedIn(from: before) {
                let latestBonus = try? await APIService.shared.getBonus(token: token)
                let message = before.d?.GroupTips?.isEmpty == false ? before.d?.GroupTips ?? "今天已经签到" : "今天已经签到"
                logCheckin("账号 \(account.username) \(trigger)状态：\(message)")
                await updateCheckinResult(
                    accountID: account.id,
                    section: section,
                    token: token,
                    uid: uid,
                    bonus: latestBonus,
                    mallID: mallID,
                    mallName: resolveMallName(for: mallID, fallback: before.d?.MallName ?? mallName),
                    reward: nil,
                    message: message,
                    succeeded: true,
                    promoteTrigger: trigger
                )
                return true
            }

            guard canAttemptCheckin(from: before) else {
                var alreadyAttemptedRepairToday = false
                if shouldAttemptAutoMallCardRepair(from: before) {
                    alreadyAttemptedRepairToday = await MainActor.run {
                        guard let latestAccount = self.accounts.first(where: { $0.id == account.id })
                            ?? self.nurseryAccounts.first(where: { $0.id == account.id }) else {
                            return account.hasAttemptedAutoMallCardRepairToday
                        }
                        return latestAccount.hasAttemptedAutoMallCardRepairToday
                    }

                    if !alreadyAttemptedRepairToday {
                        await MainActor.run {
                            self.markAutoMallCardRepairAttempt(accountID: account.id, section: section)
                        }
                        logCheckin("账号 \(account.username) 命中未开会员卡条件，开始自动补开全商场会员卡")

                        do {
                            let repairResult = try await MallCardAutoRepairService.shared.repairAllMallCards(
                                token: token,
                                phone: account.username
                            )
                            logCheckin("账号 \(account.username) 自动补开卡完成：\(repairResult.summaryText)")
                            return await retryCheckinAfterMallCardRepair(
                                account: account,
                                section: section,
                                token: repairResult.latestToken,
                                uid: uid,
                                mallID: mallID,
                                mallName: resolveMallName(for: mallID, fallback: before.d?.MallName ?? mallName),
                                trigger: trigger
                            )
                        } catch {
                            let latestBonus = try? await APIService.shared.getBonus(token: token)
                            let message = "自动补开卡失败：\(error.localizedDescription)"
                            logCheckin("账号 \(account.username) \(message)")
                            await updateCheckinResult(
                                accountID: account.id,
                                section: section,
                                token: token,
                                uid: uid,
                                bonus: latestBonus,
                                mallID: mallID,
                                mallName: resolveMallName(for: mallID, fallback: before.d?.MallName ?? mallName),
                                reward: nil,
                                message: message,
                                succeeded: false,
                                promoteTrigger: trigger,
                                preserveExistingSuccessOnFailure: true
                            )
                            return false
                        }
                    } else {
                        logCheckin("账号 \(account.username) 今天已自动补开过会员卡，本次不再重复补开")
                    }
                }

                let latestBonus = try? await APIService.shared.getBonus(token: token)
                let message = shouldAttemptAutoMallCardRepair(from: before) && alreadyAttemptedRepairToday
                    ? "今天已自动补开过会员卡，当前商场仍不可签到"
                    : resolveCheckinFailureMessage(from: before)
                logCheckin("账号 \(account.username) \(trigger)不可执行：\(message)")
                await updateCheckinResult(
                    accountID: account.id,
                    section: section,
                    token: token,
                    uid: uid,
                    bonus: latestBonus,
                    mallID: mallID,
                    mallName: resolveMallName(for: mallID, fallback: before.d?.MallName ?? mallName),
                    reward: nil,
                    message: message,
                    succeeded: false,
                    promoteTrigger: trigger,
                    preserveExistingSuccessOnFailure: true
                )
                return false
            }

            let result = try await APIService.shared.performCheckin(token: token, mallID: mallID)
            let succeeded = (result.m == 1 && result.d?.IsGiveSucess == true) || result.m == 2054
            let shouldDelayBonusRefresh = result.m == 1 && result.d?.IsGiveSucess == true
            let latestBonus = await loadLatestBonusAfterCheckin(token: token, shouldDelay: shouldDelayBonusRefresh)
            let message = resolveCheckinMessage(
                from: result,
                fallback: succeeded ? "今天已经签到" : "签到失败"
            )
            let reward = succeeded ? resolveCheckinReward(from: result) : nil
            let resolvedMallName = resolveMallName(for: mallID, fallback: before.d?.MallName ?? mallName)

            logCheckin("账号 \(account.username) \(trigger)结果：\(message)")
            await updateCheckinResult(
                accountID: account.id,
                section: section,
                token: token,
                uid: uid,
                bonus: latestBonus,
                mallID: mallID,
                mallName: resolvedMallName,
                reward: reward,
                message: message,
                succeeded: succeeded,
                promoteTrigger: trigger,
                preserveExistingSuccessOnFailure: true
            )
            return succeeded
        } catch let apiError as APIService.APIError {
            logCheckin("账号 \(account.username) \(trigger)失败：\(apiError.message)")
            await updateCheckinResult(
                accountID: account.id,
                section: section,
                token: nil,
                uid: nil,
                bonus: nil,
                mallID: mallID,
                mallName: mallName,
                reward: nil,
                message: apiError.message,
                succeeded: false,
                promoteTrigger: trigger,
                preserveExistingSuccessOnFailure: true
            )
            return false
        } catch {
            logCheckin("账号 \(account.username) \(trigger)失败：\(error.localizedDescription)")
            await updateCheckinResult(
                accountID: account.id,
                section: section,
                token: nil,
                uid: nil,
                bonus: nil,
                mallID: mallID,
                mallName: mallName,
                reward: nil,
                message: "网络失败：\(error.localizedDescription)",
                succeeded: false,
                promoteTrigger: trigger,
                preserveExistingSuccessOnFailure: true
            )
            return false
        }
    }

    func performAutoCheckin(dataManager: DataManager, trigger: String) async -> Bool {
        let context = await MainActor.run { () -> (accounts: [AccountInfo], mallID: Int?, mallName: String?) in
            (
                accounts: self.accounts + self.nurseryAccounts,
                mallID: dataManager.settings.autoCheckinTargetMallID,
                mallName: dataManager.settings.autoCheckinTargetMallName
            )
        }

        guard let mallID = context.mallID else {
            logCheckin("跳过自动签到：尚未选定签到商场，触发来源：\(trigger)")
            return false
        }

        let mallName = resolveMallName(for: mallID, fallback: context.mallName)
        guard !context.accounts.isEmpty else {
            logCheckin("跳过自动签到：当前没有可处理账号，触发来源：\(trigger)")
            return false
        }

        let pendingAccounts = context.accounts.filter { !$0.hasCheckedInToday }
        guard !pendingAccounts.isEmpty else {
            logCheckin("跳过自动签到：今天所有账号都已签到，触发来源：\(trigger)")
            return false
        }

        logCheckin("开始自动签到，触发来源：\(trigger)，商场：\(mallName)(\(mallID))，待处理账号数：\(pendingAccounts.count)")
        await MainActor.run {
            beginAutoCheckinProgress(total: pendingAccounts.count)
        }

        for (index, account) in pendingAccounts.enumerated() {
            guard let section = await MainActor.run(body: { self.accountLocation(for: account.id) }) else {
                continue
            }

            await MainActor.run {
                updateAutoCheckinProgress(
                    current: min(index + 1, pendingAccounts.count),
                    total: pendingAccounts.count,
                    username: account.username
                )
            }

            _ = await performCheckinForAccount(
                account,
                section: section,
                mallID: mallID,
                mallName: mallName,
                trigger: "自动签到"
            )

            try? await Task.sleep(nanoseconds: 600_000_000)
        }

        logCheckin("自动签到完成，触发来源：\(trigger)")
        await MainActor.run {
            resetAutoCheckinProgress()
        }
        return true
    }

    func performSingleCheckin(for account: AccountInfo, dataManager: DataManager) async {
        guard let section = await MainActor.run(body: { self.accountLocation(for: account.id) }) else {
            return
        }

        guard let mallID = await MainActor.run(body: { dataManager.settings.autoCheckinTargetMallID }) else {
            showToast("请先在设置里选定签到商场", type: .info)
            return
        }

        let mallName = await MainActor.run(body: {
            self.resolveMallName(for: mallID, fallback: dataManager.settings.autoCheckinTargetMallName)
        })

        let isBusy = await MainActor.run {
            activeCheckinAccountIDs.contains(account.id)
        }
        if isBusy {
            showToast("账号 \(account.username) 正在签到中", type: .info)
            return
        }

        showToast("正在为账号 \(account.username) 执行签到...", type: .info)
        let succeeded = await performCheckinForAccount(
            account,
            section: section,
            mallID: mallID,
            mallName: mallName,
            trigger: "手动签到"
        )

        if succeeded {
            showToast("账号 \(account.username) 签到完成", type: .success)
        } else {
            showToast("账号 \(account.username) 未完成签到", type: .info)
        }
    }

    func refreshBonus(for account: AccountInfo) async {
        print("开始为账号 \(account.username) 刷新积分...")
        guard let section = await MainActor.run(body: { self.accountLocation(for: account.id) }) else {
            return
        }

        do {
            showToast("正在登录账号...", type: .info)
            let (isValid, newToken, uid) = try await APIService.shared.login(username: account.username, password: account.password)

            if !isValid || newToken == nil {
                showToast("登录失败：\(uid ?? "未知错误")", type: .error)
                return
            }

            showToast("登录成功，正在查询积分...", type: .info)

            let bonus = try await APIService.shared.getBonus(token: newToken!)

            await MainActor.run {
                self.updateAccount(withID: account.id, in: section) { updatedAccount in
                    updatedAccount.bonus = bonus
                    updatedAccount.token = newToken
                    updatedAccount.uid = uid
                }
                _ = self.promoteNurseryAccountIfNeeded(accountID: account.id, trigger: "积分达标")
                self.showToast("积分刷新成功：\(bonus)分", type: .success)
            }
        } catch {
            showToast("刷新积分失败：\(error.localizedDescription)", type: .error)
        }
    }

    func refreshVoucherCount(for account: AccountInfo) async {
        print("开始为账号 \(account.username) 刷新停车券数量...")
        guard let section = await MainActor.run(body: { self.accountLocation(for: account.id) }) else {
            return
        }

        do {
            showToast("正在登录账号...", type: .info)
            let (isValid, newToken, uid) = try await APIService.shared.login(username: account.username, password: account.password)

            if !isValid || newToken == nil {
                showToast("登录失败：\(uid ?? "未知错误")", type: .error)
                return
            }

            showToast("登录成功，正在查询停车券...", type: .info)

            let voucherCount = try await APIService.shared.getVoucherCount(token: newToken!)

            await MainActor.run {
                self.updateAccount(withID: account.id, in: section) { updatedAccount in
                    updatedAccount.voucherCount = voucherCount
                    updatedAccount.token = newToken
                    updatedAccount.uid = uid
                }
                self.showToast("停车券刷新成功：\(voucherCount)张", type: .success)
            }
        } catch {
            showToast("刷新停车券失败：\(error.localizedDescription)", type: .error)
        }
    }

    func exchangeVoucher(
        for account: AccountInfo,
        exchangeCount: Int,
        mid: String,
        gid: String,
        exchangeAccountOverride: AccountInfo? = nil,
        cardLevelOverride: Int? = nil,
        cardTitleOverride: String? = nil
    ) async {
        let exchangeAccount = exchangeAccountOverride ?? account
        let isUsingOverride = exchangeAccount.id != account.id
        print("开始为账号 \(exchangeAccount.username) 兑换停车券...")
        var exchangeSucceeded = false

        do {
            if isUsingOverride {
                showToast("测试模式：使用账号 \(exchangeAccount.username) 进行兑换", type: .info)
            }

            showToast("正在登录账号...", type: .info)
            let (isValid, newToken, uid) = try await APIService.shared.login(
                username: exchangeAccount.username,
                password: exchangeAccount.password
            )

            if !isValid || newToken == nil {
                showToast("登录失败：\(uid ?? "未知错误")", type: .error)
                return
            }

            showToast("登录成功，正在兑换停车券...", type: .info)

            let orderNo = try await APIService.shared.exchangeVoucher(
                token: newToken!,
                uid: uid ?? "",
                count: exchangeCount,
                mid: mid,
                gid: gid,
                cardLevel: cardLevelOverride,
                cardTitle: cardTitleOverride
            )

            await MainActor.run {
                if let index = accounts.firstIndex(where: { $0.id == exchangeAccount.id }) {
                    var updatedAccount = accounts[index]
                    updatedAccount.isProcessedToday = true
                    updatedAccount.token = newToken
                    updatedAccount.uid = uid
                    accounts[index] = updatedAccount
                    saveAccounts()
                    showToast("兑换成功！订单号：\(orderNo)", type: .success)
                }
            }

            exchangeSucceeded = true
        } catch {
            showToast("兑换失败：\(error.localizedDescription)", type: .error)
        }

        // 无论兑换成功与否，都刷新停车券数量和积分
        if !exchangeSucceeded {
            // 避免错误 toast 被后续刷新流程的提示覆盖
            try? await Task.sleep(nanoseconds: 3_200_000_000)
        }

        showToast("正在刷新停车券数量...", type: .info)
        await refreshVoucherCount(for: exchangeAccount)

        showToast("正在刷新积分...", type: .info)
        await refreshBonus(for: exchangeAccount)
    }

    func executeAllAccounts(
        exchangeCount: Int,
        mid: String,
        gid: String,
        cardLevelOverride: Int? = nil,
        cardTitleOverride: String? = nil
    ) async {
        isExecutingAll = true
        showToast("开始批量兑换停车券...", type: .info)

        // 过滤出未处理的账号
        let unprocessedAccounts = accounts.filter { !$0.isProcessedToday }

        if unprocessedAccounts.isEmpty {
            showToast("没有需要处理的账号", type: .info)
            isExecutingAll = false
            currentProcessingAccountId = nil
            return
        }

        // 记录成功和失败的数量
        var successCount = 0
        var failureCount = 0

        // 依次处理每个账号
        for account in unprocessedAccounts {
            // 设置当前处理的账号ID
            await MainActor.run {
                currentProcessingAccountId = account.id
            }

            showToast("正在处理账号: \(account.username)...", type: .info)

            do {
                // 修改这里，使用返回值判断成功或失败
                let success = await processAccount(
                    account,
                    exchangeCount: exchangeCount,
                    mid: mid,
                    gid: gid,
                    cardLevelOverride: cardLevelOverride,
                    cardTitleOverride: cardTitleOverride
                )
                if success {
                    successCount += 1
                } else {
                    failureCount += 1
                }

                // 添加延迟，避免请求过于频繁
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2秒延迟
            } catch {
                print("账号处理发生异常: \(error.localizedDescription)")
                failureCount += 1
                showToast("账号 \(account.username) 处理失败：\(error.localizedDescription)", type: .error)
            }
        }

        // 添加额外的延迟确保所有异步操作完成
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒延迟

        // 显示最终执行结果
        print("批量兑换完成，重置状态")
        let finalSuccessCount = successCount
        let finalFailureCount = failureCount
        await MainActor.run {
            showToast("批量兑换完成！成功：\(finalSuccessCount)个，失败：\(finalFailureCount)个", type: .info)
            isExecutingAll = false
            currentProcessingAccountId = nil
        }
    }

    // 添加新方法处理单个账号
    func processAccount(
        _ account: AccountInfo,
        exchangeCount: Int,
        mid: String,
        gid: String,
        cardLevelOverride: Int? = nil,
        cardTitleOverride: String? = nil
    ) async -> Bool {
        do {
            // 登录账号
            showToast("正在登录账号: \(account.username)...", type: .info)
            let (isValid, newToken, uid) = try await APIService.shared.login(username: account.username, password: account.password)

            if !isValid || newToken == nil {
                showToast("账号 \(account.username) 登录失败", type: .error)
                return false
            }

            // 兑换停车券
            showToast("正在为账号 \(account.username) 兑换停车券...", type: .info)
            let orderNo = try await APIService.shared.exchangeVoucher(
                token: newToken!,
                uid: uid ?? "",
                count: exchangeCount,
                mid: mid,
                gid: gid,
                cardLevel: cardLevelOverride,
                cardTitle: cardTitleOverride
            )

            // 更新账号状态
            await MainActor.run {
                if let index = accounts.firstIndex(where: { $0.id == account.id }) {
                    var updatedAccount = accounts[index]
                    updatedAccount.isProcessedToday = true
                    updatedAccount.token = newToken
                    updatedAccount.uid = uid
                    accounts[index] = updatedAccount
                    saveAccounts()
                }
            }

            showToast("账号 \(account.username) 兑换成功，订单号: \(orderNo)", type: .success)

            // 刷新停车券数量
            showToast("正在刷新账号 \(account.username) 的停车券数量...", type: .info)
            let voucherCount = try await APIService.shared.getVoucherCount(token: newToken!)

            // 刷新积分
            showToast("正在刷新账号 \(account.username) 的积分...", type: .info)
            let bonus = try await APIService.shared.getBonus(token: newToken!)

            // 更新账号信息
            await MainActor.run {
                if let index = accounts.firstIndex(where: { $0.id == account.id }) {
                    var updatedAccount = accounts[index]
                    updatedAccount.voucherCount = voucherCount
                    updatedAccount.bonus = bonus
                    accounts[index] = updatedAccount
                    saveAccounts()
                }
            }

            return true
        } catch {
            showToast("账号 \(account.username) 处理失败: \(error.localizedDescription)", type: .error)
            return false
        }
    }

    // 修改批量导入账号的方法（如果有的话）
    func importAccounts(from accounts: [(username: String, password: String)]) async {
        for account in accounts {
            // 检查手机号是否已存在
            if !isPhoneNumberExists(account.username) {
                // 只添加不存在的账号
                _ = await addAccountWithValidation(username: account.username, password: account.password)
            } else {
                showToast("跳过重复的手机号：\(account.username)", type: .info)
            }
        }
    }

    // MARK: - 通知观察者
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: .autoBackupTriggered,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task {
                await self.triggerAutoBackup()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .accountsStorageDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            if let source = notification.object as AnyObject?, source === self {
                return
            }
            self.loadAccounts()
            self.loadNurseryAccounts()
        }
    }

    @MainActor
    private func triggerAutoBackup() async {
        // 发送通知给 DataManager 进行自动备份
        NotificationCenter.default.post(
            name: .performAutoBackup,
            object: self.accounts,
            userInfo: ["nurseryAccounts": self.nurseryAccounts]
        )
    }
}
