//
//  LockSettingsTests.swift
//  IDFAVaultTests
//

import Foundation
@testable import IDFAVault
import Testing

struct LockSettingsTests {
    @Test(arguments: [
        (AutoLockTiming.immediately, 0.0, true),
        (.afterOneMinute, 59, false),
        (.afterOneMinute, 60, true),
        (.afterFiveMinutes, 299, false),
        (.afterFiveMinutes, 300, true)
    ])
    func autoLockInterval(timing: AutoLockTiming, elapsed: TimeInterval, locks: Bool) {
        let backgroundedAt = Date(timeIntervalSince1970: 0)
        #expect(timing.shouldLock(backgroundedAt: backgroundedAt, now: backgroundedAt.addingTimeInterval(elapsed)) == locks)
    }

    /// 生体認証のマークは SF Symbols の公式シンボル（仕様書 3.1）
    @Test
    func biometrySymbols() {
        #expect(BiometryKind.faceID.symbolName == "faceid")
        #expect(BiometryKind.touchID(.homeButton).symbolName == "touchid")
        #expect(BiometryKind.touchID(.mac).symbolName == "touchid")
        #expect(BiometryKind.opticID.symbolName == "opticid")
        #expect(BiometryKind.none.symbolName == "lock")
    }

    @Test
    func settingsDefaultsAndPersistence() {
        let defaults = UserDefaults.volatile(named: "tests.settings")
        let settings = AppSettings(defaults: defaults)
        #expect(settings.autoLock == .immediately)
        #expect(settings.hidesWhileCapturing)

        settings.autoLock = .afterFiveMinutes
        settings.hidesWhileCapturing = false

        let reloaded = AppSettings(defaults: defaults)
        #expect(reloaded.autoLock == .afterFiveMinutes)
        #expect(!reloaded.hidesWhileCapturing)
    }
}
