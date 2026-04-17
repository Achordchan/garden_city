// Purpose: Toolbar content for the main window (add account, settings, plate menu, filter, batch actions).
// Author: Achord <achordchan@gmail.com>
import SwiftUI

struct ContentToolbar: ToolbarContent {
    private let mainPrincipalContentWidth: CGFloat = 520
    private let nurseryPrincipalContentWidth: CGFloat = 240
    private let plateMenuWidth: CGFloat = 92
    private let nurserySearchFieldWidth: CGFloat = 150

    @ObservedObject var viewModel: AccountsViewModel
    @Binding var showingAddAccount: Bool
    @Binding var showingSettings: Bool
    @Binding var showingPlateManager: Bool
    @Binding var showingParkingFeeQuery: Bool
    @Binding var showingNurserySearch: Bool
    @Environment(\.openWindow) private var openWindow

    var body: some ToolbarContent {
        ToolbarItemGroup {
            if viewModel.isMainSectionSelected {
                Button {
                    showingAddAccount = true
                } label: {
                    Label("添加账号", systemImage: "plus")
                        .labelStyle(.iconOnly)
                }
                .help("添加账号")

                Button {
                    openWindow(id: "beta-account")
                } label: {
                    Label("获取账号（Beta）", systemImage: "simcard.2")
                }
                .help("获取账号（Beta）")
            }
        }

        ToolbarItem(placement: .principal) {
            HStack(spacing: 12) {
                Picker("账号分区", selection: $viewModel.selectedSection) {
                    ForEach(AccountDisplaySection.allCases) { section in
                        Text(section.title).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)

                if viewModel.isNurserySectionSelected {
                    Menu {
                        ForEach(NurserySortOption.allCases) { option in
                            Button {
                                viewModel.nurserySortOption = option
                            } label: {
                                if viewModel.nurserySortOption == option {
                                    Label(option.title, systemImage: "checkmark")
                                } else {
                                    Text(option.title)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                    .fixedSize()
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .help("选择养号区排序方式")
                } else if viewModel.isMainSectionSelected {
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

                        Divider()

                        if viewModel.hasMorePlates {
                            Button {
                                showingPlateManager = true
                            } label: {
                                Label("更多车牌号…", systemImage: "ellipsis")
                            }
                        }

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
                        .frame(width: plateMenuWidth, alignment: .leading)
                    }
                    .help("选择车牌号")

                    Button {
                        showingParkingFeeQuery = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "car.fill")
                            Text("查费用")
                        }
                        .font(.callout)
                        .foregroundColor(viewModel.canQueryParkingFee ? .primary : .secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(Capsule(style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(!viewModel.canQueryParkingFee)
                    .opacity(viewModel.canQueryParkingFee ? 1 : 0.65)
                    .help(viewModel.parkingFeeButtonHelp)

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
            .frame(width: currentPrincipalContentWidth, alignment: .leading)
        }

        ToolbarItemGroup(placement: .primaryAction) {
            if viewModel.isMainSectionSelected {
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

            if viewModel.isNurserySectionSelected {
                Group {
                    if showingNurserySearch {
                        ToolbarSearchField(
                            query: viewModel.nurserySearchQuery,
                            shouldFocus: showingNurserySearch,
                            onQueryChange: { newValue in
                                if viewModel.nurserySearchQuery != newValue {
                                    viewModel.nurserySearchQuery = newValue
                                }
                            }
                        )
                    } else {
                        Color.clear
                            .accessibilityHidden(true)
                    }
                }
                .frame(width: nurserySearchFieldWidth, height: 28)

                ToolbarSearchAccessory(
                    isPresented: $showingNurserySearch,
                    onClose: {
                        viewModel.resetNurserySearch()
                    }
                )
            }

            Button {
                showingSettings = true
            } label: {
                Label("设置", systemImage: "gearshape")
                    .labelStyle(.iconOnly)
            }
            .help("设置")
        }
    }

    private var currentPrincipalContentWidth: CGFloat {
        viewModel.isNurserySectionSelected ? nurseryPrincipalContentWidth : mainPrincipalContentWidth
    }
}

private struct ToolbarSearchAccessory: View {
    @Binding var isPresented: Bool
    let onClose: () -> Void

    var body: some View {
        Button {
            if isPresented {
                onClose()
                isPresented = false
            } else {
                isPresented = true
            }
        } label: {
            Image(systemName: "magnifyingglass")
                .foregroundColor(isPresented ? .accentColor : .primary)
        }
        .buttonStyle(.plain)
        .help(isPresented ? "关闭搜索" : "搜索账号")
    }
}
