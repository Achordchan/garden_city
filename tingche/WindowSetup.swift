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
            .background(
                MainWindowChromeBridge()
                .frame(width: 0, height: 0)
            )
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

private struct MainWindowChromeBridge: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> BridgeView {
        let view = BridgeView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: BridgeView, context: Context) {
        context.coordinator.attachIfNeeded(to: nsView.window)
    }

    final class Coordinator: NSObject {
        weak var window: NSWindow?
        private var toolbarContextMenuMonitor: Any?
        private var windowObserver: NSObjectProtocol?

        deinit {
            if let toolbarContextMenuMonitor {
                NSEvent.removeMonitor(toolbarContextMenuMonitor)
            }
            if let windowObserver {
                NotificationCenter.default.removeObserver(windowObserver)
            }
        }

        func attachIfNeeded(to newWindow: NSWindow?) {
            guard let newWindow else { return }
            guard window !== newWindow else { return }

            if let toolbarContextMenuMonitor {
                NSEvent.removeMonitor(toolbarContextMenuMonitor)
                self.toolbarContextMenuMonitor = nil
            }
            if let windowObserver {
                NotificationCenter.default.removeObserver(windowObserver)
                self.windowObserver = nil
            }

            window = newWindow
            configureWindow(newWindow)
            installToolbarContextMenuBlocker(on: newWindow)
        }

        private func configureWindow(_ window: NSWindow) {
            window.toolbar?.allowsUserCustomization = false
            window.toolbar?.autosavesConfiguration = false
            window.toolbarStyle = .unified
            window.titleVisibility = .visible
            window.titlebarAppearsTransparent = false
        }

        private func installToolbarContextMenuBlocker(on window: NSWindow) {
            toolbarContextMenuMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.rightMouseDown, .leftMouseDown]
            ) { [weak self, weak window] event in
                guard let self, let window, event.window === window else {
                    return event
                }

                guard self.shouldBlockToolbarContextMenu(for: event, in: window) else {
                    return event
                }

                return nil
            }

            windowObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                if let toolbarContextMenuMonitor {
                    NSEvent.removeMonitor(toolbarContextMenuMonitor)
                    self.toolbarContextMenuMonitor = nil
                }
            }
        }

        private func shouldBlockToolbarContextMenu(for event: NSEvent, in window: NSWindow) -> Bool {
            let isRightClick = event.type == .rightMouseDown
            let isControlLeftClick = event.type == .leftMouseDown && event.modifierFlags.contains(.control)

            guard isRightClick || isControlLeftClick else {
                return false
            }

            let location = event.locationInWindow
            let toolbarThreshold = window.contentLayoutRect.maxY
            guard location.y >= toolbarThreshold else {
                return false
            }

            if let titlebarView = window.contentView?.superview {
                let pointInTitlebar = titlebarView.convert(location, from: nil)
                let hitView = titlebarView.hitTest(pointInTitlebar)
                if hitView?.hasAncestor(of: NSSearchField.self) == true {
                    return false
                }
            }

            return true
        }
    }

    final class BridgeView: NSView {
        weak var coordinator: Coordinator?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            coordinator?.attachIfNeeded(to: window)
        }
    }
}

private extension NSView {
    func hasAncestor(of type: NSView.Type) -> Bool {
        var current: NSView? = self
        while let view = current {
            if view.isKind(of: type) {
                return true
            }
            current = view.superview
        }
        return false
    }
}
