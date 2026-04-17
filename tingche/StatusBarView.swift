// Purpose: Bottom status bar showing totals and About entry.
// Author: Achord <achordchan@gmail.com>
import SwiftUI

struct StatusBarView: View {
    let sectionTitle: String
    let accountCount: Int
    let totalBonus: Int
    let totalVouchers: Int
    let onAbout: () -> Void
    @ObservedObject var accountManager: AccountManager

    private var autoCheckinProgressValue: Double {
        guard accountManager.autoCheckinProgressTotal > 0 else { return 0 }
        return Double(accountManager.autoCheckinProgressCurrent) / Double(accountManager.autoCheckinProgressTotal)
    }

    var body: some View {
        VStack(spacing: 6) {
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
                    Label("\(sectionTitle) \(accountCount)", systemImage: "person.2")
                    Label("积分 \(totalBonus)", systemImage: "star.fill")
                    Label("停车券 \(totalVouchers)", systemImage: "ticket")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }

            if accountManager.isAutoCheckinRunning {
                HStack(spacing: 8) {
                    Text(accountManager.autoCheckinProgressText)
                        .font(.caption2)
                        .fontWeight(.semibold)

                    if let username = accountManager.autoCheckinCurrentAccountUsername, !username.isEmpty {
                        Text(username)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    ProgressView(value: autoCheckinProgressValue)
                        .controlSize(.small)
                        .progressViewStyle(.linear)
                        .frame(width: 120)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
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
