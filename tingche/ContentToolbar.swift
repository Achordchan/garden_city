// Purpose: Toolbar content for the main window (add account, settings, plate menu, filter, batch actions).
// Author: Achord <achordchan@gmail.com>
import SwiftUI

struct ContentToolbar: ToolbarContent {
    @ObservedObject var viewModel: AccountsViewModel
    @Binding var showingAddAccount: Bool
    @Binding var showingSettings: Bool
    @Binding var showingPlateManager: Bool

    var body: some ToolbarContent {
        ToolbarItemGroup {
            Button {
                showingAddAccount = true
            } label: {
                Label("添加账号", systemImage: "plus")
                    .labelStyle(.iconOnly)
            }
            .help("添加账号")

            Button {
                showingSettings = true
            } label: {
                Label("设置", systemImage: "gearshape")
                    .labelStyle(.iconOnly)
            }
            .help("设置")
        }

        ToolbarItem(placement: .principal) {
            HStack(spacing: 12) {
                Menu {
                    ForEach(viewModel.platesInQuickMenu, id: \.self) { plate in
                        Button {
                            viewModel.selectLicensePlate(plate)
                        } label: {
                            if viewModel.dataManager.settings.selectedLicensePlate == plate {
                                Label(plate, systemImage: "checkmark")
                            } else {
                                Text(plate)
                            }
                        }
                    }

                    if viewModel.hasMorePlates {
                        Divider()
                        Button {
                            showingPlateManager = true
                        } label: {
                            Label("更多车牌号…", systemImage: "ellipsis")
                        }
                    }

                    Divider()

                    Button {
                        showingPlateManager = true
                    } label: {
                        Label("管理车牌号…", systemImage: "pencil")
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(viewModel.dataManager.settings.selectedLicensePlate.isEmpty ? "车牌号" : viewModel.dataManager.settings.selectedLicensePlate)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(minWidth: 160)
                }
                .help("选择车牌号")

                Button {
                    viewModel.showOnlyUnprocessed.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.showOnlyUnprocessed ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        Text("仅未处理")
                    }
                    .font(.callout)
                    .foregroundColor(viewModel.showOnlyUnprocessed ? .accentColor : .primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(viewModel.showOnlyUnprocessed ? Color.accentColor.opacity(0.16) : Color(NSColor.controlBackgroundColor))
                    .clipShape(Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .help(viewModel.showOnlyUnprocessed ? "已开启：仅显示未处理账号" : "开启：仅显示未处理账号")
                .animation(.easeInOut(duration: 0.15), value: viewModel.showOnlyUnprocessed)
            }
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                Task {
                    await viewModel.executeAllAccounts()
                }
            } label: {
                Label("一键执行", systemImage: "bolt.fill")
                    .labelStyle(.iconOnly)
            }
            .disabled(viewModel.accountManager.isExecutingAll || viewModel.accountManager.accounts.isEmpty)
            .help("一键执行")

            Button {
                viewModel.resetAllProcessedStatus()
            } label: {
                Label("重置状态", systemImage: "arrow.counterclockwise")
                    .labelStyle(.iconOnly)
            }
            .help("重置状态")
        }
    }
}
