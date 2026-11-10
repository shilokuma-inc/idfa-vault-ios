//
//  Authenticator.swift
//  IDFAVault
//
//  本人確認（LocalAuthentication）。ポリシーは .deviceOwnerAuthentication で、パスコード / パスワードへの切り替えを許す（仕様書 2）。
//

import LocalAuthentication
#if canImport(UIKit)
import UIKit
#endif

/// 本人確認の結果
enum AuthenticationOutcome: Equatable, Sendable {
    case success
    /// ユーザーやシステムが取り消した
    case cancelled
    /// 認証に失敗した（何度も間違えたなど）
    case failed
    /// 端末にパスコード（パスワード）が設定されていない
    case unavailable
}

/// 本人確認を行うもの。テストとスクリーンショットの撮影では偽物に差し替える
protocol Authenticating {
    /// 端末の生体認証の種類。登録されていなければ .none
    func biometryKind() -> BiometryKind
    /// 本人確認を行う。reason は Touch ID・パスワードのダイアログに出る理由
    func authenticate(reason: String) async -> AuthenticationOutcome
}

/// LAContext で本人確認を行う
struct LocalAuthenticator: Authenticating {
    func biometryKind() -> BiometryKind {
        let context = LAContext()
        var error: NSError?
        let canUseBiometrics = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        // 何度も失敗してロックされているときも、生体認証のある端末として扱う（解除はパスコードに切り替わる）
        let isLockedOut = error.map { LAError.Code(rawValue: $0.code) == .biometryLockout } ?? false
        guard canUseBiometrics || isLockedOut else {
            return .none
        }
        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID(Self.touchIDSensor)
        case .opticID:
            return .opticID
        case .none:
            return .none
        @unknown default:
            return .none
        }
    }

    func authenticate(reason: String) async -> AuthenticationOutcome {
        let context = LAContext()
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) ? .success : .failed
        } catch let error as LAError {
            switch error.code {
            case .userCancel, .appCancel, .systemCancel, .userFallback:
                return .cancelled
            case .passcodeNotSet:
                return .unavailable
            default:
                return .failed
            }
        } catch {
            return .failed
        }
    }

    /// Touch ID のセンサーの場所。iPhone はすべてホームボタン、iPad はホームボタンの有無（画面下の安全領域）で見分ける
    private static var touchIDSensor: BiometryKind.TouchIDSensor {
        #if os(macOS)
        return .mac
        #elseif os(iOS)
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            return .homeButton
        }
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
        return (window?.safeAreaInsets.bottom ?? 0) > 0 ? .topButton : .homeButton
        #else
        return .homeButton
        #endif
    }
}
