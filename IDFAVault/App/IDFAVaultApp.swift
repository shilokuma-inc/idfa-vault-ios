//
//  IDFAVaultApp.swift
//  IDFAVault
//
//  Created by 村石 拓海 on 2024/05/12.
//

import SwiftUI

@main
struct IDFAVaultApp: App {
    @State private var model = AppModel(dependencies: .resolve())
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        #if os(macOS)
        // Mac はウインドウを 1 つにする（メニューバーの「ウインドウを開く」で開き直す）
        Window(Text(verbatim: "IDFA Vault"), id: MenuBarContent.mainWindowID) {
            RootView()
                .environment(model)
        }
        .defaultSize(width: 1180, height: 740)
        .commands {
            IdentifierCommands(model: model)
        }

        Settings {
            MacSettingsView()
                .environment(model)
        }

        MenuBarExtra {
            MenuBarContent()
                .environment(model)
        } label: {
            Image(systemName: "lock.shield")
                .accessibilityLabel(Text(verbatim: "IDFA Vault"))
        }
        .menuBarExtraStyle(.window)
        #else
        WindowGroup {
            RootView()
                .environment(model)
        }
        .onChange(of: scenePhase) { _, phase in
            model.scenePhaseChanged(phase)
        }
        #endif
    }
}
