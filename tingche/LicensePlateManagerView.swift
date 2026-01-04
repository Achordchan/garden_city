// Purpose: UI for managing license plates and selecting the active plate.
// Author: Achord <achordchan@gmail.com>
import SwiftUI
import AppKit
import Foundation

struct LicensePlateManagerView: View {
    @ObservedObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    @State private var newPlate = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingDeleteConfirmation = false
    @State private var platePendingDeletion: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer(minLength: 14)

                VStack(spacing: 18) {
                    HStack {
                        Text("车牌号管理")
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                        Button("完成") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.horizontal, 20)

                    ScrollView {
                        VStack(spacing: 16) {
                            GroupBox("添加新车牌号") {
                                VStack(spacing: 12) {
                                    HStack {
                                        TextField("输入车牌号", text: $newPlate)
                                            .textFieldStyle(.roundedBorder)
                                            .onSubmit {
                                                addLicensePlate()
                                            }

                                        Button("添加") {
                                            addLicensePlate()
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .disabled(newPlate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                    }

                                    Text("例如：苏A12345、京B54321")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                            }

                            GroupBox("已有车牌号") {
                                if dataManager.settings.licensePlates.isEmpty {
                                    Text("暂无车牌号")
                                        .foregroundColor(.secondary)
                                        .padding()
                                } else {
                                    VStack(spacing: 8) {
                                        ForEach(dataManager.settings.licensePlates, id: \.self) { plate in
                                            HStack {
                                                Text(plate)
                                                    .font(.system(.body, design: .monospaced))

                                                if plate == dataManager.settings.selectedLicensePlate {
                                                    Text("当前选中")
                                                        .font(.caption)
                                                        .foregroundColor(.green)
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 2)
                                                        .background(Color.green.opacity(0.1))
                                                        .cornerRadius(4)
                                                }

                                                Spacer()

                                                Button("选择") {
                                                    dataManager.selectLicensePlate(plate)
                                                }
                                                .buttonStyle(.bordered)
                                                .disabled(plate == dataManager.settings.selectedLicensePlate)
                                                .help(plate == dataManager.settings.selectedLicensePlate ? "当前已选中" : "设为当前车牌号")

                                                Button(action: {
                                                    platePendingDeletion = plate
                                                    showingDeleteConfirmation = true
                                                }) {
                                                    Image(systemName: "trash")
                                                        .foregroundColor(.red)
                                                }
                                                .buttonStyle(.plain)
                                                .disabled(dataManager.settings.licensePlates.count <= 1)
                                                .help(dataManager.settings.licensePlates.count <= 1 ? "至少需要保留一个车牌号" : "删除该车牌号")
                                            }
                                            .padding(.horizontal)
                                            .padding(.vertical, 8)
                                            .background(Color(NSColor.controlBackgroundColor))
                                            .cornerRadius(8)
                                        }
                                    }
                                    .padding()
                                }
                            }
                        }
                        .frame(maxWidth: 560)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 18)
                    }
                }

                Spacer(minLength: 14)
            }
        }
        .frame(minWidth: 500, idealWidth: 550, maxWidth: 700, minHeight: 400, idealHeight: 450, maxHeight: 600)
        .confirmationDialog(
            "确认删除车牌号",
            isPresented: $showingDeleteConfirmation,
            presenting: platePendingDeletion
        ) { plate in
            Button("删除", role: .destructive) {
                removeLicensePlate(plate)
                platePendingDeletion = nil
            }
            Button("取消", role: .cancel) {
                platePendingDeletion = nil
            }
        } message: { plate in
            Text("确定要删除车牌号 \(plate) 吗？")
        }
        .alert("提示", isPresented: $showingAlert) {
            Button("确定") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func addLicensePlate() {
        let plate = newPlate.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !plate.isEmpty else {
            alertMessage = "车牌号不能为空"
            showingAlert = true
            return
        }
        
        guard !dataManager.settings.licensePlates.contains(plate) else {
            alertMessage = "车牌号已存在"
            showingAlert = true
            return
        }
        
        dataManager.addLicensePlate(plate)
        newPlate = ""
        alertMessage = "车牌号添加成功"
        showingAlert = true
    }
    
    private func removeLicensePlate(_ plate: String) {
        guard dataManager.settings.licensePlates.count > 1 else {
            alertMessage = "至少需要保留一个车牌号"
            showingAlert = true
            return
        }
        
        dataManager.removeLicensePlate(plate)
        alertMessage = "车牌号删除成功"
        showingAlert = true
    }
}
