//
//  TrackingStatus.swift
//  IDFAVault
//
//  App Tracking Transparency の許可状態（仕様書 3.2）。CloudKit のレコードの attStatus にも同じ文字列を書く。
//

import SwiftUI

enum TrackingStatus: String, Sendable, CaseIterable {
    case authorized
    case denied
    case restricted
    case notDetermined

    /// IDFA を取得できる状態か
    var allowsIdentifier: Bool {
        self == .authorized
    }

    /// 許可されていない（ユーザーが拒否した・制限されている）か
    var isRefused: Bool {
        self == .denied || self == .restricted
    }

    /// バッジの文言
    var badgeTitle: LocalizedStringResource {
        switch self {
        case .authorized:
            "Tracking Allowed"
        case .denied, .restricted:
            "Not Allowed"
        case .notDetermined:
            "Not Requested"
        }
    }

    /// バッジの色
    var badgeColor: Color {
        switch self {
        case .authorized:
            HeatTint.allowed
        case .denied, .restricted:
            HeatTint.warningLight
        case .notDetermined:
            HeatTint.sectionHeader
        }
    }
}
