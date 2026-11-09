//
//  RootView.swift
//  IDFAVault
//
//  ロック中はロック画面、解除したらメインの画面を出す。
//  アプリスイッチャーのスナップショットと画面収録には、内容を隠した画面を重ねる（仕様書 3.1・3.5）。
//

import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            HeatTintBackground()
            Group {
                if model.isLocked {
                    LockView()
                } else {
                    MainView()
                }
            }
            .transition(.opacity)

            // スナップショットに間に合うよう、目隠しはアニメーションさせずにすぐ重ねる
            if model.showsPrivacyCover {
                PrivacyCover(isCapturing: model.isCapturingScreen && model.isInForeground)
                    .transition(.identity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.isLocked)
        .foregroundStyle(HeatTint.text)
        .tint(HeatTint.link)
        .preferredColorScheme(.dark)
        .sceneCaptureObserver { isCapturing in
            model.isCapturingScreen = isCapturing
        }
        #if os(macOS)
        .macWindowBehavior(model: model)
        .onAppear {
            // 起動したときの「アクティブになった」通知は、画面ができる前に届いて受け取れないことがある
            if NSApplication.shared.isActive {
                model.scenePhaseChanged(.active)
            }
        }
        .toolbar {
            if !model.isLocked {
                MacToolbar()
            }
        }
        .frame(minWidth: 860, minHeight: 560)
        #else
        .onAppear {
            // 起動したときの active は App の onChange に届かないことがあるので、ここでも渡す
            model.scenePhaseChanged(scenePhase)
        }
        #endif
    }
}

/// ロックを解除したあとの画面。端末ごとのレイアウトはここで切り替える（iPhone の画面を引き伸ばさない）
struct MainView: View {
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    var body: some View {
        #if os(macOS)
        DeviceBrowserView()
        #elseif os(iOS)
        // iPad でも、Split View などで幅が狭いときは iPhone のレイアウトにする
        if UIDevice.current.userInterfaceIdiom == .pad, horizontalSizeClass == .regular {
            DeviceBrowserView()
        } else {
            PhoneHomeView()
        }
        #else
        PhoneHomeView()
        #endif
    }
}

#if os(macOS)
/// Mac のツールバーのロック・設定（デザインの MacMain）
private struct MacToolbar: ToolbarContent {
    @Environment(AppModel.self) private var model
    @Environment(\.openSettings) private var openSettings

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                model.lockNow()
            } label: {
                Label("Lock Now", systemImage: "lock")
            }
            .help(Text("Lock Now"))
            Button {
                openSettings()
            } label: {
                Label("Settings", systemImage: "slider.horizontal.3")
            }
            .help(Text("Settings"))
        }
    }
}
#endif

/// 内容を隠した画面。アプリスイッチャーのスナップショットと、画面収録・ミラーリング中に重ねる
struct PrivacyCover: View {
    /// 画面収録・ミラーリング中か（そうでなければ、バックグラウンドに移るところ）
    var isCapturing: Bool

    var body: some View {
        ZStack {
            HeatTintBackground()
            VStack(spacing: 14) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .identifierMetal()
                Text(verbatim: "IDFA Vault")
                    .font(.system(size: 28, weight: .heavy))
                    .tracking(1.1)
                    .headingMetal()
                if isCapturing {
                    Text("Hidden during screen recording or mirroring")
                        .font(.subheadline)
                        .foregroundStyle(HeatTint.secondaryText)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(24)
        }
        .accessibilityElement(children: .combine)
    }
}
