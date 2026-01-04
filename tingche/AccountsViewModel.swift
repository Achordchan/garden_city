// Purpose: ViewModel for the main content, bridging AccountManager and DataManager for SwiftUI views.
// Author: Achord <achordchan@gmail.com>
import Combine
import SwiftUI

final class AccountsViewModel: ObservableObject {
    let accountManager: AccountManager
    let dataManager: DataManager

    @Published var showOnlyUnprocessed: Bool = false

    private var cancellables = Set<AnyCancellable>()

    init(accountManager: AccountManager = AccountManager(), dataManager: DataManager = DataManager()) {
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
    }

    var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 260, maximum: 360), spacing: 12, alignment: .top), count: 3)
    }

    var accountCount: Int {
        accountManager.accounts.count
    }

    var totalVouchers: Int {
        accountManager.accounts.reduce(0) { partialResult, account in
            partialResult + account.voucherCount
        }
    }

    var totalBonus: Int {
        accountManager.accounts.reduce(0) { partialResult, account in
            partialResult + account.bonus
        }
    }

    var displayedAccounts: [AccountInfo] {
        if showOnlyUnprocessed {
            return accountManager.accounts.filter { !$0.isProcessedToday }
        }
        return accountManager.accounts
    }

    var platesInQuickMenu: [String] {
        Array(dataManager.settings.licensePlates.prefix(8))
    }

    var hasMorePlates: Bool {
        dataManager.settings.licensePlates.count > platesInQuickMenu.count
    }

    func deleteAccount(_ account: AccountInfo) {
        accountManager.deleteAccount(account: account)
    }

    func refreshBonus(for account: AccountInfo) async {
        await accountManager.refreshBonus(for: account)
    }

    func refreshVoucherCount(for account: AccountInfo) async {
        await accountManager.refreshVoucherCount(for: account)
    }

    func exchangeVoucher(for account: AccountInfo) async {
        await accountManager.exchangeVoucher(
            for: account,
            exchangeCount: dataManager.settings.exchangeCount,
            mid: dataManager.settings.exchangeMid,
            gid: dataManager.settings.exchangeGid
        )
    }

    func executeAllAccounts() async {
        await accountManager.executeAllAccounts(
            exchangeCount: dataManager.settings.exchangeCount,
            mid: dataManager.settings.exchangeMid,
            gid: dataManager.settings.exchangeGid
        )
    }

    func resetAllProcessedStatus() {
        accountManager.resetAllProcessedStatus()
    }

    func selectLicensePlate(_ plate: String) {
        dataManager.selectLicensePlate(plate)
    }

    func createInitialBackupIfNeeded() async {
        if dataManager.backupFiles.isEmpty && !accountManager.accounts.isEmpty && !dataManager.settings.backupLocation.isEmpty {
            let success = await dataManager.createBackup(accounts: accountManager.accounts)
            if success {
                print("已创建初始备份")
            }
        }
    }
}
