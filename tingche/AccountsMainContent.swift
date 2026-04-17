// Purpose: Main content area for the home screen (empty state, filtered empty state, and accounts grid).
// Author: Achord <achordchan@gmail.com>
import SwiftUI

struct AccountsMainContent: View {
    @ObservedObject var viewModel: AccountsViewModel

    var body: some View {
        ZStack {
            if viewModel.currentSectionAccounts.isEmpty {
                ContentUnavailableView(
                    viewModel.selectedSection.emptyTitle,
                    systemImage: viewModel.selectedSection == .main ? "person.crop.circle.badge.plus" : "tray.full",
                    description: Text(viewModel.selectedSection.emptyDescription)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.shouldShowFilteredEmptyState {
                VStack(spacing: 14) {
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundColor(.secondary)

                    Text("全部已处理")
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text("当前已开启“仅未处理”过滤")
                        .foregroundColor(.secondary)

                    Button {
                        viewModel.showOnlyUnprocessed = false
                    } label: {
                        Text("显示全部账号")
                            .frame(minWidth: 120)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.shouldShowNurserySearchEmptyState {
                ContentUnavailableView(
                    "未找到匹配账号",
                    systemImage: "magnifyingglass",
                    description: Text("试试输入完整手机号，或清空搜索条件")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                if viewModel.selectedSection == .main {
                    ScrollView {
                        LazyVGrid(columns: viewModel.gridColumns, spacing: 12) {
                            ForEach(viewModel.displayedAccounts) { account in
                                mainAccountView(for: account)
                            }
                        }
                        .padding(16)
                    }
                } else {
                    NurseryAccountsListView(viewModel: viewModel)
                }
            }
        }
    }

    @ViewBuilder
    private func mainAccountView(for account: AccountInfo) -> some View {
        AccountRow(
            account: account,
            mode: .main,
            layout: .card,
            onMoveToNursery: {
                viewModel.moveAccountToNursery(account)
            },
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
            onExchange: {
                Task {
                    await viewModel.exchangeVoucher(for: account)
                }
            },
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
