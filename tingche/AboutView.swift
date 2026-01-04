// Purpose: About window UI showing author and project links.
// Author: Achord <achordchan@gmail.com>
import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.accentColor.opacity(0.65),
                                    Color.accentColor.opacity(0.12)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 108, height: 108)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.55), lineWidth: 2)
                        )

                    AsyncImage(url: URL(string: "https://avatars.githubusercontent.com/u/179492542?v=4")) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .scaledToFill()
                        } else if phase.error != nil {
                            Image(systemName: "person.fill")
                                .font(.system(size: 42, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
                        } else {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                    .frame(width: 92, height: 92)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.9), lineWidth: 3)
                    )
                    .shadow(color: Color.black.opacity(0.18), radius: 14, x: 0, y: 10)
                }

                VStack(spacing: 6) {
                    Text("Achord")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("花园城停车助手")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.fill")
                        .foregroundColor(.accentColor)
                        .frame(width: 22)
                    Text("作者：Achord")
                        .foregroundColor(.primary)
                    Spacer()
                }

                HStack(spacing: 10) {
                    Image(systemName: "phone.fill")
                        .foregroundColor(.accentColor)
                        .frame(width: 22)
                    Text("Tel：13160235855")
                        .foregroundColor(.primary)
                    Spacer()
                }

                HStack(spacing: 10) {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(.accentColor)
                        .frame(width: 22)
                    Text("Email：achordchan@gmail.com")
                        .foregroundColor(.primary)
                    Spacer()
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.regularMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )

            HStack(spacing: 10) {
                Link(destination: URL(string: "https://github.com/achordchan/garden_city")!) {
                    Label("项目地址", systemImage: "link")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Link(destination: URL(string: "https://github.com/achordchan/garden_city")!) {
                    Label("隐私条款", systemImage: "hand.raised.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Link(destination: URL(string: "https://github.com/achordchan/garden_city")!) {
                    Label("开源协议", systemImage: "doc.text.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Link(destination: URL(string: "https://ifdian.net/a/achord")!) {
                    Label("赞助我", systemImage: "heart.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .labelStyle(.titleAndIcon)
            .controlSize(.regular)

            Text("故事起源在22年底，我来到这家外贸公司工作\n本工具目的是为了统一管理花园城停车号码的管理，稍微加了一点更改响应和基础的兑换停车功能，除此之外未进行任何逆向破解，仅供学习，请24小时内删除。")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
                .padding(.horizontal, 12)
                .padding(.top, 2)
        }
        .padding(22)
        .frame(minWidth: 520, idealWidth: 640, maxWidth: 760, minHeight: 420, idealHeight: 460, maxHeight: 520)
        .background(
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.10),
                    Color.accentColor.opacity(0.03),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}
