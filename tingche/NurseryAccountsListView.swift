import SwiftUI

struct NurseryAccountsListView: View {
    @ObservedObject var viewModel: AccountsViewModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(viewModel.displayedAccounts) { account in
                    nurseryAccountView(for: account)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 16)
        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    @ViewBuilder
    private func nurseryAccountView(for account: AccountInfo) -> some View {
        AccountRow(
            account: account,
            mode: .nursery,
            layout: .list,
            onMoveToNursery: { },
            onMoveToMain: {
                viewModel.moveNurseryAccountToMain(account)
            },
            onDeletePermanently: {
                viewModel.permanentlyDeleteNurseryAccount(account)
            },
            onRefreshBonus: {
                Task {
                    await viewModel.refreshBonus(for: account)
                }
            },
            onRefreshVoucher: {
                Task {
                    await viewModel.refreshVoucherCount(for: account)
                }
            },
            onExchange: { },
            onCheckin: {
                Task {
                    await viewModel.performCheckin(for: account)
                }
            },
            accountManager: viewModel.accountManager,
            dataManager: viewModel.dataManager
        )
    }
}
