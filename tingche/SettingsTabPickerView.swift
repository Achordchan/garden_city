// Purpose: Segmented tab picker for the settings window.
// Author: Achord <achordchan@gmail.com>
import SwiftUI

struct SettingsTabPickerView: View {
    @Binding var selectedTab: SettingsTab

    var body: some View {
        HStack {
            Picker("", selection: $selectedTab) {
                Label("基本", systemImage: "gearshape").tag(SettingsTab.basic)
                Label("备份", systemImage: "lock.shield").tag(SettingsTab.security)
                Label("高级", systemImage: "gearshape.2").tag(SettingsTab.advanced)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
}
