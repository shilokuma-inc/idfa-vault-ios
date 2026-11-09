//
//  MacSupport.swift
//  IDFAVault
//
//  macOS だけの部品（仕様書 3.3・3.5・4 章）。
//  ⌘C で表示中の IDFA をコピーするメニュー、画面収録からウインドウを外す設定、設定のウインドウ、ロックのきっかけ。
//

#if os(macOS)
import AppKit
import SwiftUI

/// メニューの「コピー」（⌘C）を、メインのウインドウで選んでいる端末の IDFA のコピーにする。
/// このアプリには文字を入力する欄が無いので、標準のカット・コピー・ペーストの代わりにする
struct IdentifierCommands: Commands {
    var model: AppModel
    @FocusedValue(\.copyableIdentifier) private var identifier

    var body: some Commands {
        CommandGroup(replacing: .pasteboard) {
            Button {
                if let identifier {
                    model.copy(identifier)
                }
            } label: {
                Text("Copy IDFA")
            }
            .keyboardShortcut("c", modifiers: .command)
            .disabled(identifier == nil || model.isLocked)
        }
    }
}

extension View {
    /// Mac のウインドウの設定。「画面収録・ミラーリング中は隠す」がオンなら、画面収録とスクリーンショットからウインドウを外す。
    /// アプリが非アクティブになったら（ほかのアプリに切り替えたら）、iOS のバックグラウンドと同じに扱う
    /// アクティブの変化はメインのウインドウ（observesActivation）だけで受け取る（設定・メニューバーの窓で二重に受けない）
    func macWindowBehavior(model: AppModel, observesActivation: Bool = true) -> some View {
        background {
            WindowSharingConfigurator(excludesFromCapture: model.settings.hidesWhileCapturing)
                .frame(width: 0, height: 0)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            if observesActivation {
                model.scenePhaseChanged(.background)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            if observesActivation {
                model.scenePhaseChanged(.active)
            }
        }
    }
}

/// ウインドウの sharingType を切り替える、見えない NSView
private struct WindowSharingConfigurator: NSViewRepresentable {
    var excludesFromCapture: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { apply(to: view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { apply(to: nsView.window) }
    }

    private func apply(to window: NSWindow?) {
        window?.sharingType = excludesFromCapture ? .none : .readOnly
    }
}

/// 設定のウインドウ（⌘,）。ロック中は項目を出さない
struct MacSettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if model.isLocked {
                VStack(spacing: 12) {
                    Image(systemName: "lock")
                        .font(.system(size: 28, weight: .semibold))
                        .identifierMetal()
                    Text("Unlock IDFA Vault to change settings.")
                        .font(.callout)
                        .foregroundStyle(HeatTint.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    SettingsForm()
                        .padding(24)
                }
            }
        }
        .frame(width: 480, height: 600)
        .background(HeatTintBackground())
        .foregroundStyle(HeatTint.text)
        .preferredColorScheme(.dark)
        .macWindowBehavior(model: model, observesActivation: false)
    }
}
#endif
