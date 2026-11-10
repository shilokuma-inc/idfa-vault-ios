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
    /// 「画面収録・ミラーリング中は隠す」の保存先（UI テストで切るときに使う）
    static let hidesWhileCapturingKey = Key.hidesWhileCapturing

    private enum Key {
        static let autoLock = "settings.autoLock"
        static let hidesWhileCapturing = "settings.hidesWhileCapturing"
        static let masksOtherDevices = "settings.masksOtherDevices"
        static let syncsThisDevice = "settings.syncsThisDevice"
    }

    /// 自動ロックのタイミング（初期値: すぐに）
    var autoLock: AutoLockTiming {
        didSet { defaults.set(autoLock.rawValue, forKey: Key.autoLock) }
    }

    /// 画面収録・ミラーリング中は隠す（初期値: オン）
    var hidesWhileCapturing: Bool {
        didSet { defaults.set(hidesWhileCapturing, forKey: Key.hidesWhileCapturing) }
    }

    /// 他デバイスの IDFA を伏せ字にする（初期値: オン）
    var masksOtherDevices: Bool {
        didSet { defaults.set(masksOtherDevices, forKey: Key.masksOtherDevices) }
    }

    /// このデバイスの IDFA を同期（初期値: オン）。切り替えは AppModel.setSyncsThisDevice で行う（オフでレコードを消すため）
    var syncsThisDevice: Bool {
        didSet { defaults.set(syncsThisDevice, forKey: Key.syncsThisDevice) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
        autoLock = defaults.string(forKey: Key.autoLock).flatMap(AutoLockTiming.init(rawValue:)) ?? .immediately
        hidesWhileCapturing = defaults.object(forKey: Key.hidesWhileCapturing) as? Bool ?? true
        masksOtherDevices = defaults.object(forKey: Key.masksOtherDevices) as? Bool ?? true
        syncsThisDevice = defaults.object(forKey: Key.syncsThisDevice) as? Bool ?? true
    }
}
