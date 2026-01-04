// Purpose: Main content area for the home screen (empty state, filtered empty state, and accounts grid).
// Author: Achord <achordchan@gmail.com>
import SwiftUI

struct AccountsMainContent: View {
    @ObservedObject var viewModel: AccountsViewModel

    var body: some View {
        ZStack {
            if viewModel.accountManager.accounts.isEmpty {
                ContentUnavailableView(
                    "暂无账号",
                    systemImage: "person.crop.circle.badge.plus",
                    description: Text("点击工具栏的“添加账号”开始使用")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.displayedAccounts.isEmpty {
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
            } else {
                ScrollView {
                    LazyVGrid(columns: viewModel.gridColumns, spacing: 12) {
                        ForEach(viewModel.displayedAccounts) { account in
                            AccountRow(
                                account: account,
                                onDelete: {
                                    viewModel.deleteAccount(account)
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
                                accountManager: viewModel.accountManager,
                                dataManager: viewModel.dataManager
                            )
                        }
                    }
                    .padding(16)
                }
            }
        }
    }
}
