// Purpose: Main window sizing and constraints for the macOS app.
// Author: Achord <achordchan@gmail.com>
import SwiftUI
import AppKit

final class MainWindowDelegate: NSObject, NSWindowDelegate {
    static let shared = MainWindowDelegate()

    var fixedWidth: CGFloat = 1020
    var minHeight: CGFloat = 620
    var maxHeight: CGFloat = 1000

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        let clampedHeight = min(max(frameSize.height, minHeight), maxHeight)
        return NSSize(width: fixedWidth, height: clampedHeight)
    }
}

// 添加一个WindowSetupModifier以控制窗口设置
struct WindowSetupModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(width: 1020)
            .onAppear {
                setupMainWindow()
            }
    }

    private func setupMainWindow() {
        // 设置窗口位置和大小
        DispatchQueue.main.async {
            let window = NSApplication.shared.keyWindow
                ?? NSApplication.shared.mainWindow
                ?? NSApplication.shared.windows.first(where: { $0.isVisible })
                ?? NSApplication.shared.windows.first
            if let window {
                // 获取屏幕尺寸
                guard let screen = NSScreen.main else { return }
                let screenRect = screen.frame

                let fixedWidth: CGFloat = 1020
                let maxHeight = min(screenRect.height * 0.85, 1000)
                let minHeight: CGFloat = 620

                // 尽量按当前账号数量计算启动高度（账号少就完整显示，账号多就到上限并滚动）
                let accountsCount: Int
                if let data = UserDefaults.standard.data(forKey: "savedAccounts"),
                   let accounts = try? JSONDecoder().decode([AccountInfo].self, from: data) {
                    accountsCount = accounts.count
                } else {
                    accountsCount = 0
                }

                let columns = 3
                let rows = max(1, Int(ceil(Double(accountsCount) / Double(columns))))
                let estimatedCardHeight: CGFloat = 240
                let verticalSpacing: CGFloat = 12
                let verticalPadding: CGFloat = 16 * 2
                let chromeHeight: CGFloat = 180
                let estimatedHeight = chromeHeight
                    + verticalPadding
                    + CGFloat(rows) * estimatedCardHeight
                    + CGFloat(max(0, rows - 1)) * verticalSpacing
                let preferredHeight = min(max(minHeight, estimatedHeight), maxHeight)

                // 固定窗口宽度，只允许调整高度（防止布局变形）
                window.minSize = NSSize(width: fixedWidth, height: minHeight)
                window.maxSize = NSSize(width: fixedWidth, height: maxHeight)

                MainWindowDelegate.shared.fixedWidth = fixedWidth
                MainWindowDelegate.shared.minHeight = minHeight
                MainWindowDelegate.shared.maxHeight = maxHeight
                window.delegate = MainWindowDelegate.shared

                // 计算窗口大小（宽度固定，高度保持当前）
                let windowWidth = fixedWidth
                let windowHeight = preferredHeight

                // 计算居中位置
                let x = (screenRect.width - windowWidth) / 2
                let y = (screenRect.height - windowHeight) / 2

                // 设置窗口位置和大小
                window.setFrame(NSRect(x: x, y: y, width: windowWidth, height: windowHeight), display: true)
            }
        }
    }
}

// 扩展View以应用修饰符
extension View {
    func setupMainWindow() -> some View {
        self.modifier(WindowSetupModifier())
    }
}
