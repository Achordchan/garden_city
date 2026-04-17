// Purpose: Main SwiftUI view for the app window.
// Author: Achord <achordchan@gmail.com>
//
//  ContentView.swift
//  tingche1
//
//  Created by A chord on 2025/2/19.
//

import SwiftUI
import WebKit

struct ContentView: View {
    @StateObject private var viewModel = AccountsViewModel()
    @State private var showingAddAccount = false
    @State private var showingSettings = false
    @State private var showingPlateManager = false
    @State private var showingParkingFeeQuery = false
    @State private var showingNurserySearch = false
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        NavigationStack {
            AccountsMainContent(viewModel: viewModel)
            .navigationTitle("花园城停车助手 V3.1")
            .toolbar {
                ContentToolbar(
                    viewModel: viewModel,
                    showingAddAccount: $showingAddAccount,
                    showingSettings: $showingSettings,
                    showingPlateManager: $showingPlateManager,
                    showingParkingFeeQuery: $showingParkingFeeQuery,
                    showingNurserySearch: $showingNurserySearch
                )
            }
        }
        .contentSheets(
            viewModel: viewModel,
            showingAddAccount: $showingAddAccount,
            showingSettings: $showingSettings,
            showingPlateManager: $showingPlateManager,
            showingParkingFeeQuery: $showingParkingFeeQuery
        )
        .overlay(alignment: .top) {
            ToastOverlayView(
                showToast: viewModel.accountManager.showToast,
                toastMessage: viewModel.accountManager.toastMessage,
                toastType: viewModel.accountManager.toastType,
                isShowingAddAccount: showingAddAccount,
                isShowingSettings: showingSettings,
                isShowingPlateManager: showingPlateManager
            )
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            StatusBarView(
                sectionTitle: viewModel.selectedSection.title,
                accountCount: viewModel.currentSectionAccountCount,
                totalBonus: viewModel.currentSectionTotalBonus,
                totalVouchers: viewModel.currentSectionTotalVouchers,
                onAbout: {
                    openWindow(id: "about")
                },
                accountManager: viewModel.accountManager
            )
        }
        .setupMainWindow(
            selectedSection: viewModel.selectedSection,
            showingNurserySearch: $showingNurserySearch,
            nurserySearchQuery: $viewModel.nurserySearchQuery
        )
        .onAppear {
            viewModel.startBackgroundServicesIfNeeded()
            Task {
                await viewModel.createInitialBackupIfNeeded()
            }
        }
        .onChange(of: viewModel.selectedSection) { _, newValue in
            guard newValue != .nursery else { return }
            showingNurserySearch = false
            viewModel.resetNurserySearch()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettingsFromMenu)) { _ in
            showingSettings = true
        }
    }
}
