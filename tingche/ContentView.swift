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
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        NavigationStack {
            AccountsMainContent(viewModel: viewModel)
            .navigationTitle("花园城停车助手 V3.0")
            .toolbar {
                ContentToolbar(
                    viewModel: viewModel,
                    showingAddAccount: $showingAddAccount,
                    showingSettings: $showingSettings,
                    showingPlateManager: $showingPlateManager
                )
            }
        }
        .contentSheets(
            viewModel: viewModel,
            showingAddAccount: $showingAddAccount,
            showingSettings: $showingSettings,
            showingPlateManager: $showingPlateManager
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
                accountCount: viewModel.accountCount,
                totalBonus: viewModel.totalBonus,
                totalVouchers: viewModel.totalVouchers,
                onAbout: {
                    openWindow(id: "about")
                }
            )
        }
        .setupMainWindow()
        .onAppear {
            // 在应用启动时创建初始备份
            Task {
                await viewModel.createInitialBackupIfNeeded()
            }
        }
    }
}

