// Purpose: ViewModel for the main content, bridging AccountManager and DataManager for SwiftUI views.
// Author: Achord <achordchan@gmail.com>
import Combine
import SwiftUI

enum AccountDisplaySection: String, CaseIterable, Identifiable {
    case main
    case nursery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .main:
            return "主账号"
        case .nursery:
            return "养号区"
        }
    }

    var emptyTitle: String {
        switch self {
        case .main:
            return "暂无主账号"
        case .nursery:
            return "养号区暂无账号"
        }
    }

    var emptyDescription: String {
        switch self {
        case .main:
            return "点击工具栏的“添加账号”开始使用"
        case .nursery:
            return "把主账号移入养号区后，会显示在这里"
        }
    }
}

enum NurserySortOption: String, CaseIterable, Identifiable {
    case addedTimeNewest
    case addedTimeOldest
    case bonusHighToLow
    case bonusLowToHigh

    var id: String { rawValue }

    var title: String {
        switch self {
        case .addedTimeNewest:
            return "添加时间（新到旧）"
        case .addedTimeOldest:
            return "添加时间（旧到新）"
        case .bonusHighToLow:
            return "积分（高到低）"
        case .bonusLowToHigh:
            return "积分（低到高）"
        }
    }
}

final class AccountsViewModel: ObservableObject {
    private enum MigrationKeys {
        static let deletedAccountsToNurseryV1 = "didMigrateDeletedAccountsToNurseryV1"
    }

    let accountManager: AccountManager
    let dataManager: DataManager

    @Published var showOnlyUnprocessed: Bool = false {
        didSet {
            guard oldValue != showOnlyUnprocessed else { return }
            recomputeDisplayedAccounts()
        }
    }
    @Published var selectedSection: AccountDisplaySection = .main {
        didSet {
            guard oldValue != selectedSection else { return }
            recomputeDisplayedAccounts()
        }
    }
    @Published var nurserySearchQuery: String = "" {
        didSet {
            guard oldValue != nurserySearchQuery else { return }
            recomputeDisplayedAccounts()
        }
    }
    @Published var nurserySortOption: NurserySortOption = .addedTimeOldest {
        didSet {
            guard oldValue != nurserySortOption else { return }
            recomputeDisplayedAccounts()
        }
    }
    @Published private(set) var displayedAccounts: [AccountInfo] = []

    private var cancellables = Set<AnyCancellable>()

    init(accountManager: AccountManager = .shared, dataManager: DataManager = .shared) {
        self.accountManager = accountManager
        self.dataManager = dataManager

        accountManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        dataManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        accountManager.$accounts
            .combineLatest(accountManager.$nurseryAccounts)
            .sink { [weak self] accounts, nurseryAccounts in
                self?.recomputeDisplayedAccounts(accounts: accounts, nurseryAccounts: nurseryAccounts)
            }
            .store(in: &cancellables)

        migrateDeletedAccountsIfNeeded()
        recomputeDisplayedAccounts()
    }

    var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 260, maximum: 360), spacing: 12, alignment: .top), count: 3)
    }

    var isMainSectionSelected: Bool {
        selectedSection == .main
    }

    var isNurserySectionSelected: Bool {
        selectedSection == .nursery
    }

    var currentSectionAccounts: [AccountInfo] {
        switch selectedSection {
        case .main:
            return accountManager.accounts
        case .nursery:
            return accountManager.nurseryAccounts
        }
    }

    var currentSectionAccountCount: Int {
        currentSectionAccounts.count
    }

    var currentSectionTotalVouchers: Int {
        currentSectionAccounts.reduce(0) { $0 + $1.voucherCount }
    }

    var currentSectionTotalBonus: Int {
        currentSectionAccounts.reduce(0) { $0 + $1.bonus }
    }

    var shouldShowFilteredEmptyState: Bool {
        selectedSection == .main && !accountManager.accounts.isEmpty && displayedAccounts.isEmpty
    }

    var shouldShowNurserySearchEmptyState: Bool {
        selectedSection == .nursery
            && !accountManager.nurseryAccounts.isEmpty
            && displayedAccounts.isEmpty
            && !nurserySearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var platesInQuickMenu: [String] {
        Array(dataManager.settings.licensePlates.prefix(8))
    }

    var hasMorePlates: Bool {
        dataManager.settings.licensePlates.count > platesInQuickMenu.count
    }

    var allAccountsForSelection: [AccountInfo] {
        accountManager.allManagedAccounts()
    }

    var forcedExchangeAccount: AccountInfo? {
        guard let forcedId = dataManager.settings.forceExchangeAccountId else {
            return nil
        }
        return allAccountsForSelection.first { $0.id.uuidString == forcedId }
    }

    var canQueryParkingFee: Bool {
        let plate = dataManager.settings.selectedLicensePlate.trimmingCharacters(in: .whitespacesAndNewlines)
        return !plate.isEmpty && forcedExchangeAccount != nil
    }

    var parkingFeeButtonHelp: String {
        let plate = dataManager.settings.selectedLicensePlate.trimmingCharacters(in: .whitespacesAndNewlines)
        if plate.isEmpty {
            return "请先选择车牌号"
        }
        guard let forcedId = dataManager.settings.forceExchangeAccountId, !forcedId.isEmpty else {
            return "先到高级设置选择“强制兑换账号”"
        }
        guard allAccountsForSelection.contains(where: { $0.id.uuidString == forcedId }) else {
            return "当前强制兑换账号已不存在，请重新选择"
        }
        return "查询当前车牌费用"
    }

    var selectedCheckinMallName: String {
        let rawName = dataManager.settings.autoCheckinTargetMallName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !rawName.isEmpty {
            return rawName
        }
        if let mallID = dataManager.settings.autoCheckinTargetMallID {
            return CheckinMallCatalog.name(for: mallID) ?? "MallID \(mallID)"
        }
        return ""
    }

    func moveAccountToNursery(_ account: AccountInfo) {
        accountManager.moveAccountToNursery(account: account)
        recomputeDisplayedAccounts()
    }

    func moveNurseryAccountToMain(_ account: AccountInfo) {
        accountManager.moveNurseryAccountToMain(account: account)
        recomputeDisplayedAccounts()
    }

    func permanentlyDeleteNurseryAccount(_ account: AccountInfo) {
        accountManager.permanentlyDeleteNurseryAccount(account: account)
        recomputeDisplayedAccounts()
        DispatchQueue.main.async { [weak self] in
            self?.recomputeDisplayedAccounts()
        }
    }

    func refreshBonus(for account: AccountInfo) async {
        await accountManager.refreshBonus(for: account)
    }

    func refreshVoucherCount(for account: AccountInfo) async {
        await accountManager.refreshVoucherCount(for: account)
    }

    func performCheckin(for account: AccountInfo) async {
        await accountManager.performSingleCheckin(for: account, dataManager: dataManager)
    }

    func exchangeVoucher(for account: AccountInfo) async {
        await accountManager.exchangeVoucher(
            for: account,
            exchangeCount: dataManager.settings.exchangeCount,
            mid: dataManager.settings.exchangeMid,
            gid: dataManager.settings.exchangeGid,
            cardLevelOverride: dataManager.settings.forceExchangeCardLevel,
            cardTitleOverride: dataManager.settings.forceExchangeCardTitle
        )
    }

    func executeAllAccounts() async {
        await accountManager.executeAllAccounts(
            exchangeCount: dataManager.settings.exchangeCount,
            mid: dataManager.settings.exchangeMid,
            gid: dataManager.settings.exchangeGid,
            cardLevelOverride: dataManager.settings.forceExchangeCardLevel,
            cardTitleOverride: dataManager.settings.forceExchangeCardTitle
        )
    }

    func resetAllProcessedStatus() {
        accountManager.resetAllProcessedStatus()
    }

    func selectLicensePlate(_ plate: String) {
        dataManager.selectLicensePlate(plate)
    }

    func resetNurserySearch() {
        nurserySearchQuery = ""
    }

    @MainActor
    func startBackgroundServicesIfNeeded() {
        accountManager.resetDailyStatusesIfNeeded()
        AutoCheckinCoordinator.shared.startIfNeeded(accountManager: accountManager, dataManager: dataManager)
    }

    func createInitialBackupIfNeeded() async {
        if dataManager.backupFiles.isEmpty
            && (!accountManager.accounts.isEmpty || !accountManager.nurseryAccounts.isEmpty)
            && !dataManager.settings.backupLocation.isEmpty {
            let success = await dataManager.createBackup(
                accounts: accountManager.accounts,
                nurseryAccounts: accountManager.nurseryAccounts
            )
            if success {
                print("已创建初始备份")
            }
        }
    }

    private func migrateDeletedAccountsIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: MigrationKeys.deletedAccountsToNurseryV1) else {
            return
        }

        accountManager.importDeletedAccountsToNurseryIfNeeded(dataManager.deletedAccounts)
        UserDefaults.standard.set(true, forKey: MigrationKeys.deletedAccountsToNurseryV1)
    }

    private func recomputeDisplayedAccounts(
        accounts: [AccountInfo]? = nil,
        nurseryAccounts: [AccountInfo]? = nil
    ) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.recomputeDisplayedAccounts(accounts: accounts, nurseryAccounts: nurseryAccounts)
            }
            return
        }

        let mainAccounts = accounts ?? accountManager.accounts
        let nurseryAccounts = nurseryAccounts ?? accountManager.nurseryAccounts
        let computedAccounts: [AccountInfo]

        if selectedSection == .main, showOnlyUnprocessed {
            computedAccounts = mainAccounts.filter { !$0.isProcessedToday }
        } else if selectedSection == .nursery {
            let keyword = nurserySearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            let indexedAccounts = nurseryAccounts.enumerated().map { index, account in
                (index, account)
            }

            let filteredAccounts = indexedAccounts.filter { _, account in
                guard !keyword.isEmpty else { return true }
                return account.username.localizedCaseInsensitiveContains(keyword)
            }

            let sortedAccounts: [(Int, AccountInfo)] = switch nurserySortOption {
            case .addedTimeNewest:
                filteredAccounts.sorted { lhs, rhs in
                    lhs.0 > rhs.0
                }
            case .addedTimeOldest:
                filteredAccounts.sorted { lhs, rhs in
                    lhs.0 < rhs.0
                }
            case .bonusHighToLow:
                filteredAccounts.sorted { lhs, rhs in
                    if lhs.1.bonus == rhs.1.bonus {
                        return lhs.0 < rhs.0
                    }
                    return lhs.1.bonus > rhs.1.bonus
                }
            case .bonusLowToHigh:
                filteredAccounts.sorted { lhs, rhs in
                    if lhs.1.bonus == rhs.1.bonus {
                        return lhs.0 < rhs.0
                    }
                    return lhs.1.bonus < rhs.1.bonus
                }
            }

            computedAccounts = sortedAccounts.map(\.1)
        } else {
            computedAccounts = selectedSection == .main ? mainAccounts : nurseryAccounts
        }

        displayedAccounts = computedAccounts
    }
}
