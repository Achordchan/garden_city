// Purpose: App entry point defining scenes and windows.
// Author: Achord <achordchan@gmail.com>
//
//  tingcheApp.swift
//  tingche
//
//  Created by A chord on 2025/2/19.
//

import SwiftUI

@main
struct tingcheApp: App {
    @NSApplicationDelegateAdaptor(AppMenuLocalizer.self) private var appMenuLocalizer

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            AppMenuCommands()
        }

        Window("关于", id: "about") {
            AboutView()
        }
        .defaultSize(width: 720, height: 540)
        .windowResizability(.contentSize)

        Window("日志", id: "logs") {
            LogsView()
        }
        .defaultSize(width: 920, height: 680)

        Window("获取账号（Beta）", id: "beta-account") {
            BetaAccountWindowView()
        }
        .defaultSize(width: 920, height: 760)
    }
}
