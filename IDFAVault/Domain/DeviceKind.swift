//
//  DeviceKind.swift
//  IDFAVault
//
//  端末の種類（iPhone・iPad・Mac・Apple Vision Pro）。インゴットの刻印やアイコンに使う。
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum DeviceKind: String, Sendable, CaseIterable {
    case iPhone
    case iPad
    case mac
    case vision

    /// この端末の種類
    static var current: DeviceKind {
        #if os(macOS)
        .mac
        #elseif os(visionOS)
        .vision
        #else
        UIDevice.current.userInterfaceIdiom == .pad ? .iPad : .iPhone
        #endif
    }

    /// インゴットに刻む大文字の名前（IDFA · IPHONE など）
    var engravedName: String {
        switch self {
        case .iPhone:
            "IPHONE"
        case .iPad:
            "IPAD"
        case .mac:
            "MAC"
        case .vision:
            "VISION PRO"
        }
    }

    /// アイコン（SF Symbol）
    var symbolName: String {
        switch self {
        case .iPhone:
            "iphone"
        case .iPad:
            "ipad.landscape"
        case .mac:
            "laptopcomputer"
        case .vision:
            "visionpro"
        }
    }
}
