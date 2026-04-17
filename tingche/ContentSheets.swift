// Purpose: Sheet presentations for the main window (add account, settings, plate manager).
// Author: Achord <achordchan@gmail.com>
import SwiftUI

struct ContentSheetsModifier: ViewModifier {
    @ObservedObject var viewModel: AccountsViewModel

    @Binding var showingAddAccount: Bool
    @Binding var showingSettings: Bool
    @Binding var showingPlateManager: Bool
    @Binding var showingParkingFeeQuery: Bool

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showingAddAccount) {
                AddAccountView(isPresented: $showingAddAccount, accountManager: viewModel.accountManager)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(dataManager: viewModel.dataManager, accountManager: viewModel.accountManager, isPresented: $showingSettings)
            }
            .sheet(isPresented: $showingPlateManager) {
                LicensePlateManagerView(dataManager: viewModel.dataManager)
            }
            .sheet(isPresented: $showingParkingFeeQuery) {
                ParkingFeeQuerySheet(accountManager: viewModel.accountManager, dataManager: viewModel.dataManager)
            }
    }
}

extension View {
    func contentSheets(
        viewModel: AccountsViewModel,
        showingAddAccount: Binding<Bool>,
        showingSettings: Binding<Bool>,
        showingPlateManager: Binding<Bool>,
        showingParkingFeeQuery: Binding<Bool>
    ) -> some View {
        modifier(
            ContentSheetsModifier(
                viewModel: viewModel,
                showingAddAccount: showingAddAccount,
                showingSettings: showingSettings,
                showingPlateManager: showingPlateManager,
                showingParkingFeeQuery: showingParkingFeeQuery
            )
        )
    }
}
