// Purpose: ViewModel for settings-related async operations (gift discovery, gift list fetching, and nursery checkin mall querying).
// Author: Achord <achordchan@gmail.com>
import Foundation

struct CheckinMallRecommendation: Identifiable, Equatable {
    let mallID: Int
    let mallName: String
    let signableAccountCount: Int
    let estimatedRewardTotal: Int?
    let isComplexRule: Bool
    let ruleDescription: String

    var id: Int { mallID }

    var estimatedRewardText: String {
        if let estimatedRewardTotal {
            return "\(estimatedRewardTotal)"
        }
        return "规则复杂"
    }
}

private struct CheckinQuerySession {
    let username: String
    let token: String
}

final class SettingsViewModel: ObservableObject {
    @Published var isDiscoveringGift: Bool = false
    @Published var isFetchingGiftList: Bool = false
    @Published var isQueryingCheckinMalls: Bool = false
    @Published var checkinMallQueryStatusText: String = ""
    @Published var parkingVoucherGifts: [APIService.GiftInfoListItem] = []
    @Published var checkinMallRecommendations: [CheckinMallRecommendation] = []

    private let apiService: APIServiceProtocol

    init(apiService: APIServiceProtocol = APIService.shared) {
        self.apiService = apiService
    }

    private func preferredParkingVoucherGift(
        from gifts: [APIService.GiftInfoListItem],
        preferredCardTitle: String?
    ) -> APIService.GiftInfoListItem? {
        let trimmedTitle = preferredCardTitle?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !trimmedTitle.isEmpty,
           let match = gifts.first(where: { $0.n.contains(trimmedTitle) }) {
            return match
        }

        if let best = gifts.first(where: { $0.n.contains("2小时") }) {
            return best
        }

        if let best = gifts.first(where: { $0.n.contains("1小时") }) {
            return best
        }

        return gifts.first
    }

    private func combinedAccounts(from accountManager: AccountManager) -> [AccountInfo] {
        accountManager.allManagedAccounts()
    }

    func fetchParkingVoucherGifts(dataManager: DataManager, accountManager: AccountManager) async {
        let context: (accounts: [AccountInfo], exchangeMid: String)? = await MainActor.run {
            guard !isFetchingGiftList else { return nil }
            let accounts = combinedAccounts(from: accountManager)
            guard !accounts.isEmpty else {
                accountManager.showToast("请先添加账号，再拉取礼品列表", type: .info)
                return nil
            }

            isFetchingGiftList = true
            parkingVoucherGifts = []
            return (accounts, dataManager.settings.exchangeMid)
        }

        guard let context else { return }

        defer {
            Task { @MainActor in
                self.isFetchingGiftList = false
            }
        }

        do {
            var resolvedToken: String?
            var resolvedUid: String?
            var lastLoginError: String?

            for account in context.accounts {
                do {
                    let (isValid, token, uid) = try await apiService.login(
                        username: account.username,
                        password: account.password
                    )

                    if isValid, let token {
                        resolvedToken = token
                        resolvedUid = uid
                        break
                    } else {
                        lastLoginError = "账号 \(account.username) 登录失败"
                    }
                } catch let apiError as APIService.APIError {
                    lastLoginError = apiError.message
                } catch {
                    lastLoginError = error.localizedDescription
                }
            }

            guard let rawToken = resolvedToken else {
                let finalLoginError = lastLoginError
                await MainActor.run {
                    if let finalLoginError {
                        accountManager.showToast("登录失败，无法拉取：\(finalLoginError)", type: .error)
                    } else {
                        accountManager.showToast("登录失败，无法拉取", type: .error)
                    }
                }
                return
            }

            let tokenForGiftList: String
            if rawToken.contains(",") {
                tokenForGiftList = rawToken
            } else if let uid = resolvedUid, !uid.isEmpty {
                tokenForGiftList = "\(rawToken),\(uid)"
            } else {
                tokenForGiftList = rawToken
            }

            let parkingVouchers = try await apiService.getParkingVoucherGiftCandidates(
                token: tokenForGiftList,
                mid: context.exchangeMid
            )

            await MainActor.run {
                parkingVoucherGifts = parkingVouchers
                if parkingVouchers.isEmpty {
                    accountManager.showToast("未找到停车券礼品", type: .info)
                } else {
                    accountManager.showToast("已拉取 \(parkingVouchers.count) 个停车券礼品", type: .success)
                }
            }
        } catch let apiError as APIService.APIError {
            await MainActor.run {
                accountManager.showToast("拉取失败：\(apiError.message)", type: .error)
            }
        } catch {
            await MainActor.run {
                accountManager.showToast("拉取失败：\(error.localizedDescription)", type: .error)
            }
        }
    }

    func discoverParkingVoucherGift(dataManager: DataManager, accountManager: AccountManager) async {
        let context: (accounts: [AccountInfo], exchangeMid: String, preferredCardTitle: String?)? = await MainActor.run {
            guard !isDiscoveringGift else { return nil }
            let accounts = combinedAccounts(from: accountManager)
            guard !accounts.isEmpty else {
                accountManager.showToast("请先添加账号，再进行自动识别", type: .info)
                return nil
            }

            isDiscoveringGift = true
            return (
                accounts,
                dataManager.settings.exchangeMid,
                dataManager.settings.forceExchangeCardTitle
            )
        }

        guard let context else { return }

        defer {
            Task { @MainActor in
                self.isDiscoveringGift = false
            }
        }

        do {
            var resolvedToken: String?
            var resolvedUid: String?
            var lastLoginError: String?

            for account in context.accounts {
                do {
                    let (isValid, token, uid) = try await apiService.login(
                        username: account.username,
                        password: account.password
                    )

                    if isValid, let token {
                        resolvedToken = token
                        resolvedUid = uid
                        break
                    } else {
                        lastLoginError = "账号 \(account.username) 登录失败"
                    }
                } catch let apiError as APIService.APIError {
                    lastLoginError = apiError.message
                } catch {
                    lastLoginError = error.localizedDescription
                }
            }

            guard let rawToken = resolvedToken else {
                let finalLoginError = lastLoginError
                await MainActor.run {
                    if let finalLoginError {
                        accountManager.showToast("登录失败，无法识别：\(finalLoginError)", type: .error)
                    } else {
                        accountManager.showToast("登录失败，无法识别", type: .error)
                    }
                }
                return
            }

            let tokenForGiftList: String
            if rawToken.contains(",") {
                tokenForGiftList = rawToken
            } else if let uid = resolvedUid, !uid.isEmpty {
                tokenForGiftList = "\(rawToken),\(uid)"
            } else {
                tokenForGiftList = rawToken
            }

            let gifts = try await apiService.getParkingVoucherGiftCandidates(
                token: tokenForGiftList,
                mid: context.exchangeMid
            )

            guard let gift = preferredParkingVoucherGift(
                from: gifts,
                preferredCardTitle: context.preferredCardTitle
            ) else {
                throw APIService.APIError.networkError("未找到停车券礼品")
            }

            await MainActor.run {
                dataManager.settings.exchangeGid = String(gift.id)
                dataManager.saveSettings()
                accountManager.showToast("已识别：\(gift.n)（gid=\(gift.id)）", type: .success)
            }
        } catch let apiError as APIService.APIError {
            await MainActor.run {
                accountManager.showToast("识别失败：\(apiError.message)", type: .error)
            }
        } catch {
            await MainActor.run {
                accountManager.showToast("识别失败：\(error.localizedDescription)", type: .error)
            }
        }
    }

    private func loginFirstCheckinSession(accounts: [AccountInfo]) async -> CheckinQuerySession? {
        for account in accounts {
            do {
                let (isValid, token, _) = try await apiService.login(
                    username: account.username,
                    password: account.password
                )

                if isValid, let token {
                    return CheckinQuerySession(username: account.username, token: token)
                }
            } catch {
                continue
            }
        }

        return nil
    }

    private static func parseFirstInteger(from texts: [String?]) -> Int? {
        for text in texts {
            guard let text else { continue }
            if let match = text.range(of: #"\d+"#, options: .regularExpression) {
                return Int(text[match])
            }
        }
        return nil
    }

    private static func canSign(from response: APIService.CheckinBeforeResponse) -> Bool {
        guard response.m == 1 else { return false }
        let alreadyChecked = (response.d?.IsCheckIn ?? false) || (response.d?.IsCheckInForGroup ?? false)
        guard !alreadyChecked else { return false }
        return (response.d?.IsOpenCheckin ?? false) || (response.d?.IsOpenCheckinForGroup ?? false)
    }

    private static func estimateRewardInfo(
        summary: APIService.CheckinRuleSummaryResponseData?,
        detail: APIService.CheckinDetailResponseData?
    ) -> (reward: Int?, description: String, isSimple: Bool) {
        let summaryDescription = summary?.CheckinRuleDescribe?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard summary?.CheckinRewardRuleType == 0,
              let rules = summary?.RuleList,
              !rules.isEmpty else {
            return (nil, summaryDescription?.isEmpty == false ? summaryDescription! : "规则复杂", false)
        }

        let targetDay = max(1, (detail?.ContinueDay ?? 0) + 1)
        guard let matchedRule = rules.first(where: { rule in
            let start = rule.StartDay ?? Int.min
            let end = rule.EndDay ?? Int.max
            return targetDay >= start && targetDay <= end
        }) else {
            return (nil, summaryDescription?.isEmpty == false ? summaryDescription! : "规则复杂", false)
        }

        let reward = parseFirstInteger(
            from: [
                matchedRule.RewardContent,
                matchedRule.Num,
                matchedRule.RewardSummary,
                matchedRule.RewardTitle
            ]
        )

        guard let reward else {
            return (nil, summaryDescription?.isEmpty == false ? summaryDescription! : "规则复杂", false)
        }

        let ruleDescription = matchedRule.RewardTitle?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedDescription = ruleDescription?.isEmpty == false
            ? ruleDescription!
            : (summaryDescription?.isEmpty == false ? summaryDescription! : "连续\(targetDay)天")

        return (reward, resolvedDescription, true)
    }

    private static func evaluateMallRecommendation(
        mall: CheckinMallInfo,
        session: CheckinQuerySession,
        apiService: APIServiceProtocol
    ) async -> CheckinMallRecommendation? {
        let summaryResponse = try? await apiService.getCheckinRuleSummary(
            token: session.token,
            mallID: mall.mallID
        )
        let summaryData = summaryResponse?.m == 1 ? summaryResponse?.d : nil

        guard let before = try? await apiService.getCheckinBefore(
            token: session.token,
            mallID: mall.mallID
        ),
        canSign(from: before) else {
            return nil
        }

        let rewardInfo: (reward: Int?, description: String, isSimple: Bool)
        if summaryData?.CheckinRewardRuleType == 0 {
            let detail = try? await apiService.getCheckinDetail(
                token: session.token,
                mallID: mall.mallID
            )
            rewardInfo = estimateRewardInfo(summary: summaryData, detail: detail?.d)
        } else {
            let description = summaryData?.CheckinRuleDescribe?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            rewardInfo = (
                reward: nil,
                description: description?.isEmpty == false ? description! : "规则复杂",
                isSimple: false
            )
        }

        return CheckinMallRecommendation(
            mallID: mall.mallID,
            mallName: mall.name,
            signableAccountCount: 1,
            estimatedRewardTotal: rewardInfo.isSimple ? rewardInfo.reward : nil,
            isComplexRule: !rewardInfo.isSimple,
            ruleDescription: rewardInfo.description
        )
    }

    func queryCheckinMallRecommendations(dataManager _: DataManager, accountManager: AccountManager) async {
        let nurseryAccounts = await MainActor.run {
            accountManager.nurseryAccounts
        }

        guard !nurseryAccounts.isEmpty else {
            await MainActor.run {
                accountManager.showToast("养号区为空，无法查询签到商场", type: .info)
            }
            return
        }

        let canStart = await MainActor.run { () -> Bool in
            guard !isQueryingCheckinMalls else { return false }
            isQueryingCheckinMalls = true
            checkinMallQueryStatusText = "正在登录养号区样本账号..."
            checkinMallRecommendations = []
            return true
        }

        guard canStart else { return }

        defer {
            Task { @MainActor in
                self.isQueryingCheckinMalls = false
            }
        }

        guard let sampleSession = await loginFirstCheckinSession(accounts: nurseryAccounts) else {
            await MainActor.run {
                checkinMallQueryStatusText = "未找到可登录的养号区账号"
                accountManager.showToast("养号区账号登录失败，无法查询签到商场", type: .error)
            }
            return
        }

        await MainActor.run {
            checkinMallQueryStatusText = "样本账号 \(sampleSession.username) 正在扫描商场（0/\(CheckinMallCatalog.all.count)）"
        }

        var results: [CheckinMallRecommendation] = []
        let totalMallCount = CheckinMallCatalog.all.count
        let maxConcurrentMallTasks = min(4, totalMallCount)
        let apiService = self.apiService

        await withTaskGroup(of: CheckinMallRecommendation?.self) { group in
            var iterator = CheckinMallCatalog.all.makeIterator()
            var completedMallCount = 0

            for _ in 0..<maxConcurrentMallTasks {
                guard let mall = iterator.next() else { break }
                group.addTask {
                    await Self.evaluateMallRecommendation(
                        mall: mall,
                        session: sampleSession,
                        apiService: apiService
                    )
                }
            }

            while let recommendation = await group.next() {
                completedMallCount += 1
                if let recommendation {
                    results.append(recommendation)
                }

                let progressText = "样本账号 \(sampleSession.username) 正在扫描商场（\(completedMallCount)/\(totalMallCount)）"
                await MainActor.run {
                    self.checkinMallQueryStatusText = progressText
                }

                if let nextMall = iterator.next() {
                    group.addTask {
                        await Self.evaluateMallRecommendation(
                            mall: nextMall,
                            session: sampleSession,
                            apiService: apiService
                        )
                    }
                }
            }
        }

        let sortedResults = results.sorted { lhs, rhs in
            if lhs.isComplexRule != rhs.isComplexRule {
                return rhs.isComplexRule
            }

            let lhsReward = lhs.estimatedRewardTotal ?? -1
            let rhsReward = rhs.estimatedRewardTotal ?? -1
            if lhsReward != rhsReward {
                return lhsReward > rhsReward
            }

            if lhs.signableAccountCount != rhs.signableAccountCount {
                return lhs.signableAccountCount > rhs.signableAccountCount
            }

            return lhs.mallName < rhs.mallName
        }

        await MainActor.run {
            checkinMallRecommendations = sortedResults
            checkinMallQueryStatusText = "样本账号 \(sampleSession.username) 扫描完成，共 \(sortedResults.count) 个可用商场"

            if sortedResults.isEmpty {
                accountManager.showToast("未查询到可推荐的签到商场", type: .info)
            } else {
                accountManager.showToast("已查询 \(sortedResults.count) 个签到商场推荐", type: .success)
            }
        }
    }

    func selectAutoCheckinMall(
        _ recommendation: CheckinMallRecommendation,
        dataManager: DataManager,
        accountManager: AccountManager
    ) {
        dataManager.settings.autoCheckinTargetMallID = recommendation.mallID
        dataManager.settings.autoCheckinTargetMallName = recommendation.mallName
        dataManager.saveSettings()
        accountManager.showToast("已选定签到商场：\(recommendation.mallName)", type: .success)
    }
}
