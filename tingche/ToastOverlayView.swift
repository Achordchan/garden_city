// Purpose: Overlay host for ToastView with suppression when sheets are presented.
// Author: Achord <achordchan@gmail.com>
import SwiftUI

struct ToastOverlayView: View {
    let showToast: Bool
    let toastMessage: String
    let toastType: AccountManager.ToastType

    let isShowingAddAccount: Bool
    let isShowingSettings: Bool
    let isShowingPlateManager: Bool

    var body: some View {
        if showToast
            && !isShowingAddAccount
            && !isShowingSettings
            && !isShowingPlateManager {
            ToastView(message: toastMessage, type: toastType)
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut, value: showToast)
                .zIndex(999)
                .allowsHitTesting(false)
        }
    }
}
