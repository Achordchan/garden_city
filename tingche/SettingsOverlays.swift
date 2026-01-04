// Purpose: Settings view modifier that wires sheets, alerts, folder picker trigger, and toast overlay.
// Author: Achord <achordchan@gmail.com>
import SwiftUI

struct SettingsOverlaysModifier: ViewModifier {
    @ObservedObject var dataManager: DataManager
    @ObservedObject var accountManager: AccountManager

    @Binding var showingFolderPicker: Bool
    let onFolderPickerRequested: () -> Void

    @Binding var showingBackupListView: Bool
    @Binding var showingDeletedAccountsView: Bool
    @Binding var showingLicensePlateManager: Bool

    @Binding var showingRestoreAlert: Bool
    let selectedBackupFile: BackupFileInfo?
    let restoreAlertMessage: String
    let onConfirmRestore: (BackupFileInfo) -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: showingFolderPicker) { isPresented in
                if isPresented {
                    DispatchQueue.main.async {
                        onFolderPickerRequested()
                    }
                }
            }
            .sheet(isPresented: $showingBackupListView) {
                BackupListView(dataManager: dataManager, accountManager: accountManager)
            }
            .sheet(isPresented: $showingDeletedAccountsView) {
                DeletedAccountsView(dataManager: dataManager, accountManager: accountManager)
            }
            .sheet(isPresented: $showingLicensePlateManager) {
                LicensePlateManagerView(dataManager: dataManager)
            }
            .alert("恢复备份", isPresented: $showingRestoreAlert) {
                Button("取消", role: .cancel) { }
                Button("确认恢复") {
                    if let backupFile = selectedBackupFile {
                        onConfirmRestore(backupFile)
                    }
                }
            } message: {
                Text(restoreAlertMessage)
            }
            .overlay(alignment: .top) {
                if accountManager.showToast
                    && !showingBackupListView
                    && !showingLicensePlateManager
                    && !showingDeletedAccountsView
                    && accountManager.toastMessage != "设置已保存" {
                    ToastView(message: accountManager.toastMessage, type: accountManager.toastType)
                        .padding(.horizontal, 16)
                        .padding(.top, 64)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.easeInOut, value: accountManager.showToast)
                        .zIndex(999)
                        .allowsHitTesting(false)
                }
            }
    }
}

extension View {
    func settingsOverlays(
        dataManager: DataManager,
        accountManager: AccountManager,
        showingFolderPicker: Binding<Bool>,
        onFolderPickerRequested: @escaping () -> Void,
        showingBackupListView: Binding<Bool>,
        showingDeletedAccountsView: Binding<Bool>,
        showingLicensePlateManager: Binding<Bool>,
        showingRestoreAlert: Binding<Bool>,
        selectedBackupFile: BackupFileInfo?,
        restoreAlertMessage: String,
        onConfirmRestore: @escaping (BackupFileInfo) -> Void
    ) -> some View {
        modifier(
            SettingsOverlaysModifier(
                dataManager: dataManager,
                accountManager: accountManager,
                showingFolderPicker: showingFolderPicker,
                onFolderPickerRequested: onFolderPickerRequested,
                showingBackupListView: showingBackupListView,
                showingDeletedAccountsView: showingDeletedAccountsView,
                showingLicensePlateManager: showingLicensePlateManager,
                showingRestoreAlert: showingRestoreAlert,
                selectedBackupFile: selectedBackupFile,
                restoreAlertMessage: restoreAlertMessage,
                onConfirmRestore: onConfirmRestore
            )
        )
    }
}
