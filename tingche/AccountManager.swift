// Purpose: Observable store that manages accounts and orchestrates login, refresh, exchange, and batch operations.
// Author: Achord <achordchan@gmail.com>
import Foundation
import SwiftUI

// 账号管理类
class AccountManager: ObservableObject {
    @Published var accounts: [AccountInfo] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var showToast = false
    @Published var toastMessage = ""
    @Published var toastType: ToastType = .success
    @Published var isExecutingAll = false
    @Published var currentProcessingAccountId: UUID?
    private let accountsKey = "savedAccounts"
    private var resetTimer: Timer?

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
        let lastResetDate = UserDefaults.standard.object(forKey: "lastResetDate") as? Date ?? Date.distantPast

        // 检查是否是不同的日期
        if !calendar.isDate(lastResetDate, inSameDayAs: now) {
            // 如果不是同一天，重置所有账号的状态
            for index in accounts.indices {
                accounts[index].isProcessedToday = false
            }
            saveAccounts()

            // 更新最后重置日期
            UserDefaults.standard.set(now, forKey: "lastResetDate")
            print("软件启动时检测到新的一天，已重置所有账号状态")
        }
    }

    // 修改原有的重置方法，同时更新最后重置日期
    func resetAllProcessedStatus() {
        DispatchQueue.main.async {
            for index in self.accounts.indices {
                self.accounts[index].isProcessedToday = false
            }
            self.saveAccounts()

            // 更新最后重置日期
            UserDefaults.standard.set(Date(), forKey: "lastResetDate")
            self.showToast("已重置所有账号的处理状态", type: .info)
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

    // 保存账号
    func saveAccounts() {
        do {
            let data = try JSONEncoder().encode(accounts)
            UserDefaults.standard.set(data, forKey: accountsKey)
            print("成功保存\(accounts.count)个账号")
        } catch {
            print("保存账号失败: \(error.localizedDescription)")
        }
    }

    // 添加检查手机号是否存在的方法
    func isPhoneNumberExists(_ phoneNumber: String) -> Bool {
        return accounts.contains { $0.username == phoneNumber }
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
        accounts.append(account)
        saveAccounts()
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

    // 更新账号状态
    func updateAccount(_ account: AccountInfo) {
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index] = account
            saveAccounts()
        }
    }

    func refreshBonus(for account: AccountInfo) async {
        print("开始为账号 \(account.username) 刷新积分...")

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
                if let index = accounts.firstIndex(where: { $0.id == account.id }) {
                    var updatedAccount = accounts[index]
                    updatedAccount.bonus = bonus
                    updatedAccount.token = newToken
                    updatedAccount.uid = uid
                    accounts[index] = updatedAccount
                    saveAccounts()
                    showToast("积分刷新成功：\(bonus)分", type: .success)
                }
            }
        } catch {
            showToast("刷新积分失败：\(error.localizedDescription)", type: .error)
        }
    }

    func refreshVoucherCount(for account: AccountInfo) async {
        print("开始为账号 \(account.username) 刷新停车券数量...")

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
                if let index = accounts.firstIndex(where: { $0.id == account.id }) {
                    var updatedAccount = accounts[index]
                    updatedAccount.voucherCount = voucherCount
                    updatedAccount.token = newToken
                    updatedAccount.uid = uid
                    accounts[index] = updatedAccount
                    saveAccounts()
                    showToast("停车券刷新成功：\(voucherCount)张", type: .success)
                }
            }
        } catch {
            showToast("刷新停车券失败：\(error.localizedDescription)", type: .error)
        }
    }

    func exchangeVoucher(for account: AccountInfo, exchangeCount: Int, mid: String, gid: String) async {
        print("开始为账号 \(account.username) 兑换停车券...")
        var exchangeSucceeded = false

        do {
            showToast("正在登录账号...", type: .info)
            let (isValid, newToken, uid) = try await APIService.shared.login(username: account.username, password: account.password)

            if !isValid || newToken == nil {
                showToast("登录失败：\(uid ?? "未知错误")", type: .error)
                return
            }

            showToast("登录成功，正在兑换停车券...", type: .info)

            let orderNo = try await APIService.shared.exchangeVoucher(
                token: newToken!,
                count: exchangeCount,
                mid: mid,
                gid: gid
            )

            await MainActor.run {
                if let index = accounts.firstIndex(where: { $0.id == account.id }) {
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
        await refreshVoucherCount(for: account)

        showToast("正在刷新积分...", type: .info)
        await refreshBonus(for: account)
    }

    func executeAllAccounts(exchangeCount: Int, mid: String, gid: String) async {
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
                let success = await processAccount(account, exchangeCount: exchangeCount, mid: mid, gid: gid)
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
        await MainActor.run {
            showToast("批量兑换完成！成功：\(successCount)个，失败：\(failureCount)个", type: .info)
            isExecutingAll = false
            currentProcessingAccountId = nil
        }
    }

    // 添加新方法处理单个账号
    func processAccount(_ account: AccountInfo, exchangeCount: Int, mid: String, gid: String) async -> Bool {
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
                count: exchangeCount,
                mid: mid,
                gid: gid
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
    }

    @MainActor
    private func triggerAutoBackup() async {
        // 发送通知给 DataManager 进行自动备份
        NotificationCenter.default.post(
            name: .performAutoBackup,
            object: self.accounts
        )
    }
}
