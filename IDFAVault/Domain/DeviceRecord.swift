//
//  DeviceRecord.swift
//  IDFAVault
//
//  同じ Apple ID の端末ごとの IDFA（仕様書 5 章の DeviceIDFA）。CloudKit のプライベートデータベースに 1 端末 1 レコードで置く。
//

import Foundation

/// 端末のプラットフォーム。レコードの platform にこの rawValue を書く
enum DevicePlatform: String, Sendable, CaseIterable {
    case iOS
    case iPadOS
    case macOS
    case visionOS

    /// この端末のプラットフォーム
    static var current: DevicePlatform {
        switch DeviceKind.current {
        case .iPhone:
            .iOS
        case .iPad:
            .iPadOS
        case .mac:
            .macOS
        case .vision:
            .visionOS
        }
    }

    /// アプリが自分の IDFA を取れるプラットフォームか（iPhone・iPad だけ。Mac・visionOS は取れない）。
    /// 一覧には取れるプラットフォームのレコードだけを出す
    var providesAdvertisingIdentifier: Bool {
        switch self {
        case .iOS, .iPadOS:
            true
        case .macOS, .visionOS:
            false
        }
    }

    /// 端末の種類（アイコンに使う）
    var kind: DeviceKind {
        switch self {
        case .iOS:
            .iPhone
        case .iPadOS:
            .iPad
        case .macOS:
            .mac
        case .visionOS:
            .vision
        }
    }
}

struct DeviceRecord: Identifiable, Hashable, Sendable {
    /// アプリが作って Keychain に保存した端末の UUID（レコード名にも使う）
    let id: String
    /// 表示名。iOS はモデル名（個人名が入らないよう、UIDevice の name は使わない）。Mac・visionOS はレコードを書かない
    var name: String
    var platform: DevicePlatform
    /// IDFA。トラッキングが許可されていない・全桁 0 のときは nil（全桁 0 は同期しない。仕様書 3.2）
    var identifier: AdvertisingIdentifier?
    var trackingStatus: TrackingStatus
    var updatedAt: Date
}
