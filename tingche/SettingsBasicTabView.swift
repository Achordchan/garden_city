// Purpose: Settings basic tab UI (license plates and exchange-related settings).
// Author: Achord <achordchan@gmail.com>
import SwiftUI

struct SettingsBasicTabView: View {
    @ObservedObject var dataManager: DataManager
    @ObservedObject var accountManager: AccountManager
    @Binding var showingLicensePlateManager: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                GroupBox(label: HStack {
                    Label("车牌号管理", systemImage: "car.fill")
                    Spacer()
                    Text("当前：\(dataManager.settings.selectedLicensePlate)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }) {
                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("当前选中车牌号")
                                    .font(.headline)
                                Text("用于停车费查询")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Picker("选择车牌号", selection: $dataManager.settings.selectedLicensePlate) {
                                ForEach(dataManager.settings.licensePlates, id: \.self) { plate in
                                    Text(plate).tag(plate)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(minWidth: 120)
                        }

                        Divider()

                        HStack {
                            VStack(alignment: .leading) {
                                Text("车牌号列表")
                                    .font(.headline)
                                Text("管理所有车牌号")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button("管理车牌号") {
                                showingLicensePlateManager = true
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                GroupBox(label: HStack {
                    Label("停车券使用数量", systemImage: "ticket.fill")
                    Spacer()
                    Text("当前：\(dataManager.settings.selectedMaxCount) 张")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("每次使用数量")
                                    .font(.headline)
                                Text("影响“查看停车”页面里的可用数量")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Stepper(value: $dataManager.settings.selectedMaxCount, in: 1...20) {
                                Text("\(dataManager.settings.selectedMaxCount) 张")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.accentColor)
                            }
                            .frame(minWidth: 220)
                        }

                        HStack {
                            Text("1张")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("20张")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                GroupBox(label: HStack {
                    Label("兑换设置", systemImage: "arrow.left.arrow.right")
                    Spacer()
                    Text("当前：\(dataManager.settings.exchangeCount) 张")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("兑换数量")
                                    .font(.headline)
                                Text("影响每次“兑换停车券”的请求数量")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Stepper(value: $dataManager.settings.exchangeCount, in: 1...20) {
                                Text("\(dataManager.settings.exchangeCount) 张")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.accentColor)
                            }
                            .frame(minWidth: 220)
                        }

                        HStack {
                            Text("1张")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("20张")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                GroupBox(label: HStack {
                    Label("账号概览", systemImage: "person.3.fill")
                    Spacer()
                    Text("主 \(accountManager.accounts.count) · 养 \(accountManager.nurseryAccounts.count) · 删 \(dataManager.deletedAccounts.count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("当前账号数量")
                                .font(.headline)
                            Text("主账号、养号区与删除记录数量概览")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text("主 \(accountManager.accounts.count) · 养 \(accountManager.nurseryAccounts.count) · 删 \(dataManager.deletedAccounts.count)")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .frame(maxWidth: 860)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }
}
