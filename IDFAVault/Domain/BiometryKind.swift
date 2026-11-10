//
//  BiometryKind.swift
//  IDFAVault
//
//  端末の生体認証の種類と、ロック画面・設定に出すマークと文言（仕様書 3.1）。
//  マークは SF Symbols の公式シンボルを使い、独自に描かない。
//

import Foundation

enum BiometryKind: Hashable, Sendable {
    /// Touch ID のセンサーの場所。補足の文言を切り替える
    enum TouchIDSensor: Hashable, Sendable {
        /// iPhone SE や一部の iPad のホームボタン
        case homeButton
        /// ホームボタンの無い iPad のトップボタン
        case topButton
        /// Mac のキーボードの Touch ID
        case mac
    }

    case faceID
    case touchID(TouchIDSensor)
    case opticID
    /// 生体認証が無い・登録されていない。パスコード（Mac はパスワード）で解除する
    case none

    /// 認証のマーク（SF Symbol）
    var symbolName: String {
        switch self {
        case .faceID:
            "faceid"
        case .touchID:
            "touchid"
        case .opticID:
            "opticid"
        case .none:
            "lock"
        }
    }

    /// 製品名（Face ID など）。生体認証が無いときは nil
    var productName: String? {
        switch self {
        case .faceID:
            "Face ID"
        case .touchID:
            "Touch ID"
        case .opticID:
            "Optic ID"
        case .none:
            nil
        }
    }

    /// 設定の「認証」の表示（製品名か、パスコード / パスワード）
    var methodName: LocalizedStringResource {
        if let productName {
            return "\(productName)"
        }
        return Self.usesPassword ? "Password" : "Passcode"
    }

    /// ロック解除のボタンの文言
    var unlockTitle: LocalizedStringResource {
        if let productName {
            return "Unlock with \(productName)"
        }
        return Self.usesPassword ? "Unlock with Password" : "Unlock with Passcode"
    }

    /// 認証中に出す補足の文言。生体認証が無いときは nil
    var authenticatingMessage: LocalizedStringResource? {
        switch self {
        case .faceID:
            "Verifying with Face ID…"
        case .touchID(.homeButton):
            "Place your finger on the Home button"
        case .touchID(.topButton):
            "Place your finger on the top button"
        case .touchID(.mac):
            "Place your finger on the Touch ID sensor"
        case .opticID:
            "Verifying with Optic ID…"
        case .none:
            nil
        }
    }

    /// 設定の「起動時に（認証方式）を要求」の文言
    var requireAtLaunchTitle: LocalizedStringResource {
        if let productName {
            return "Require \(productName) at Launch"
        }
        return Self.usesPassword ? "Require Password at Launch" : "Require Passcode at Launch"
    }

    /// パスコード（Mac はパスワード）で解除するサブボタンの文言
    static var passcodeButtonTitle: LocalizedStringResource {
        usesPassword ? "Use Password" : "Use Passcode"
    }

    /// 端末のロック解除に「パスワード」を使うプラットフォームか（Mac）。ほかは「パスコード」
    static var usesPassword: Bool {
        #if os(macOS)
        true
        #else
        false
        #endif
    }
}
