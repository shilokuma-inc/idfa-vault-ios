//
//  TrackingProvider.swift
//  IDFAVault
//
//  トラッキングの許可（AppTrackingTransparency）と IDFA の取得（AdSupport）。
//  IDFA は画面に出すことと、ユーザー自身の iCloud に保存することにだけ使う。広告の配信やトラッキングには使わない。
//  visionOS の SDK には AdSupport が無く、visionOS のアプリは IDFA を取得できない（iPad の互換アプリ用にしか無い）。
//

#if canImport(AdSupport)
import AdSupport
#endif
import AppTrackingTransparency

/// トラッキングの許可状態と IDFA を返すもの。テストとスクリーンショットの撮影では偽物に差し替える
protocol TrackingProviding {
    /// このプラットフォームでアプリが IDFA を取得できるか（visionOS はできない）
    var supportsAdvertisingIdentifier: Bool { get }
    /// 今の許可状態
    func currentStatus() -> TrackingStatus
    /// 許可のダイアログを出し、結果の許可状態を返す（決まっていれば出さずに今の状態を返す）
    func requestAuthorization() async -> TrackingStatus
    /// この端末の IDFA。許可されていなければ全桁 0
    func advertisingIdentifier() -> AdvertisingIdentifier
}

struct SystemTrackingProvider: TrackingProviding {
    var supportsAdvertisingIdentifier: Bool {
        #if canImport(AdSupport)
        true
        #else
        false
        #endif
    }

    func currentStatus() -> TrackingStatus {
        TrackingStatus(ATTrackingManager.trackingAuthorizationStatus)
    }

    func requestAuthorization() async -> TrackingStatus {
        TrackingStatus(await ATTrackingManager.requestTrackingAuthorization())
    }

    func advertisingIdentifier() -> AdvertisingIdentifier {
        #if canImport(AdSupport)
        AdvertisingIdentifier(uuid: ASIdentifierManager.shared().advertisingIdentifier)
        #else
        .zero
        #endif
    }
}

extension TrackingStatus {
    init(_ status: ATTrackingManager.AuthorizationStatus) {
        switch status {
        case .authorized:
            self = .authorized
        case .denied:
            self = .denied
        case .restricted:
            self = .restricted
        case .notDetermined:
            self = .notDetermined
        @unknown default:
            self = .notDetermined
        }
    }
}
