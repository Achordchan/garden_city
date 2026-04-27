// Purpose: About window UI showing author and project links.
// Author: Achord <achordchan@gmail.com>
import AppKit
import SwiftUI

struct AboutView: View {
    private let avatarURL = URL(string: "https://avatars.githubusercontent.com/u/179492542?v=4")

    var body: some View {
        ZStack {
            AboutBackgroundView()

            VStack(spacing: 14) {
                heroSection
                contactCard
                actionLinks
                noticeCard
            }
            .padding(.horizontal, 54)
            .padding(.top, 22)
            .padding(.bottom, 20)
        }
        .frame(width: 760, height: 540)
        .preferredColorScheme(.light)
    }

    private var heroSection: some View {
        VStack(spacing: 8) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 126, height: 126)
                .shadow(color: .blue.opacity(0.22), radius: 18, x: 0, y: 10)
                .shadow(color: .black.opacity(0.16), radius: 12, x: 0, y: 7)

            VStack(spacing: 4) {
                Text("Achord")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.teal.opacity(0.65))

                    Text("花园城停车助手")
                        .font(.system(size: 17, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(.secondary)

                    Image(systemName: "leaf.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.teal.opacity(0.65))
                        .scaleEffect(x: -1, y: 1)
                }
            }
        }
    }

    private var contactCard: some View {
        VStack(spacing: 0) {
            AboutInfoRow(icon: .avatar(avatarURL), title: "作者：", value: "Achord")
            Divider().padding(.leading, 56)
            AboutInfoRow(icon: .symbol("phone.fill"), title: "Tel：", value: "13160235855")
            Divider().padding(.leading, 56)
            AboutInfoRow(icon: .symbol("envelope.fill"), title: "Email：", value: "achordchan@gmail.com", isLink: true)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.72), lineWidth: 1)
        }
        .shadow(color: .blue.opacity(0.08), radius: 16, x: 0, y: 10)
    }

    private var actionLinks: some View {
        HStack(spacing: 14) {
            AboutLinkButton(title: "项目地址", systemImage: "link", url: "https://github.com/achordchan/garden_city")
            AboutLinkButton(title: "隐私条款", systemImage: "hand.raised.fill", url: "https://github.com/achordchan/garden_city")
            AboutLinkButton(title: "开源协议", systemImage: "doc.text.fill", url: "https://github.com/achordchan/garden_city")
            AboutLinkButton(title: "赞助我", systemImage: "heart.fill", url: "https://ifdian.net/a/achord")
        }
    }

    private var noticeCard: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "info")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(LinearGradient(colors: [.blue.opacity(0.58), .indigo.opacity(0.34)], startPoint: .topLeading, endPoint: .bottomTrailing))
                )

            Text("故事起源在22年底，我来到这家外贸公司工作。本工具目的是为了统一管理花园城停车号码的管理，稍微加了一点更改响应和基础的兑换停车功能，除此之外未进行任何逆向破解，仅供学习，请24小时内删除。")
                .font(.system(size: 13, weight: .regular))
                .lineSpacing(3)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.78), lineWidth: 1)
        }
        .shadow(color: .blue.opacity(0.08), radius: 14, x: 0, y: 8)
    }
}

private struct AboutInfoRow: View {
    enum Icon {
        case symbol(String)
        case avatar(URL?)
    }

    let icon: Icon
    let title: String
    let value: String
    var isLink = false

    var body: some View {
        HStack(spacing: 14) {
            iconView
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.blue.opacity(0.10))
                )

            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 62, alignment: .leading)

            Text(value)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isLink ? Color.blue : Color.primary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 5)
    }

    @ViewBuilder
    private var iconView: some View {
        switch icon {
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.blue)
        case .avatar(let url):
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFill()
                } else if phase.error != nil {
                    Image(systemName: "person.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.blue)
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .frame(width: 28, height: 28)
            .clipShape(Circle())
            .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 1.5))
        }
    }
}

private struct AboutLinkButton: View {
    let title: String
    let systemImage: String
    let url: String

    var body: some View {
        Link(destination: URL(string: url)!) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .labelStyle(.titleAndIcon)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(.white.opacity(0.82), lineWidth: 1)
                }
                .shadow(color: .blue.opacity(0.10), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}

private struct AboutBackgroundView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.98, blue: 1.0),
                    Color(red: 0.90, green: 0.95, blue: 1.0),
                    Color.white
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(colors: [.blue.opacity(0.18), .clear], center: .top, startRadius: 20, endRadius: 320)
                .blur(radius: 8)

            GeometryReader { proxy in
                let size = proxy.size

                Path { path in
                    path.move(to: CGPoint(x: 0, y: size.height * 0.55))
                    path.addCurve(
                        to: CGPoint(x: size.width, y: size.height * 0.44),
                        control1: CGPoint(x: size.width * 0.28, y: size.height * 0.48),
                        control2: CGPoint(x: size.width * 0.60, y: size.height * 0.22)
                    )
                    path.addLine(to: CGPoint(x: size.width, y: size.height))
                    path.addLine(to: CGPoint(x: 0, y: size.height))
                    path.closeSubpath()
                }
                .fill(Color.white.opacity(0.42))

                ParkingSign()
                    .stroke(Color.blue.opacity(0.12), lineWidth: 5)
                    .frame(width: 76, height: 110)
                    .position(x: size.width * 0.22, y: size.height * 0.38)

                CarShape()
                    .fill(Color.blue.opacity(0.055))
                    .frame(width: 165, height: 72)
                    .position(x: size.width * 0.78, y: size.height * 0.47)

                LeafShape()
                    .fill(Color.teal.opacity(0.18))
                    .frame(width: 150, height: 90)
                    .rotationEffect(.degrees(-24))
                    .position(x: size.width * 0.09, y: size.height * 0.56)

                LeafShape()
                    .fill(Color.teal.opacity(0.22))
                    .frame(width: 58, height: 34)
                    .rotationEffect(.degrees(-28))
                    .position(x: size.width * 0.88, y: size.height * 0.39)

                LeafShape()
                    .fill(Color.teal.opacity(0.20))
                    .frame(width: 48, height: 28)
                    .rotationEffect(.degrees(-16))
                    .position(x: size.width * 0.78, y: size.height * 0.17)
            }
            .blur(radius: 0.2)
        }
        .ignoresSafeArea()
    }
}

private struct ParkingSign: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let sign = CGRect(x: rect.minX + rect.width * 0.12, y: rect.minY, width: rect.width * 0.76, height: rect.width * 0.76)
        path.addRoundedRect(in: sign, cornerSize: CGSize(width: 8, height: 8))
        path.move(to: CGPoint(x: sign.midX, y: sign.maxY))
        path.addLine(to: CGPoint(x: sign.midX, y: rect.maxY))
        path.move(to: CGPoint(x: sign.midX - 12, y: rect.maxY))
        path.addLine(to: CGPoint(x: sign.midX + 12, y: rect.maxY))
        return path
    }
}

private struct CarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.midY))
        path.addCurve(to: CGPoint(x: rect.minX + rect.width * 0.35, y: rect.minY + rect.height * 0.18), control1: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.minY + rect.height * 0.28), control2: CGPoint(x: rect.minX + rect.width * 0.26, y: rect.minY + rect.height * 0.18))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.66, y: rect.minY + rect.height * 0.18))
        path.addCurve(to: CGPoint(x: rect.minX + rect.width * 0.88, y: rect.midY), control1: CGPoint(x: rect.minX + rect.width * 0.76, y: rect.minY + rect.height * 0.18), control2: CGPoint(x: rect.minX + rect.width * 0.82, y: rect.minY + rect.height * 0.30))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY + rect.height * 0.20))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY + rect.height * 0.20))
        path.closeSubpath()
        path.addEllipse(in: CGRect(x: rect.minX + rect.width * 0.22, y: rect.midY + rect.height * 0.06, width: rect.height * 0.28, height: rect.height * 0.28))
        path.addEllipse(in: CGRect(x: rect.minX + rect.width * 0.68, y: rect.midY + rect.height * 0.06, width: rect.height * 0.28, height: rect.height * 0.28))
        return path
    }
}

private struct LeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control1: CGPoint(x: rect.width * 0.32, y: rect.minY), control2: CGPoint(x: rect.width * 0.72, y: rect.minY))
        path.addCurve(to: CGPoint(x: rect.minX, y: rect.midY), control1: CGPoint(x: rect.width * 0.74, y: rect.maxY), control2: CGPoint(x: rect.width * 0.30, y: rect.maxY))
        return path
    }
}
