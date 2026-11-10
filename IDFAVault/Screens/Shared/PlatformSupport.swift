//
//  PlatformSupport.swift
//  IDFAVault
//
//  プラットフォームで書き方が違うものをまとめる（画面収録の検知・ナビゲーションバー・設定アプリを開く URL）。
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension View {
    /// 画面収録・ミラーリングの状態が変わったら知らせる。iOS・visionOS は sceneCaptureState（iOS 17+）で見る。
    /// Mac は検知の API が無いので、ウインドウをキャプチャの対象から外す側で対応する
    func sceneCaptureObserver(_ onChange: @escaping (Bool) -> Void) -> some View {
        #if canImport(UIKit)
        background {
            SceneCaptureReader(onChange: onChange)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
        #else
        self
        #endif
    }

    /// システムのナビゲーションバーを隠す（見出しと戻るボタンは画面の中に面取りで描く）
    @ViewBuilder
    func hidesNavigationBar() -> some View {
        #if os(iOS) || os(visionOS)
        toolbar(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }
}

#if canImport(UIKit)
/// ウインドウのシーンの sceneCaptureState を読む、見えない UIView
private struct SceneCaptureReader: UIViewRepresentable {
    var onChange: (Bool) -> Void

    func makeUIView(context: Context) -> CaptureStateView {
        let view = CaptureStateView()
        view.onChange = onChange
        return view
    }

    func updateUIView(_ uiView: CaptureStateView, context: Context) {
        uiView.onChange = onChange
    }

    final class CaptureStateView: UIView {
        var onChange: ((Bool) -> Void)?
        private var lastReported: Bool?

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            registerForTraitChanges([UITraitSceneCaptureState.self]) { (view: Self, _: UITraitCollection) in
                view.report()
            }
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            report()
        }

        private func report() {
            let isCapturing = traitCollection.sceneCaptureState == .active
            guard isCapturing != lastReported else {
                return
            }
            lastReported = isCapturing
            onChange?(isCapturing)
        }
    }
}
#endif

enum SystemSettings {
    /// このアプリの設定（トラッキングの許可）を開く URL。macOS のシステム設定にはトラッキングの項目が無いので nil
    static var appSettingsURL: URL? {
        #if canImport(UIKit)
        URL(string: UIApplication.openSettingsURLString)
        #else
        nil
        #endif
    }
}
