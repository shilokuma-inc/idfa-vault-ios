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
        WindowGroup {
            RootView()
                .environment(model)
        }
        .onChange(of: scenePhase) { _, phase in
            model.scenePhaseChanged(phase)
        }
    }
}
