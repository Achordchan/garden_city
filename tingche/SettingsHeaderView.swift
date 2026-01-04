// Purpose: Settings header UI (title, tab icon/subtitle, save and close action).
// Author: Achord <achordchan@gmail.com>
import SwiftUI

struct SettingsHeaderView: View {
    let tabIconName: String
    let tabSubtitle: String
    let onSaveAndClose: () -> Void

    var body: some View {
        HStack {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.14))
                        .frame(width: 34, height: 34)
                    Image(systemName: tabIconName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("应用设置")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(tabSubtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Button("保存并关闭") {
                onSaveAndClose()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }
}
