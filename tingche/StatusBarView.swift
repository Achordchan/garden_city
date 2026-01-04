// Purpose: Bottom status bar showing totals and About entry.
// Author: Achord <achordchan@gmail.com>
import SwiftUI

struct StatusBarView: View {
    let accountCount: Int
    let totalBonus: Int
    let totalVouchers: Int
    let onAbout: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button {
                onAbout()
            } label: {
                Label("About", systemImage: "info.circle")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.plain)
            .help("关于")

            Spacer(minLength: 8)

            HStack(spacing: 10) {
                Label("账号 \(accountCount)", systemImage: "person.2")
                Label("积分 \(totalBonus)", systemImage: "star.fill")
                Label("停车券 \(totalVouchers)", systemImage: "ticket")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Rectangle()
                .fill(Color(NSColor.windowBackgroundColor))
        )
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color(NSColor.separatorColor).opacity(0.6)),
            alignment: .top
        )
    }
}
