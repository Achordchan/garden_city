import SwiftUI
import AppKit

extension Notification.Name {
    static let openSettingsFromMenu = Notification.Name("openSettingsFromMenu")
}

struct AppMenuCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("关于花园城停车助手") {
                openWindow(id: "about")
            }
        }

        CommandGroup(replacing: .appSettings) {
            Button("设置…") {
                NotificationCenter.default.post(name: .openSettingsFromMenu, object: nil)
            }
            .keyboardShortcut(",", modifiers: .command)
        }

        AppMenuCleanupCommands()
        EditingMenuCleanupCommands()
        WindowMenuCleanupCommands()

        CommandMenu("工具") {
            Button("获取账号（Beta）") {
                openWindow(id: "beta-account")
            }

            Button("查看日志") {
                openWindow(id: "logs")
            }
        }
    }
}

private struct AppMenuCleanupCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .systemServices) { }
        CommandGroup(replacing: .newItem) { }
        CommandGroup(replacing: .saveItem) { }
        CommandGroup(replacing: .importExport) { }
        CommandGroup(replacing: .printItem) { }
    }
}

private struct EditingMenuCleanupCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .undoRedo) { }
        CommandGroup(replacing: .pasteboard) { }
        CommandGroup(replacing: .textEditing) { }
        CommandGroup(replacing: .textFormatting) { }
        CommandGroup(replacing: .toolbar) { }
        CommandGroup(replacing: .sidebar) { }
    }
}

private struct WindowMenuCleanupCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .windowArrangement) { }
        CommandGroup(replacing: .windowSize) { }
        CommandGroup(replacing: .windowList) { }
        CommandGroup(replacing: .singleWindowList) { }
    }
}

final class AppMenuLocalizer: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async {
            self.localizeMainMenu()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        localizeMainMenu()
    }

    private func localizeMainMenu() {
        guard let mainMenu = NSApp.mainMenu else { return }

        let topLevelTitles = ["花园城停车助手", "文件", "编辑", "视图", "窗口", "帮助"]
        for (index, title) in topLevelTitles.enumerated() where mainMenu.items.indices.contains(index) {
            mainMenu.items[index].title = title
        }

        mainMenu.items.forEach { item in
            localizeMenu(item.submenu)
        }

        removeUnusedTopLevelMenus(from: mainMenu)
    }

    private func localizeMenu(_ menu: NSMenu?) {
        guard let menu else { return }

        for item in menu.items {
            switch item.action {
            case #selector(NSApplication.hide(_:)):
                item.title = "隐藏花园城停车助手"
            case #selector(NSApplication.hideOtherApplications(_:)):
                item.title = "隐藏其他"
            case #selector(NSApplication.unhideAllApplications(_:)):
                item.title = "显示全部"
            case #selector(NSApplication.terminate(_:)):
                item.title = "退出花园城停车助手"
            default:
                break
            }

            if let submenu = item.submenu {
                localizeMenu(submenu)
            }
        }
    }

    private func removeUnusedTopLevelMenus(from mainMenu: NSMenu) {
        let removableTitles = Set(["编辑", "视图", "窗口"])
        let indexes = mainMenu.items.enumerated()
            .filter { removableTitles.contains($0.element.title) }
            .map(\.offset)
            .sorted(by: >)

        for index in indexes {
            mainMenu.removeItem(at: index)
        }
    }
}
