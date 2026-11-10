//
//  AppSettings.swift
//  IDFAVault
//
//  設定（仕様書 3.5）。UserDefaults に保存する。「起動時に生体認証を要求」は固定でオンなので保存しない。
//

import Foundation
import Observation

@Observable
final class AppSettings {
    private enum Key {
        static let autoLock = "settings.autoLock"
        static let hidesWhileCapturing = "settings.hidesWhileCapturing"
    }

    /// 自動ロックのタイミング（初期値: すぐに）
    var autoLock: AutoLockTiming {
        didSet { defaults.set(autoLock.rawValue, forKey: Key.autoLock) }
    }

    /// 画面収録・ミラーリング中は隠す（初期値: オン）
    var hidesWhileCapturing: Bool {
        didSet { defaults.set(hidesWhileCapturing, forKey: Key.hidesWhileCapturing) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
        autoLock = defaults.string(forKey: Key.autoLock).flatMap(AutoLockTiming.init(rawValue:)) ?? .immediately
        hidesWhileCapturing = defaults.object(forKey: Key.hidesWhileCapturing) as? Bool ?? true
    }
}
