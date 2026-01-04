// Purpose: Toast UI component for transient user feedback.
// Author: Achord <achordchan@gmail.com>
import SwiftUI

// 添加 Toast 视图组件
struct ToastView: View {
    let message: String
    let type: AccountManager.ToastType

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.iconName)
                .foregroundColor(.white)
            Text(message)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(type.backgroundColor)
        .cornerRadius(8)
        .shadow(radius: 4)
    }
}
