// Purpose: Settings window root view (tabs, overlays) for app configuration and maintenance actions.
// Author: Achord <achordchan@gmail.com>
//
//  SettingsView.swift
//  tingche
//
//  Created by AI Assistant on 2025/9/8.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var dataManager: DataManager
    @ObservedObject var accountManager: AccountManager
    @Binding var isPresented: Bool

    @StateObject private var viewModel = SettingsViewModel()

    @Environment(\.openWindow) private var openWindow
    
    @State private var showingFolderPicker = false
    @State private var showingDeletedAccountsView = false
    @State private var showingBackupListView = false
    @State private var showingRestoreAlert = false
    @State private var selectedBackupFile: BackupFileInfo?
    @State private var restoreAlertMessage = ""
    @State private var showingLicensePlateManager = false
    
    @State private var selectedTab: SettingsTab = .basic
    @State private var advancedKeyInput = ""
    @State private var isAdvancedUnlocked = false
    
    private static let integerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = 0
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .basic:
            SettingsBasicTabView(
                dataManager: dataManager,
                showingLicensePlateManager: $showingLicensePlateManager
            )
        case .security:
            SettingsSecurityTabView(
                dataManager: dataManager,
                accountManager: accountManager,
                showingFolderPicker: $showingFolderPicker,
                showingDeletedAccountsView: $showingDeletedAccountsView,
                showingBackupListView: $showingBackupListView,
                createManualBackup: {
                    await createManualBackup()
                },
                exportAccountData: exportAccountData,
                importAccountData: importAccountData
            )
        case .advanced:
            SettingsAdvancedTabView(
                dataManager: dataManager,
                accountManager: accountManager,
                viewModel: viewModel,
                advancedKeyInput: $advancedKeyInput,
                isAdvancedUnlocked: $isAdvancedUnlocked
            )
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                // 标题
                SettingsHeaderView(
                    tabIconName: selectedTab.iconName,
                    tabSubtitle: selectedTab.subtitle,
                    onSaveAndClose: {
                        dataManager.saveSettings()
                        isPresented = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            accountManager.showToast("设置已保存", type: .success)
                        }
                    }
                )
                
                VStack(spacing: 10) {
                    SettingsTabPickerView(selectedTab: $selectedTab)
                    
                    tabContent
                        .groupBoxStyle(SettingsCardGroupBoxStyle())
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.windowBackgroundColor))
            .background(
                LinearGradient(
                    colors: [
                        Color.accentColor.opacity(0.08),
                        Color.accentColor.opacity(0.02),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        .frame(minWidth: 760, idealWidth: 860, maxWidth: 980, minHeight: 640, idealHeight: 760, maxHeight: 980)
        .settingsOverlays(
            dataManager: dataManager,
            accountManager: accountManager,
            showingFolderPicker: $showingFolderPicker,
            onFolderPickerRequested: {
                showFolderPicker()
            },
            showingBackupListView: $showingBackupListView,
            showingDeletedAccountsView: $showingDeletedAccountsView,
            showingLicensePlateManager: $showingLicensePlateManager,
            showingRestoreAlert: $showingRestoreAlert,
            selectedBackupFile: selectedBackupFile,
            restoreAlertMessage: restoreAlertMessage,
            onConfirmRestore: { backupFile in
                restoreFromBackup(backupFile)
            }
        )
    }
    
    // MARK: - 私有方法
    private func createManualBackup() async {
        await SettingsFileActions.createManualBackup(dataManager: dataManager, accountManager: accountManager)
    }
    
    private func exportAccountData() {
        SettingsFileActions.exportAccountData(dataManager: dataManager, accountManager: accountManager)
    }
    
    private func importAccountData() {
        SettingsFileActions.importAccountData(dataManager: dataManager, accountManager: accountManager)
    }
    
    private func restoreFromBackup(_ backupFile: BackupFileInfo) {
        SettingsFileActions.restoreFromBackup(dataManager: dataManager, accountManager: accountManager, backupFile: backupFile)
    }
    
    // MARK: - 文件夹选择器
    private func showFolderPicker() {
        SettingsFileActions.showFolderPicker(
            dataManager: dataManager,
            onDismiss: {
                self.showingFolderPicker = false
            }
        )
    }
}

// MARK: - 删除记录查看视图

// MARK: - 备份列表视图

// MARK: - 车牌号管理视图
 