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
    var body: some Scene {
        WindowGroup {
            ContentView()
                .navigationTitle("花园城停车助手 v3.0 全新出发")  // 设置窗口标题
        }

        Window("About", id: "about") {
            AboutView()
        }
        .defaultSize(width: 720, height: 540)
        .windowResizability(.contentSize)

        Window("Logs", id: "logs") {
            LogsView()
        }
        .defaultSize(width: 920, height: 680)
    }
}
